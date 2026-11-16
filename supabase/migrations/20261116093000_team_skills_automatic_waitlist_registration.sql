-- Admit only max_teams competing requests, then place up to max_teams
-- additional captain-verified applications on the auditable waitlist.
-- No auto-payment, auto-approval, ranking or booking commission.
create or replace function public.team_skills_register(
 p_cup_id uuid,p_team_id uuid,p_player_ids uuid[],p_goalkeeper_id uuid,p_representative_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_cup public.team_skills_cups%rowtype; v_reg uuid;
 v_actor uuid := (select auth.uid()); v_status text:='pending';
begin
 if v_actor is null then raise exception 'Login required'; end if;
 select * into v_cup from public.team_skills_cups where id=p_cup_id for update;
 if v_cup.id is null or v_cup.status <> 'registration' or v_cup.starts_at <= now()
 then raise exception 'Registration closed'; end if;
 if not exists(select 1 from public.teams where id=p_team_id and captain_id=v_actor)
 then raise exception 'Captain only'; end if;
 if coalesce(array_length(p_player_ids,1),0)<>5 or
    (select count(distinct x) from unnest(p_player_ids) as x)<>5 or
    p_goalkeeper_id is null or not (p_goalkeeper_id=any(p_player_ids)) or
    p_representative_id is null or not (p_representative_id=any(p_player_ids))
 then raise exception 'Exactly four field players and one goalkeeper required'; end if;
 if exists(select 1 from unnest(p_player_ids) as x
   where not exists(select 1 from public.team_members tm
     where tm.team_id=p_team_id and tm.user_id=x)
     and not exists(select 1 from public.teams t where t.id=p_team_id and t.captain_id=x)
 ) then raise exception 'Roster player is not a team member'; end if;
 if exists(select 1 from public.team_skills_registrations where cup_id=p_cup_id and team_id=p_team_id)
 then raise exception 'Team already registered'; end if;
 if exists(select 1 from public.team_skills_roster where cup_id=p_cup_id and active
    and player_id=any(p_player_ids))
 then raise exception 'Player is already participating'; end if;
 -- A closed playing roster may accept a limited WAITLIST without
 -- falsely promising approval. The cup row FOR UPDATE serializes last-slot
 -- allocation among concurrent captains.
 if (select count(*) from public.team_skills_registrations where cup_id=p_cup_id
   and status in ('pending','approved')) >= v_cup.max_teams then
   v_status:='waitlist';
   if (select count(*) from public.team_skills_registrations
     where cup_id=p_cup_id and status='waitlist')>=v_cup.max_teams then
     raise exception 'Tournament and waitlist are full';
   end if;
 end if;
 insert into public.team_skills_registrations(
  cup_id,team_id,captain_id,goalkeeper_id,representative_id,status)
 values(p_cup_id,p_team_id,v_actor,p_goalkeeper_id,p_representative_id,v_status)
 returning id into v_reg;
 insert into public.team_skills_roster(cup_id,registration_id,player_id,position)
 select p_cup_id,v_reg,x,case when x=p_goalkeeper_id then 'goalkeeper' else 'field' end
 from unnest(p_player_ids) as x;
 insert into public.team_skills_audit(cup_id,actor_id,action,subject_id,details)
 values(p_cup_id,v_actor,'register_team',v_reg,
   jsonb_build_object('initial_status',v_status));
 return v_reg;
end $$;
