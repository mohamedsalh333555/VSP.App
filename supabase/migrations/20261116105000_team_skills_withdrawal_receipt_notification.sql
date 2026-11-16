-- Uniform, once-only inbox receipt for an approved admin cancellation
-- or current captain withdrawal. Bound audit input to avoid oversized records.
-- Existing role, paid-check-in, row locks and immutable withdrawal state remain.
create or replace function public.team_skills_withdraw_registration(
 p_registration_id uuid, p_reason text default null
) returns void language plpgsql security definer set search_path='' as $$
declare
 v_actor uuid := (select auth.uid());
 v_is_admin boolean;
 v_cup_id uuid;
 c public.team_skills_cups%rowtype;
 r public.team_skills_registrations%rowtype;
 v_reason text;
begin
 if v_actor is null then raise exception 'Login required'; end if;
 v_is_admin := vsp_skills_private.is_admin();
 select cup_id into v_cup_id from public.team_skills_registrations
   where id=p_registration_id;
 if v_cup_id is null then raise exception 'Registration not found'; end if;
 -- Lock order matches register/review and serializes withdrawal vs promotion.
 select * into c from public.team_skills_cups where id=v_cup_id for update;
 if c.id is null or c.status<>'registration' or c.starts_at<=now()
 then raise exception 'Registration withdrawals are closed'; end if;
 select * into r from public.team_skills_registrations
  where id=p_registration_id for update;
 if r.id is null or r.cup_id<>c.id
   or r.status not in ('pending','waitlist','approved')
 then raise exception 'Registration cannot be withdrawn';end if;
 if r.checked_in_at is not null or r.hospitality_payment_status<>'unpaid'
 then raise exception 'Hospitality settlement requires manual admin review';end if;
 if not v_is_admin then
   if r.captain_id<>v_actor or r.status not in ('pending','waitlist')
     or not exists(select 1 from public.teams t
       where t.id=r.team_id and t.captain_id=v_actor)
     or not exists(select 1 from public.users u
       where u.id=v_actor and coalesce(u.is_blocked,false)=false)
   then raise exception 'Current captain can only withdraw an unreviewed team';end if;
 end if;
 v_reason := nullif(btrim(coalesce(p_reason,'')),'');
 if char_length(coalesce(v_reason,''))>300
 then raise exception 'Withdrawal reason exceeds 300 characters';end if;
 if v_is_admin then
   if coalesce(char_length(v_reason),0)<10
   then raise exception 'Documented admin withdrawal reason required';end if;
 else
   v_reason := coalesce(v_reason,'Captain withdrew before registration closed');
 end if;
 update public.team_skills_registrations
   set status='withdrawn',withdrawal_reason=v_reason,
       withdrawn_at=now(),withdrawn_by=v_actor
   where id=r.id;
 update public.team_skills_roster set active=false
   where registration_id=r.id;
 insert into public.team_skills_audit(
   cup_id,actor_id,action,subject_id,details)
 values(c.id,v_actor,'withdraw_registration',r.id,
   jsonb_build_object('former_status',r.status,'reason',v_reason,
      'withdrawn_by_admin',v_is_admin));
 -- One transactionally durable inbox receipt, for captain or admin action.
 -- No sensitive reason text in notification metadata.
 insert into public.notifications(user_id,title,body,message,type,metadata)
 values(r.captain_id,'تحديث مشاركة الفريق في بطولة مهارات الفرق',
   case when v_is_admin and v_actor<>r.captain_id
     then 'ألغت إدارة البطولة تسجيل فريقك. راجع تفاصيل الطلب مع الإدارة.'
     else 'تم سحب طلب فريقك من البطولة وتحرير مكانه.' end,
   case when v_is_admin and v_actor<>r.captain_id
     then 'ألغت إدارة البطولة تسجيل فريقك. راجع تفاصيل الطلب مع الإدارة.'
     else 'تم سحب طلب فريقك من البطولة وتحرير مكانه.' end,
   'info',jsonb_build_object(
      'source','team_skills_cup','event','registration_withdrawn',
      'cup_id',c.id,'team_id',r.team_id,'registration_id',r.id,
      'status','withdrawn'));
end $$;
