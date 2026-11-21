-- Physical hospitality collection only; no Paymob payment/order or venue commission changes.
create or replace function public.team_skills_confirm_hospitality(
 p_registration_id uuid,p_waive boolean default false,p_reason text default null)
returns void language plpgsql security definer set search_path='' as $$
declare r public.team_skills_registrations%rowtype;
begin
 if not vsp_skills_private.is_admin() then raise exception 'Not authorized'; end if;
 select * into r from public.team_skills_registrations where id=p_registration_id for update;
 if r.id is null or r.status not in ('pending','approved','waitlist') then
   raise exception 'Invalid registration'; end if;
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
revoke all on function public.team_skills_confirm_hospitality(uuid,boolean,text) from public,anon;
grant execute on function public.team_skills_confirm_hospitality(uuid,boolean,text) to authenticated;

create or replace function public.team_skills_check_in(p_registration_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare r public.team_skills_registrations%rowtype;
begin
 if not vsp_skills_private.is_admin() then raise exception 'Not authorized'; end if;
 select * into r from public.team_skills_registrations where id=p_registration_id for update;
 if r.id is null or r.status<>'approved' then raise exception 'Team not approved'; end if;
 if r.checked_in_at is not null then return; end if;
 if not exists(select 1 from public.team_skills_cups c
 where c.id=r.cup_id and c.status in ('registration','live'))
 then raise exception 'Check-in unavailable'; end if;
 update public.team_skills_registrations set checked_in_at=now() where id=r.id;
 insert into public.team_skills_audit(cup_id,actor_id,action,subject_id)
 values(r.cup_id,(select auth.uid()),'check_in',r.id);
end $$;
revoke all on function public.team_skills_check_in(uuid) from public,anon;
grant execute on function public.team_skills_check_in(uuid) to authenticated;
