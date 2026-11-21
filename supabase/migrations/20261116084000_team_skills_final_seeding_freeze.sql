-- Freeze the approved skills ranking once 1v1 finals are seeded.
-- Prevents premature seed order and ranking changes during the knockout.
-- A common advisory transaction lock serializes score writes vs seed generation.
create or replace function public.team_skills_generate_knockout(p_cup_id uuid)
returns integer language plpgsql security definer set search_path='' as $$
declare ids uuid[]; n int; size int; round_count int; seeds int[];
 i int; a uuid; b uuid; v_id uuid; v_round int;
begin
 if not vsp_skills_private.is_admin() then raise exception 'Not authorized'; end if;
 -- Serialize final bracket seeding with score writes and other bracket creators.
 perform pg_advisory_xact_lock(hashtextextended('skills-final:'||p_cup_id::text,0));
 if not exists(select 1 from public.team_skills_cups
   where id=p_cup_id and status in ('live','completed'))
 then raise exception 'Tournament not live'; end if;
 if exists(select 1 from public.team_skills_knockout where cup_id=p_cup_id)
 then raise exception 'Bracket already exists'; end if;
 select array_agg(r.id order by coalesce(l.points,0) desc,r.created_at,r.id)
 into ids
 from public.team_skills_registrations r
 left join public.team_skills_leaderboard l on l.registration_id=r.id
 where r.cup_id=p_cup_id and r.status='approved';
 n:=coalesce(array_length(ids,1),0);
 if n < 4 or n > 8 then raise exception '4 to 8 teams required'; end if;
 if exists(
   select 1 from public.team_skills_registrations r
   left join public.team_skills_leaderboard l on l.registration_id=r.id
   where r.cup_id=p_cup_id and r.status='approved'
     and (coalesce(l.all_stages_approved,false)=false or l.completed_stages<>12)
 ) then
   raise exception 'All 12 skills stages must be approved for every team before seeding the finals';
 end if;
 if n <= 4 then size:=4;round_count:=2;seeds:=array[1,4,2,3];
 else size:=8;round_count:=3;seeds:=array[1,8,4,5,2,7,3,6]; end if;
 for v_round in 1..round_count loop
   for i in 1..(size/(2^v_round)::int) loop
     if v_round=1 then
       a:=case when seeds[2*i-1]<=n then ids[seeds[2*i-1]] else null end;
       b:=case when seeds[2*i]<=n then ids[seeds[2*i]] else null end;
     else a:=null;b:=null; end if;
     insert into public.team_skills_knockout(cup_id,round_no,match_no,
       first_registration_id,second_registration_id,winner_registration_id,status)
     values(p_cup_id,v_round,i,a,b,
       case when v_round=1 and b is null then a else null end,
       case when v_round=1 and b is null then 'approved' else 'scheduled' end);
   end loop;
 end loop;
 -- Promote verified first-round byes to the correct next-round slot.
 for i in 1..(size/2) loop
   select winner_registration_id into v_id from public.team_skills_knockout
   where cup_id=p_cup_id and round_no=1 and match_no=i and status='approved';
   if v_id is not null then
     if mod(i,2)=1 then
       update public.team_skills_knockout set first_registration_id=v_id
       where cup_id=p_cup_id and round_no=2 and match_no=(i+1)/2;
     else
       update public.team_skills_knockout set second_registration_id=v_id
       where cup_id=p_cup_id and round_no=2 and match_no=i/2;
     end if;
   end if;
 end loop;
 insert into public.team_skills_audit(cup_id,actor_id,action,details)
 values(p_cup_id,(select auth.uid()),'generate_knockout',jsonb_build_object('teams',n,'bracket_size',size));
 return size;
end $$;

create or replace function public.team_skills_correct_score(
 p_score_id uuid,p_new_raw numeric,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare s public.team_skills_scores%rowtype; p public.team_skills_phases%rowtype;
 v_points numeric;
begin
 if not vsp_skills_private.is_admin() then raise exception 'Not authorized'; end if;
 if char_length(btrim(coalesce(p_reason,'')))<10 then raise exception 'Reason is required'; end if;
 select * into s from public.team_skills_scores where id=p_score_id for update;
 if s.id is null then raise exception 'Score not found'; end if;
 -- The final bracket fixes the skills ranking. Corrections require a separate,
 -- documented adjudication workflow before seeding, not silent reseeding.
 if exists(select 1 from public.team_skills_knockout k where k.cup_id=s.cup_id)
 then raise exception 'Knockout already seeded; skills results are frozen'; end if;
 if not exists(select 1 from public.team_skills_cups where id=s.cup_id and status='live')
 then raise exception 'Only active tournaments permit correction'; end if;
 select * into p from public.team_skills_phases where cup_id=s.cup_id and stage_no=s.stage_no;
 v_points:=vsp_skills_private.score(p.metric,p_new_raw,p.weight,p.target,p.best_ms,p.worst_ms);
 insert into public.team_skills_audit(cup_id,actor_id,action,subject_id,details)
 values(s.cup_id,(select auth.uid()),'correct_score',s.id,
 jsonb_build_object('old_raw',s.raw_value,'old_points',s.computed_points,
 'old_status',s.status,'new_raw',p_new_raw,'new_points',v_points,'reason',p_reason));
 update public.team_skills_scores set raw_value=p_new_raw,computed_points=v_points,
 status='pending',entered_by=(select auth.uid()),entered_at=now(),
 approved_by=null,approved_at=null where id=s.id;
end $$;

create or replace function vsp_skills_private.guard_score_after_seeding()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_cup uuid;
begin
 v_cup:=case when tg_op='DELETE' then old.cup_id else new.cup_id end;
 perform pg_advisory_xact_lock(hashtextextended('skills-final:'||v_cup::text,0));
 if exists(select 1 from public.team_skills_knockout k where k.cup_id=v_cup)
 then raise exception 'Knockout already seeded; skills scores are frozen'; end if;
 if tg_op='DELETE' then return old; end if;
 return new;
end $$;
revoke all on function vsp_skills_private.guard_score_after_seeding() from public,anon,authenticated;
drop trigger if exists team_skills_freeze_score_after_seed on public.team_skills_scores;
create trigger team_skills_freeze_score_after_seed
before insert or update or delete on public.team_skills_scores
for each row execute function vsp_skills_private.guard_score_after_seeding();
