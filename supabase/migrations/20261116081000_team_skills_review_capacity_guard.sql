-- Fix late approval of waitlisted teams bypassing tournament capacity.
-- Lock cup before registration, matching captain registration lock order.
-- Review actions are forbidden after the event has started or is closed.
create or replace function public.team_skills_review_registration(
 p_registration_id uuid,p_decision text,p_reason text default null)
returns void language plpgsql security definer set search_path='' as $$
declare r public.team_skills_registrations%rowtype;
        c public.team_skills_cups%rowtype; v_cup_id uuid;
begin
 if not vsp_skills_private.is_admin() then raise exception 'Not authorized'; end if;
 if p_decision not in ('approved','rejected','waitlist') then raise exception 'Invalid decision'; end if;
 select cup_id into v_cup_id
 from public.team_skills_registrations where id=p_registration_id;
 if v_cup_id is null then raise exception 'Registration not found'; end if;

 -- Serialize captain registrations and administrative waitlist promotions.
 select * into c from public.team_skills_cups where id=v_cup_id for update;
 if c.status <> 'registration' or c.starts_at <= now()
 then raise exception 'Registration review is closed'; end if;
 select * into r from public.team_skills_registrations where id=p_registration_id for update;
 if r.id is null or r.cup_id <> c.id or r.status not in ('pending','waitlist')
 then raise exception 'Registration is not reviewable'; end if;
 if p_decision='rejected' and char_length(btrim(coalesce(p_reason,'')))<5
 then raise exception 'Documented rejection reason required'; end if;

 if p_decision='approved' and (
   select count(*) from public.team_skills_registrations
   where cup_id=c.id and status='approved'
 ) >= c.max_teams then raise exception 'Tournament approved-team capacity reached'; end if;

 update public.team_skills_registrations set status=p_decision,
  rejection_reason=case when p_decision='rejected' then p_reason else null end,
  reviewed_by=(select auth.uid()),reviewed_at=now()
 where id=r.id;

 if p_decision='rejected' then
   update public.team_skills_roster set active=false
   where registration_id=r.id;
 end if;
 insert into public.team_skills_audit(cup_id,actor_id,action,subject_id,details)
 values(r.cup_id,(select auth.uid()),'review_registration',r.id,
 jsonb_build_object('decision',p_decision,'reason',p_reason));
end $$;
revoke all on function public.team_skills_review_registration(uuid,text,text) from public,anon;
grant execute on function public.team_skills_review_registration(uuid,text,text) to authenticated;
