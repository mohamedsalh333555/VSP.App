-- Team Skills Cup: regenerate *unplayed* knockout seeding in place.
-- This is deliberately NOT a reset of match results. Every existing match ID
-- is preserved. Once a real match was played or an award announced, refuse.
-- Must follow 20261117021000 penalty fields and existing seeded bracket RPC.
create or replace function public.team_skills_regenerate_knockout(p_cup_id uuid)
returns integer language plpgsql security definer set search_path='' as $$
declare v_cup public.team_skills_cups%rowtype;
 ids uuid[]; n int; v_size int; v_round_count int; seeds int[];
 v_i int; v_round int; a uuid; b uuid; v_id uuid; v_count int;
begin
 if not vsp_skills_private.is_admin() then raise exception 'Not authorized'; end if;
 perform pg_advisory_xact_lock(hashtextextended('skills-final:'||p_cup_id::text,0));
 select * into v_cup from public.team_skills_cups where id=p_cup_id for update;
 if v_cup.id is null or v_cup.status<>'live' then
   raise exception 'Only a live cup can regenerate unplayed finals'; end if;
 -- Take locks before checking played-match status. Concurrent approvals hold
 -- the same match rows, so regeneration cannot erase an accepted result.
 perform 1 from public.team_skills_knockout
   where cup_id=p_cup_id order by round_no,match_no for update;
 select count(*) into v_count from public.team_skills_knockout
   where cup_id=p_cup_id;
 if v_count=0 then raise exception 'Bracket not yet generated';end if;
 if exists(select 1 from public.team_skills_knockout
   where cup_id=p_cup_id and (
      first_goals is not null or second_goals is not null
      or first_penalties is not null or second_penalties is not null
      or (status='approved' and second_registration_id is not null)
   )) then
   raise exception 'Cannot regenerate finals after any played match';
 end if;
 if exists(select 1 from public.team_skills_awards
    where cup_id=p_cup_id) then
   raise exception 'Cannot regenerate finals after award announcement';
 end if;
 select array_agg(r.id order by coalesce(l.points,0) desc,r.created_at,r.id)
 into ids from public.team_skills_registrations r
 left join public.team_skills_leaderboard l on l.registration_id=r.id
 where r.cup_id=p_cup_id and r.status='approved';
 n:=coalesce(array_length(ids,1),0);
 if n < 4 or n > 8 then raise exception '4 to 8 teams required';end if;
 if exists(select 1 from public.team_skills_registrations r
   left join public.team_skills_leaderboard l on l.registration_id=r.id
   where r.cup_id=p_cup_id and r.status='approved'
    and (coalesce(l.all_stages_approved,false)=false or l.completed_stages<>12))
 then raise exception 'All 12 skills stages required';end if;
 if n<=4 then
   v_size:=4;v_round_count:=2;seeds:=array[1,4,2,3];
 else
   v_size:=8;v_round_count:=3;seeds:=array[1,8,4,5,2,7,3,6];
 end if;
 if v_count<>v_size-1 or exists(
  select 1 from generate_series(1,v_round_count) r
  join generate_series(1,v_size/(2^r)::int) m on true
  left join public.team_skills_knockout k on k.cup_id=p_cup_id
      and k.round_no=r and k.match_no=m
  where k.id is null
 ) then raise exception 'Bracket shape does not match current team count';end if;
 -- No DELETE or INSERT, preserving row IDs and existing subscribers.
 update public.team_skills_knockout set
   first_registration_id=null,second_registration_id=null,
   winner_registration_id=null,status='scheduled',
   first_goals=null,second_goals=null,
   first_penalties=null,second_penalties=null
 where cup_id=p_cup_id;
 for v_i in 1..(v_size/2) loop
   a:=case when seeds[2*v_i-1]<=n then ids[seeds[2*v_i-1]] else null end;
   b:=case when seeds[2*v_i]<=n then ids[seeds[2*v_i]] else null end;
   update public.team_skills_knockout set
     first_registration_id=a,second_registration_id=b,
     winner_registration_id=case when b is null then a else null end,
     status=case when b is null then 'approved' else 'scheduled' end
   where cup_id=p_cup_id and round_no=1 and match_no=v_i;
 end loop;
 -- Restore automatic first-round byes into their correct future slots.
 for v_i in 1..(v_size/2) loop
   select winner_registration_id into v_id from public.team_skills_knockout
   where cup_id=p_cup_id and round_no=1 and match_no=v_i
    and status='approved';
   if v_id is not null then
     if mod(v_i,2)=1 then
       update public.team_skills_knockout set first_registration_id=v_id
       where cup_id=p_cup_id and round_no=2 and match_no=(v_i+1)/2;
     else
       update public.team_skills_knockout set second_registration_id=v_id
       where cup_id=p_cup_id and round_no=2 and match_no=v_i/2;
     end if;
   end if;
 end loop;
 insert into public.team_skills_audit(cup_id,actor_id,action,details)
 values(p_cup_id,(select auth.uid()),'regenerate_knockout',
   jsonb_build_object('team_count',n,'bracket_size',v_size,
     'match_ids_preserved',true,'played_matches_reset',false));
 return v_size;
end $$;
revoke all on function public.team_skills_regenerate_knockout(uuid)
  from public,anon,authenticated;
grant execute on function public.team_skills_regenerate_knockout(uuid)
  to authenticated;
