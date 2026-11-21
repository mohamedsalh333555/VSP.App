-- Collect physical Team Skills hospitality only after the event admin
-- APPROVES the team. Pending/waitlisted teams are not liable for a cash
-- receipt or exemption before a seat is confirmed; preserves cancellation
-- and documented waiver protections from earlier releases.
create or replace function public.team_skills_confirm_hospitality(
 p_registration_id uuid,p_waive boolean default false,p_reason text default null)
returns void language plpgsql security definer set search_path='' as $$
declare r public.team_skills_registrations%rowtype;
begin
 if not vsp_skills_private.is_admin() then raise exception 'Not authorized'; end if;
 select * into r from public.team_skills_registrations where id=p_registration_id for update;
 if r.id is null or r.status <> 'approved' then
   raise exception 'Hospitality can only be recorded for approved teams'; end if;
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
