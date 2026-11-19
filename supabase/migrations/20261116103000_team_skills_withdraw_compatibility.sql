-- Keep the earlier captain-only withdrawal RPC compatible, but delegate
-- all actual mutations to the same audited, financially guarded withdrawal
-- implementation used by Flutter and the Admin Panel. Previously withdrawn
-- applications retain idempotent captain-only retry behavior.
create or replace function public.team_skills_withdraw_application(
 p_registration_id uuid, p_reason text default null
) returns void language plpgsql security definer set search_path='' as $$
declare
 v_actor uuid := (select auth.uid());
 v_reg public.team_skills_registrations%rowtype;
begin
 if v_actor is null then raise exception 'Login required';end if;
 select * into v_reg from public.team_skills_registrations
 where id=p_registration_id;
 if v_reg.id is null or v_reg.captain_id<>v_actor or not exists(
   select 1 from public.teams t where t.id=v_reg.team_id
     and t.captain_id=v_actor)
 then raise exception 'Captain application only';end if;
 if v_reg.status='withdrawn' then return;end if;
 perform public.team_skills_withdraw_registration(p_registration_id,p_reason);
end $$;

revoke all on function public.team_skills_withdraw_application(uuid,text)
  from public,anon;
grant execute on function public.team_skills_withdraw_application(uuid,text)
  to authenticated;
