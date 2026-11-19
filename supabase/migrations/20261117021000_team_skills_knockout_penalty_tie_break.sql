-- Team Skills Cup finals: decisive penalties after a tied regulation score.
-- Preserve the original 3-argument no-tie RPC for existing clients.
-- This migration must be deployed separately after staging verification;
-- do not rewrite already-adjudicated knockout results.
alter table public.team_skills_knockout
  add column if not exists first_penalties integer,
  add column if not exists second_penalties integer;

alter table public.team_skills_knockout
  drop constraint if exists team_skills_knockout_penalties_decisive;
alter table public.team_skills_knockout
  add constraint team_skills_knockout_penalties_decisive
  check (
    (first_penalties is null and second_penalties is null)
    or (first_penalties is not null and second_penalties is not null
      and first_penalties >= 0 and second_penalties >= 0
      and first_penalties <> second_penalties and
      first_goals is not null and second_goals is not null
      and first_goals = second_goals)
  );

create or replace function public.team_skills_approve_knockout_penalties(
 p_match_id uuid,
 p_first_goals integer,p_second_goals integer,
 p_first_penalties integer,p_second_penalties integer)
returns uuid language plpgsql security definer set search_path='' as $$
declare m public.team_skills_knockout%rowtype;
 winner uuid;
begin
 if not vsp_skills_private.is_admin() then
   raise exception 'Not authorized';
 end if;
 select * into m from public.team_skills_knockout where id=p_match_id for update;
 if m.id is null or m.status<>'scheduled' or m.first_registration_id is null
   or m.second_registration_id is null then
   raise exception 'Match not ready';
 end if;
 if not exists(select 1 from public.team_skills_cups c
   where c.id=m.cup_id and c.status in ('live','completed')) then
   raise exception 'Cannot approve knockout after cancellation';
 end if;
 if p_first_goals is null or p_second_goals is null
   or p_first_goals < 0 or p_second_goals < 0
   or p_first_goals <> p_second_goals then
   raise exception 'Penalties require a tied nonnegative regulation score';
 end if;
 if p_first_penalties is null or p_second_penalties is null
   or p_first_penalties < 0 or p_second_penalties < 0
   or p_first_penalties = p_second_penalties then
   raise exception 'Decisive penalty score required';
 end if;
 winner:=case when p_first_penalties>p_second_penalties
   then m.first_registration_id else m.second_registration_id end;
 update public.team_skills_knockout
 set first_goals=p_first_goals,second_goals=p_second_goals,
   first_penalties=p_first_penalties,second_penalties=p_second_penalties,
   winner_registration_id=winner,status='approved'
 where id=m.id;
 if m.round_no < (select max(round_no) from public.team_skills_knockout
   where cup_id=m.cup_id) then
   if mod(m.match_no,2)=1 then
     update public.team_skills_knockout
     set first_registration_id=winner
     where cup_id=m.cup_id and round_no=m.round_no+1
       and match_no=(m.match_no+1)/2;
   else
     update public.team_skills_knockout
     set second_registration_id=winner
     where cup_id=m.cup_id and round_no=m.round_no+1
       and match_no=m.match_no/2;
   end if;
 end if;
 insert into public.team_skills_audit(cup_id,actor_id,action,subject_id,details)
 values(m.cup_id,(select auth.uid()),'approve_knockout',m.id,
   jsonb_build_object(
     'method','penalties','first_goals',p_first_goals,
     'second_goals',p_second_goals,
     'first_penalties',p_first_penalties,
     'second_penalties',p_second_penalties,'winner',winner));
 return winner;
end $$;
revoke all on function public.team_skills_approve_knockout_penalties(
 uuid,integer,integer,integer,integer) from public,anon,authenticated;
grant execute on function public.team_skills_approve_knockout_penalties(
 uuid,integer,integer,integer,integer) to authenticated;
