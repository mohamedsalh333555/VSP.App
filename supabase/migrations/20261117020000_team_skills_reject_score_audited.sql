-- Team Skills Cup: a documented rejection of a pending raw skills score.
-- Reuse the existing admin-only team_skills_correct_score RPC to return
-- a rejected measurement to pending after supplying a corrected raw value.
-- This is a feature-branch migration; it is NOT applied to hosted staging or prod.
create or replace function public.team_skills_reject_score(
 p_score_id uuid,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare
 v_actor uuid := (select auth.uid());
 v_cup_id uuid;
 s public.team_skills_scores%rowtype;
begin
 if not vsp_skills_private.is_admin() then
   raise exception 'Not authorized';
 end if;
 if char_length(btrim(coalesce(p_reason,'')))<10
    or char_length(btrim(coalesce(p_reason,'')))>1000 then
   raise exception 'Documented rejection reason must contain 10 to 1000 characters';
 end if;

 select cup_id into v_cup_id from public.team_skills_scores
 where id=p_score_id;
 if v_cup_id is null then raise exception 'Score not found'; end if;
 -- Same lock as bracket seeding and score writes. Prevents the result
 -- from being rejected during concurrent final-bracket generation.
 perform pg_advisory_xact_lock(hashtextextended(
   'skills-final:'||v_cup_id::text,0));

 select * into s from public.team_skills_scores
 where id=p_score_id for update;
 if s.id is null or s.status<>'pending' then
   raise exception 'Only a pending score may be rejected';
 end if;
 if not exists(select 1 from public.team_skills_cups c
   where c.id=s.cup_id and c.status='live') then
   raise exception 'Only an active tournament permits score rejection';
 end if;
 if exists(select 1 from public.team_skills_knockout k
   where k.cup_id=s.cup_id) then
   raise exception 'Knockout already seeded; skills results are frozen';
 end if;

 update public.team_skills_scores
 set status='rejected',approved_by=null,approved_at=null
 where id=s.id;
 insert into public.team_skills_audit(
   cup_id,actor_id,action,subject_id,details)
 values(s.cup_id,v_actor,'reject_score',s.id,
   jsonb_build_object(
     'stage',s.stage_no,
     'old_raw',s.raw_value,
     'old_points',s.computed_points,
     'reason',btrim(p_reason)));
end $$;
revoke all on function public.team_skills_reject_score(uuid,text)
  from public,anon,authenticated;
grant execute on function public.team_skills_reject_score(uuid,text)
  to authenticated;
