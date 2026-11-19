-- Prevent two goalkeeper stations from requiring the same team at the
-- same time. A team may be a keeper participant OR the shooting opponent.
-- Serialize writes on both participating teams in canonical UUID order.
-- [start,end) slots allow adjacent sessions without a false collision.
create or replace function public.team_skills_schedule_goalkeeper(
 p_registration_id uuid,p_opponent_team_id uuid,
 p_start timestamptz,p_end timestamptz)
returns uuid language plpgsql security definer set search_path='' as $$
declare r public.team_skills_registrations%rowtype;
 c public.team_skills_cups%rowtype; v_id uuid;v_team_id uuid;
begin
 if not vsp_skills_private.is_admin() then raise exception 'Not authorized'; end if;
 select * into r from public.team_skills_registrations where id=p_registration_id;
 if r.id is null or r.status<>'approved' then raise exception 'Keeper team not approved'; end if;
 select * into c from public.team_skills_cups where id=r.cup_id;
 if c.status not in ('registration','live') or p_start < c.starts_at or
   p_end > c.ends_at or p_end <= p_start then
   raise exception 'Outside tournament schedule';end if;
 if p_opponent_team_id=r.team_id or not exists(
   select 1 from public.team_skills_registrations e
   where e.cup_id=r.cup_id and e.team_id=p_opponent_team_id and e.status='approved')
 then raise exception 'Goalkeeper cannot face own team or unapproved opponent';end if;

 -- Sort team locks so A/B and B/A requests never deadlock.
 for v_team_id in
   select unnest(array[r.team_id,p_opponent_team_id]) order by 1
 loop
   perform pg_advisory_xact_lock(hashtextextended(
     'skills-keeper-team:'||r.cup_id::text||':'||v_team_id::text,0));
 end loop;

 if exists(
   select 1 from public.team_skills_goalkeeper_trials t
   join public.team_skills_registrations other on other.id=t.registration_id
   where t.cup_id=r.cup_id
     and tstzrange(t.starts_at,t.ends_at,'[)') &&
         tstzrange(p_start,p_end,'[)')
     and (
       other.team_id in (r.team_id,p_opponent_team_id)
       or t.opponent_team_id in (r.team_id,p_opponent_team_id)
     )
 ) then raise exception 'A participating team already has a goalkeeper station in this time window';
 end if;

 insert into public.team_skills_goalkeeper_trials(
  cup_id,goalkeeper_id,opponent_team_id,registration_id,starts_at,ends_at)
 values(r.cup_id,r.goalkeeper_id,p_opponent_team_id,r.id,p_start,p_end)
 returning id into v_id;
 insert into public.team_skills_audit(cup_id,actor_id,action,subject_id,details)
 values(r.cup_id,(select auth.uid()),'schedule_goalkeeper',v_id,
 jsonb_build_object('keeper_team',r.team_id,'opponent_team',p_opponent_team_id,
 'starts_at',p_start,'ends_at',p_end));
 return v_id;
end $$;
