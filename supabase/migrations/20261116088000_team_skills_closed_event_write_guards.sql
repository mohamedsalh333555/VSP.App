-- Team Skills Cup lifecycle integrity: cancellations and archived events
-- must not accept new approvals, judge measurements, official assignments,
-- hospitality cash confirmations or knockout winners.
--
-- Existing read-only history and revocation RPCs remain available.
create or replace function public.team_skills_approve_score(p_score_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare s public.team_skills_scores%rowtype;
begin
 if not vsp_skills_private.is_admin() then raise exception 'Not authorized'; end if;
 select * into s from public.team_skills_scores where id=p_score_id for update;
 if s.id is null or s.status<>'pending' then raise exception 'Not pending'; end if;
 if not exists(select 1 from public.team_skills_cups c
   where c.id=s.cup_id and c.status='live')
 then raise exception 'Cannot approve skills score outside live tournament'; end if;
 update public.team_skills_scores set status='approved',approved_by=(select auth.uid()),approved_at=now()
 where id=s.id;
 insert into public.team_skills_audit(cup_id,actor_id,action,subject_id,details)
 values(s.cup_id,(select auth.uid()),'approve_score',s.id,jsonb_build_object('points',s.computed_points));
end $$;

create or replace function public.team_skills_record_goalkeeper(
 p_trial_id uuid,p_shots int,p_saves int,p_conceded int)
returns void language plpgsql security definer set search_path='' as $$
declare t public.team_skills_goalkeeper_trials%rowtype;
begin
 select * into t from public.team_skills_goalkeeper_trials where id=p_trial_id for update;
 if t.id is null or t.status<>'scheduled' then raise exception 'Trial unavailable'; end if;
 if not exists(select 1 from public.team_skills_cups c
   where c.id=t.cup_id and c.status='live')
 then raise exception 'Cannot record goalkeeper outside live tournament'; end if;
 if not vsp_skills_private.is_admin() then
   perform 1 from public.team_skills_officials o
     join public.users u on u.id=o.user_id
   where o.cup_id=t.cup_id and o.user_id=(select auth.uid())
     and o.role='judge' and coalesce(u.is_blocked,false)=false
   for share of o;
   if not found then raise exception 'Judge only'; end if;
 end if;
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

create or replace function public.team_skills_approve_goalkeeper(p_trial_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare t public.team_skills_goalkeeper_trials%rowtype;
begin
 if not vsp_skills_private.is_admin() then raise exception 'Not authorized'; end if;
 select * into t from public.team_skills_goalkeeper_trials where id=p_trial_id for update;
 if t.id is null or t.status<>'completed' then raise exception 'Trial not complete'; end if;
 if not exists(select 1 from public.team_skills_cups c
   where c.id=t.cup_id and c.status in ('live','completed'))
 then raise exception 'Cannot approve goalkeeper after cancellation'; end if;
 update public.team_skills_goalkeeper_trials set status='approved' where id=t.id;
 insert into public.team_skills_audit(cup_id,actor_id,action,subject_id)
 values(t.cup_id,(select auth.uid()),'approve_goalkeeper',t.id);
end $$;

create or replace function public.team_skills_approve_knockout_match(
 p_match_id uuid,p_first_goals int,p_second_goals int)
returns uuid language plpgsql security definer set search_path='' as $$
declare m public.team_skills_knockout%rowtype; winner uuid;
begin
 if not vsp_skills_private.is_admin() then raise exception 'Not authorized'; end if;
 select * into m from public.team_skills_knockout where id=p_match_id for update;
 if m.id is null or m.status<>'scheduled' or m.first_registration_id is null
   or m.second_registration_id is null then raise exception 'Match not ready'; end if;
 if not exists(select 1 from public.team_skills_cups c
   where c.id=m.cup_id and c.status in ('live','completed'))
 then raise exception 'Cannot approve knockout after cancellation'; end if;
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

create or replace function public.team_skills_confirm_hospitality(
 p_registration_id uuid,p_waive boolean default false,p_reason text default null)
returns void language plpgsql security definer set search_path='' as $$
declare r public.team_skills_registrations%rowtype;
begin
 if not vsp_skills_private.is_admin() then raise exception 'Not authorized'; end if;
 select * into r from public.team_skills_registrations where id=p_registration_id for update;
 if r.id is null or r.status not in ('pending','approved','waitlist') then
   raise exception 'Invalid registration'; end if;
 if not exists(select 1 from public.team_skills_cups c
   where c.id=r.cup_id and c.status in ('registration','live'))
 then raise exception 'Cannot collect hospitality after event cancellation or closure'; end if;
 if r.hospitality_payment_status<>'unpaid' then raise exception 'Already recorded'; end if;
 if p_waive and char_length(btrim(coalesce(p_reason,'')))<10
 then raise exception 'Waiver reason required'; end if;
 update public.team_skills_registrations set
 hospitality_payment_status=case when p_waive then 'waived' else 'verified' end
 where id=r.id;
 insert into public.team_skills_audit(cup_id,actor_id,action,subject_id,details)
 values(r.cup_id,(select auth.uid()),'hospitality_recorded',r.id,
 jsonb_build_object('waived',p_waive,'reason',p_reason));
end $$;

create or replace function public.team_skills_assign_official(
 p_cup_id uuid,p_user_id uuid,p_role text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not vsp_skills_private.is_admin() then raise exception 'Not authorized'; end if;
 if p_role not in ('judge','organizer') then raise exception 'Invalid official role'; end if;
 if not exists(select 1 from public.team_skills_cups c
   where c.id=p_cup_id and c.status in ('draft','registration','live'))
 then raise exception 'Cannot assign official to cancelled or completed event'; end if;
 if not exists(select 1 from public.users u where u.id=p_user_id
    and coalesce(u.is_blocked,false)=false) then raise exception 'Unknown official'; end if;
 insert into public.team_skills_officials(cup_id,user_id,role,assigned_by)
 values(p_cup_id,p_user_id,p_role,(select auth.uid()))
 on conflict(cup_id,user_id) do update
 set role=excluded.role,assigned_by=excluded.assigned_by;
 insert into public.team_skills_audit(cup_id,actor_id,action,subject_id,details)
 values(p_cup_id,(select auth.uid()),'assign_official',p_user_id,jsonb_build_object('role',p_role));
end $$;
