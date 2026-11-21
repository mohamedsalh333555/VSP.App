-- Additive follow-up. Server-only official actions; no payment / legacy 1v1 mutations.
create or replace function public.team_skills_assign_official(
 p_cup_id uuid,p_user_id uuid,p_role text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not vsp_skills_private.is_admin() then raise exception 'Not authorized'; end if;
 if p_role not in ('judge','organizer') then raise exception 'Invalid official role'; end if;
 if not exists(select 1 from public.users u where u.id=p_user_id
    and coalesce(u.is_blocked,false)=false) then raise exception 'Unknown official'; end if;
 insert into public.team_skills_officials(cup_id,user_id,role,assigned_by)
 values(p_cup_id,p_user_id,p_role,(select auth.uid()))
 on conflict(cup_id,user_id) do update
 set role=excluded.role,assigned_by=excluded.assigned_by;
 insert into public.team_skills_audit(cup_id,actor_id,action,subject_id,details)
 values(p_cup_id,(select auth.uid()),'assign_official',p_user_id,jsonb_build_object('role',p_role));
end $$;
revoke all on function public.team_skills_assign_official(uuid,uuid,text) from public,anon;
grant execute on function public.team_skills_assign_official(uuid,uuid,text) to authenticated;

-- A validated correction reopens the approval workflow and preserves both
-- raw measurements and computed scores in the immutable audit history.
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
revoke all on function public.team_skills_correct_score(uuid,numeric,text) from public,anon;
grant execute on function public.team_skills_correct_score(uuid,numeric,text) to authenticated;

create or replace function public.team_skills_schedule_goalkeeper(
 p_registration_id uuid,p_opponent_team_id uuid,p_start timestamptz,p_end timestamptz)
returns uuid language plpgsql security definer set search_path='' as $$
declare r public.team_skills_registrations%rowtype;
 c public.team_skills_cups%rowtype; v_id uuid;
begin
 if not vsp_skills_private.is_admin() then raise exception 'Not authorized'; end if;
 select * into r from public.team_skills_registrations where id=p_registration_id;
 if r.id is null or r.status<>'approved' then raise exception 'Keeper team not approved'; end if;
 select * into c from public.team_skills_cups where id=r.cup_id;
 if c.status not in ('registration','live') or p_start < c.starts_at or
   p_end > c.ends_at or p_end <= p_start then raise exception 'Outside tournament schedule'; end if;
 if p_opponent_team_id=r.team_id or not exists(select 1 from public.team_skills_registrations
   where cup_id=r.cup_id and team_id=p_opponent_team_id and status='approved')
 then raise exception 'Goalkeeper cannot face own team or unapproved opponent'; end if;
 -- Serializes competing schedule insertions for the same keeper in this cup.
 perform pg_advisory_xact_lock(hashtextextended(r.cup_id::text||':'||r.goalkeeper_id::text,0));
 if exists(select 1 from public.team_skills_goalkeeper_trials t
  where t.cup_id=r.cup_id and t.goalkeeper_id=r.goalkeeper_id
    and tstzrange(t.starts_at,t.ends_at,'[)') && tstzrange(p_start,p_end,'[)'))
 then raise exception 'Goalkeeper time conflict'; end if;
 insert into public.team_skills_goalkeeper_trials(
 cup_id,goalkeeper_id,opponent_team_id,registration_id,starts_at,ends_at)
 values(r.cup_id,r.goalkeeper_id,p_opponent_team_id,r.id,p_start,p_end)
 returning id into v_id;
 insert into public.team_skills_audit(cup_id,actor_id,action,subject_id)
 values(r.cup_id,(select auth.uid()),'schedule_goalkeeper',v_id);
 return v_id;
end $$;
revoke all on function public.team_skills_schedule_goalkeeper(uuid,uuid,timestamptz,timestamptz) from public,anon;
grant execute on function public.team_skills_schedule_goalkeeper(uuid,uuid,timestamptz,timestamptz) to authenticated;

create or replace function public.team_skills_record_goalkeeper(
 p_trial_id uuid,p_shots int,p_saves int,p_conceded int)
returns void language plpgsql security definer set search_path='' as $$
declare t public.team_skills_goalkeeper_trials%rowtype;
begin
 select * into t from public.team_skills_goalkeeper_trials where id=p_trial_id for update;
 if t.id is null or t.status<>'scheduled' then raise exception 'Trial unavailable'; end if;
 if not (vsp_skills_private.is_admin() or exists(select 1 from public.team_skills_officials o
 where o.cup_id=t.cup_id and o.user_id=(select auth.uid()) and o.role='judge'))
 then raise exception 'Judge only'; end if;
 if p_shots is null or p_shots < 1 or p_saves is null or p_conceded is null
    or p_saves < 0 or p_conceded < 0 or p_shots <> p_saves+p_conceded
 then raise exception 'Invalid goalkeeper measurements'; end if;
 update public.team_skills_goalkeeper_trials
 set shots_on_target=p_shots,saves=p_saves,goals_conceded=p_conceded,status='completed'
 where id=t.id;
 insert into public.team_skills_audit(cup_id,actor_id,action,subject_id,details)
 values(t.cup_id,(select auth.uid()),'record_goalkeeper',t.id,
 jsonb_build_object('shots',p_shots,'saves',p_saves,'conceded',p_conceded));
end $$;
revoke all on function public.team_skills_record_goalkeeper(uuid,int,int,int) from public,anon;
grant execute on function public.team_skills_record_goalkeeper(uuid,int,int,int) to authenticated;

create or replace function public.team_skills_approve_goalkeeper(p_trial_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare t public.team_skills_goalkeeper_trials%rowtype;
begin
 if not vsp_skills_private.is_admin() then raise exception 'Not authorized'; end if;
 select * into t from public.team_skills_goalkeeper_trials where id=p_trial_id for update;
 if t.id is null or t.status<>'completed' then raise exception 'Trial not complete'; end if;
 update public.team_skills_goalkeeper_trials set status='approved' where id=t.id;
 insert into public.team_skills_audit(cup_id,actor_id,action,subject_id)
 values(t.cup_id,(select auth.uid()),'approve_goalkeeper',t.id);
end $$;
revoke all on function public.team_skills_approve_goalkeeper(uuid) from public,anon;
grant execute on function public.team_skills_approve_goalkeeper(uuid) to authenticated;

-- Seeded knockout: standard 4- or 8-slot bracket, top seeds receive byes.
-- This bracket is independent of all group-skill points.
create or replace function public.team_skills_generate_knockout(p_cup_id uuid)
returns integer language plpgsql security definer set search_path='' as $$
declare ids uuid[]; n int; size int; round_count int; seeds int[];
 i int; a uuid; b uuid; v_id uuid; v_round int;
begin
 if not vsp_skills_private.is_admin() then raise exception 'Not authorized'; end if;
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
revoke all on function public.team_skills_generate_knockout(uuid) from public,anon;
grant execute on function public.team_skills_generate_knockout(uuid) to authenticated;

create or replace function public.team_skills_approve_knockout_match(
 p_match_id uuid,p_first_goals int,p_second_goals int)
returns uuid language plpgsql security definer set search_path='' as $$
declare m public.team_skills_knockout%rowtype; winner uuid;
begin
 if not vsp_skills_private.is_admin() then raise exception 'Not authorized'; end if;
 select * into m from public.team_skills_knockout where id=p_match_id for update;
 if m.id is null or m.status<>'scheduled' or m.first_registration_id is null
   or m.second_registration_id is null then raise exception 'Match not ready'; end if;
 if p_first_goals is null or p_second_goals is null or p_first_goals<0
   or p_second_goals<0 or p_first_goals=p_second_goals
 then raise exception 'Decisive score required; use penalties to resolve ties'; end if;
 winner:=case when p_first_goals>p_second_goals then m.first_registration_id
 else m.second_registration_id end;
 update public.team_skills_knockout set first_goals=p_first_goals,
 second_goals=p_second_goals,winner_registration_id=winner,status='approved' where id=m.id;
 if m.round_no<(select max(round_no) from public.team_skills_knockout where cup_id=m.cup_id) then
   if mod(m.match_no,2)=1 then
     update public.team_skills_knockout set first_registration_id=winner
     where cup_id=m.cup_id and round_no=m.round_no+1 and match_no=(m.match_no+1)/2;
   else
     update public.team_skills_knockout set second_registration_id=winner
     where cup_id=m.cup_id and round_no=m.round_no+1 and match_no=m.match_no/2;
   end if;
 end if;
 insert into public.team_skills_audit(cup_id,actor_id,action,subject_id,details)
 values(m.cup_id,(select auth.uid()),'approve_knockout',m.id,
 jsonb_build_object('first_goals',p_first_goals,'second_goals',p_second_goals,'winner',winner));
 return winner;
end $$;
revoke all on function public.team_skills_approve_knockout_match(uuid,int,int) from public,anon;
grant execute on function public.team_skills_approve_knockout_match(uuid,int,int) to authenticated;

-- Only the objectively determined official winner can be announced.
create or replace function public.team_skills_announce_award(
 p_cup_id uuid,p_award text,p_team_id uuid,p_player_id uuid default null)
returns void language plpgsql security definer set search_path='' as $$
declare top_record record; tied int; final_winner uuid; eligible uuid;
begin
 if not vsp_skills_private.is_admin() then raise exception 'Not authorized'; end if;
 if not exists(select 1 from public.team_skills_cups where id=p_cup_id and status='completed')
 then raise exception 'Tournament must be completed'; end if;
 if p_award='team_champion' then
   if p_player_id is not null then raise exception 'Team title has no player'; end if;
   select l.team_id,l.points into top_record
   from public.team_skills_leaderboard l where l.cup_id=p_cup_id
      and l.all_stages_approved order by l.points desc limit 1;
   if top_record.team_id is null or top_record.team_id<>p_team_id then
     raise exception 'Team is not skills champion'; end if;
   select count(*) into tied from public.team_skills_leaderboard
   where cup_id=p_cup_id and all_stages_approved and points=top_record.points;
   if tied<>1 then raise exception 'Skills tie requires a documented tie-break'; end if;
 elsif p_award='one_v_one_champion' then
   select m.winner_registration_id into final_winner
   from public.team_skills_knockout m where m.cup_id=p_cup_id
     and m.round_no=(select max(round_no) from public.team_skills_knockout where cup_id=p_cup_id)
     and m.status='approved';
   if final_winner is null or not exists(
      select 1 from public.team_skills_registrations r where r.id=final_winner
      and r.team_id=p_team_id and r.representative_id=p_player_id)
   then raise exception 'No verified 1v1 champion'; end if;
 elsif p_award='best_goalkeeper' then
   if p_player_id is null or not exists(select 1 from public.team_skills_registrations r
      where r.cup_id=p_cup_id and r.team_id=p_team_id and r.goalkeeper_id=p_player_id
      and r.status='approved') then raise exception 'Invalid goalkeeper'; end if;
   select t.goalkeeper_id into eligible
    from public.team_skills_goalkeeper_trials t
    where t.cup_id=p_cup_id and t.status='approved'
    group by t.goalkeeper_id
    having sum(t.shots_on_target)>=5
    order by (sum(t.saves)::numeric/nullif(sum(t.shots_on_target),0)) desc,
             sum(t.saves) desc,t.goalkeeper_id
    limit 1;
   if eligible is null or eligible<>p_player_id then
     raise exception 'Goalkeeper did not achieve highest eligible save rate'; end if;
 else raise exception 'Unsupported award type'; end if;
 insert into public.team_skills_awards(cup_id,award_type,team_id,player_id,announced_by)
 values(p_cup_id,p_award,p_team_id,p_player_id,(select auth.uid()));
 insert into public.team_skills_audit(cup_id,actor_id,action,details)
 values(p_cup_id,(select auth.uid()),'announce_award',
 jsonb_build_object('award',p_award,'team',p_team_id,'player',p_player_id));
end $$;
revoke all on function public.team_skills_announce_award(uuid,text,uuid,uuid) from public,anon;
grant execute on function public.team_skills_announce_award(uuid,text,uuid,uuid) to authenticated;
