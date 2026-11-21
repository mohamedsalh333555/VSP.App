-- A captain can withdraw an UNAPPROVED Team Skills application during
-- registration, without payment or referee intervention. No refunds are
-- processed here; approved and paid entries are deliberately excluded.
--
-- This RPC serializes with registration, waitlist promotion and admin review
-- through the same cup FOR UPDATE lock. Withdrawal is idempotent for a
-- previously withdrawn application owned by the same CURRENT team captain.
create or replace function public.team_skills_withdraw_application(
 p_registration_id uuid,p_reason text default null
) returns void language plpgsql security definer set search_path='' as $$
declare
 v_actor uuid := (select auth.uid());
 v_cup_id uuid;
 v_cup public.team_skills_cups%rowtype;
 v_reg public.team_skills_registrations%rowtype;
begin
 if v_actor is null then raise exception 'Login required'; end if;
 select cup_id into v_cup_id from public.team_skills_registrations
 where id=p_registration_id;
 if v_cup_id is null then raise exception 'Application unavailable';end if;
 select * into v_cup from public.team_skills_cups
 where id=v_cup_id for update;
 select * into v_reg from public.team_skills_registrations
 where id=p_registration_id for update;
 if v_reg.id is null or v_reg.cup_id<>v_cup_id or
    v_reg.captain_id<>v_actor or not exists(
      select 1 from public.teams t
      where t.id=v_reg.team_id and t.captain_id=v_actor)
 then raise exception 'Captain application only';end if;
 if v_reg.status='withdrawn' then return;end if;
 if v_cup.status<>'registration' or v_cup.starts_at<=now()
 then raise exception 'Withdrawal deadline passed';end if;
 if v_reg.status not in ('pending','waitlist') then
   raise exception 'Only unapproved applications can be withdrawn';end if;
 if v_reg.hospitality_payment_status<>'unpaid' or
    v_reg.checked_in_at is not null
 then raise exception 'Paid or checked-in applications require admin support';end if;
 if p_reason is not null and char_length(btrim(p_reason))>300
 then raise exception 'Withdrawal reason too long';end if;

 update public.team_skills_registrations
 set status='withdrawn',reviewed_at=now()
 where id=v_reg.id;
 update public.team_skills_roster set active=false
 where registration_id=v_reg.id;
 insert into public.team_skills_audit(cup_id,actor_id,action,subject_id,details)
 values(v_reg.cup_id,v_actor,'withdraw_application',v_reg.id,
   jsonb_build_object('previous_status',v_reg.status,
   'reason',nullif(btrim(coalesce(p_reason,'')),'')));

 insert into public.notifications(user_id,title,body,message,type,metadata)
 values(v_actor,'تم سحب طلب المشاركة',
   'تم سحب طلب فريقك من بطولة مهارات الفرق. لا يمكن إعادة التسجيل في نفس البطولة تلقائيًا.',
   'تم سحب طلب فريقك من بطولة مهارات الفرق. لا يمكن إعادة التسجيل في نفس البطولة تلقائيًا.',
   'info',jsonb_build_object(
      'source','team_skills_cup',
      'event','registration_withdrawn',
      'cup_id',v_reg.cup_id,
      'team_id',v_reg.team_id,
      'registration_id',v_reg.id,
      'status','withdrawn'));
end $$;
revoke all on function public.team_skills_withdraw_application(uuid,text)
 from public,anon;
grant execute on function public.team_skills_withdraw_application(uuid,text)
 to authenticated;
