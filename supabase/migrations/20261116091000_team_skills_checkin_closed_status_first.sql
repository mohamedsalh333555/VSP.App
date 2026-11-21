-- Status is validated before payment/attendance so cancelled events
-- cannot look payable or silently accept idempotent check-ins after closure.
-- Existing cash-or-audited-waiver condition remains unchanged.
create or replace function public.team_skills_check_in(p_registration_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare r public.team_skills_registrations%rowtype;
begin
 if not vsp_skills_private.is_admin() then raise exception 'Not authorized'; end if;
 select * into r from public.team_skills_registrations where id=p_registration_id for update;
 if r.id is null or r.status<>'approved' then raise exception 'Team not approved'; end if;
 if not exists(select 1 from public.team_skills_cups c
   where c.id=r.cup_id and c.status in ('registration','live'))
 then raise exception 'Check-in unavailable'; end if;
 if r.checked_in_at is not null then return; end if;
 if exists(select 1 from public.team_skills_cups c
   where c.id=r.cup_id and c.hospitality_fee>0)
    and r.hospitality_payment_status not in ('verified','waived')
 then raise exception 'Record cash hospitality receipt or a documented waiver before check-in'; end if;
 update public.team_skills_registrations set checked_in_at=now() where id=r.id;
 insert into public.team_skills_audit(cup_id,actor_id,action,subject_id)
 values(r.cup_id,(select auth.uid()),'check_in',r.id);
end $$;
