-- Allow the CURRENT team captain to correct a pending/waitlisted cup
-- lineup before admin approval, without recreating the application.
-- Locks the cup first: signup, review, withdrawal and lineup correction
-- cannot race against each other or leave an inconsistent active roster.
create or replace function public.team_skills_correct_roster(
  p_registration_id uuid,p_player_ids uuid[],
  p_goalkeeper_id uuid,p_representative_id uuid
) returns void language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid := (select auth.uid());
  v_cup_id uuid;
  c public.team_skills_cups%rowtype;
  r public.team_skills_registrations%rowtype;
  v_old_players uuid[];
begin
  if v_actor is null then raise exception 'Login required';end if;
  select cup_id into v_cup_id from public.team_skills_registrations
  where id=p_registration_id;
  if v_cup_id is null then raise exception 'Registration not found';end if;
  select * into c from public.team_skills_cups
  where id=v_cup_id for update;
  if c.id is null or c.status<>'registration' or c.starts_at<=now()
  then raise exception 'Lineup corrections are closed';end if;
  select * into r from public.team_skills_registrations
  where id=p_registration_id for update;
  if r.id is null or r.cup_id<>v_cup_id or
     r.status not in ('pending','waitlist') or
     r.captain_id<>v_actor or not exists(
       select 1 from public.teams t
       where t.id=r.team_id and t.captain_id=v_actor)
  then raise exception 'Current captain can only correct an unapproved team';end if;
  if exists(select 1 from public.users u where u.id=v_actor
    and coalesce(u.is_blocked,false))
  then raise exception 'Blocked captain cannot correct cup roster';end if;
  if r.checked_in_at is not null or r.hospitality_payment_status<>'unpaid'
  then raise exception 'Hospitality settlement requires admin support';end if;
  if coalesce(array_length(p_player_ids,1),0)<>5 or
     (select count(distinct id) from unnest(p_player_ids) as id)<>5 or
     p_goalkeeper_id is null or p_representative_id is null or
     not p_goalkeeper_id=any(p_player_ids) or
     not p_representative_id=any(p_player_ids)
  then raise exception 'Exactly five unique players, including keeper and representative, required';end if;
  if exists(select 1 from public.users u
    where u.id=any(p_player_ids) and coalesce(u.is_blocked,false))
  then raise exception 'Blocked player cannot join cup roster';end if;
  if exists(select 1 from unnest(p_player_ids) as id
    where not exists(select 1 from public.team_members tm
      where tm.team_id=r.team_id and tm.user_id=id)
      and not exists(select 1 from public.teams t
        where t.id=r.team_id and t.captain_id=id))
  then raise exception 'Roster player is not a current team member';end if;
  if exists(select 1 from public.team_skills_roster s
    where s.cup_id=r.cup_id and s.registration_id<>r.id
      and s.active and s.player_id=any(p_player_ids))
  then raise exception 'Player is already participating with another team';end if;
  select array_agg(player_id order by player_id) into v_old_players
  from public.team_skills_roster where registration_id=r.id and active;
  if v_old_players=(select array_agg(id order by id)
        from unnest(p_player_ids) as id)
      and r.goalkeeper_id=p_goalkeeper_id
      and r.representative_id=p_representative_id
  then raise exception 'No roster change requested';end if;

  -- Both updates are one transaction. Inactive historic rows preserve audit
  -- provenance while no longer preventing a different team enrolling.
  update public.team_skills_roster set active=false
  where registration_id=r.id and active;
  insert into public.team_skills_roster(
     cup_id,registration_id,player_id,position,active)
  select r.cup_id,r.id,id,
         case when id=p_goalkeeper_id then 'goalkeeper' else 'field' end,true
  from unnest(p_player_ids) as id
  on conflict(registration_id,player_id)
  do update set position=excluded.position,active=true;
  update public.team_skills_registrations
  set goalkeeper_id=p_goalkeeper_id,
      representative_id=p_representative_id
  where id=r.id;
  insert into public.team_skills_audit(
    cup_id,actor_id,action,subject_id,details)
  values(r.cup_id,v_actor,'correct_pending_roster',r.id,
   jsonb_build_object(
     'old_player_count',coalesce(array_length(v_old_players,1),0),
     'new_player_count',5,
     'old_goalkeeper_id',r.goalkeeper_id,
     'new_goalkeeper_id',p_goalkeeper_id,
     'old_representative_id',r.representative_id,
     'new_representative_id',p_representative_id));
end $$;
revoke all on function public.team_skills_correct_roster(uuid,uuid[],uuid,uuid)
 from public,anon;
grant execute on function public.team_skills_correct_roster(uuid,uuid[],uuid,uuid)
 to authenticated;
