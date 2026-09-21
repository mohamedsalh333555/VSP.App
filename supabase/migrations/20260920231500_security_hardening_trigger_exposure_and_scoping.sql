-- Security hardening: close trigger-only API exposure and enforce owner/user scoping
begin;

revoke execute on function public.calculate_elo_on_match_completion() from public, anon, authenticated;
revoke execute on function public.check_1v1_registration_capacity() from public, anon, authenticated;
revoke execute on function public.check_owner_stadium_limit_trigger() from public, anon, authenticated;
revoke execute on function public.check_owner_stadium_limit() from public, anon, authenticated;
revoke execute on function public.check_team_and_member_limits() from public, anon, authenticated;
revoke execute on function public.enforce_cash_booking_restrictions() from public, anon, authenticated;
revoke execute on function public.enforce_real_sender_name() from public, anon, authenticated;
revoke execute on function public.fn_log_sensitive_changes() from public, anon, authenticated;
revoke execute on function public.handle_new_notification_fcm() from public, anon, authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.handle_stadium_breaks_collision() from public, anon, authenticated;
revoke execute on function public.handle_stadium_review_changes() from public, anon, authenticated;
revoke execute on function public.log_booking_payment_transaction() from public, anon, authenticated;
revoke execute on function public.prevent_late_cancellation() from public, anon, authenticated;
revoke execute on function public.protect_booking_payment_fields() from public, anon, authenticated;
revoke execute on function public.protect_booking_sensitive_fields() from public, anon, authenticated;
revoke execute on function public.protect_championship_sensitive_fields() from public, anon, authenticated;
revoke execute on function public.protect_completed_match_scores() from public, anon, authenticated;
revoke execute on function public.protect_stadium_sensitive_fields() from public, anon, authenticated;
revoke execute on function public.protect_team_sensitive_fields() from public, anon, authenticated;
revoke execute on function public.reset_fair_play_score_annually() from public, anon, authenticated;
revoke execute on function public.sync_booking_players_table() from public, anon, authenticated;
revoke execute on function public.sync_head_to_head_on_result_insert() from public, anon, authenticated;
revoke execute on function public.sync_notification_message_body() from public, anon, authenticated;
revoke execute on function public.sync_owner_has_stadium() from public, anon, authenticated;
revoke execute on function public.sync_owner_has_stadium_on_soft_delete() from public, anon, authenticated;
revoke execute on function public.trg_fn_enforce_booking_state_machine() from public, anon, authenticated;
revoke execute on function public.trg_fn_protect_user_sensitive_fields() from public, anon, authenticated;

create or replace function public.get_current_user_role(p_user_id uuid default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid; v_user record; v_caller_role text;
begin
  v_uid:=coalesce(p_user_id,auth.uid());
  if v_uid is null then return jsonb_build_object('success',false,'error','NO_USER_ID'); end if;
  if auth.role()<>'service_role' then
    if auth.uid() is null then return jsonb_build_object('success',false,'error','AUTHENTICATION_REQUIRED'); end if;
    if v_uid is distinct from auth.uid() then
      select role into v_caller_role from public.users where id=auth.uid();
      if coalesce(v_caller_role,'') not in ('admin','co_founder','cofounder','super_admin') then
        return jsonb_build_object('success',false,'error','UNAUTHORIZED');
      end if;
    end if;
  end if;
  select id,role,subscription_plan,trial_ends_at,is_registration_complete,is_onboarding_confirmed,has_stadium
  into v_user from public.users where id=v_uid;
  if not found then return jsonb_build_object('success',false,'error','USER_NOT_FOUND'); end if;
  return jsonb_build_object('success',true,'role',v_user.role,'subscription_plan',v_user.subscription_plan,'trial_ends_at',v_user.trial_ends_at,'is_registration_complete',v_user.is_registration_complete,'is_onboarding_confirmed',v_user.is_onboarding_confirmed,'has_stadium',v_user.has_stadium);
end; $$;

create or replace function public.check_owner_stadium_limit(p_owner_id uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_owner record; v_count int; v_max_allowed int:=0; v_is_active_trial boolean:=false; v_is_sub_active boolean:=false; v_caller_role text;
begin
  if auth.role()<>'service_role' then
    if auth.uid() is null then return jsonb_build_object('allowed',false,'message','Authentication required.'); end if;
    if p_owner_id is distinct from auth.uid() then
      select role into v_caller_role from public.users where id=auth.uid();
      if coalesce(v_caller_role,'') not in ('admin','co_founder','cofounder','super_admin') then return jsonb_build_object('allowed',false,'message','Unauthorized'); end if;
    end if;
  end if;
  select * into v_owner from public.users where id=p_owner_id;
  if not found then return jsonb_build_object('allowed',false,'message','المستخدم غير موجود.'); end if;
  if v_owner.role in ('admin','co_founder','super_admin') then return jsonb_build_object('allowed',true,'current_count',0,'max_allowed',999); end if;
  v_is_active_trial:=(coalesce(v_owner.subscription_plan,'free_trial')='free_trial' and ((v_owner.trial_ends_at is not null and v_owner.trial_ends_at>now()) or (v_owner.trial_ends_at is null and v_owner.created_at+interval '60 days'>now())));
  v_is_sub_active:=(v_owner.subscription_expires_at is not null and v_owner.subscription_expires_at>now());
  if v_owner.subscription_plan='pro' and v_is_sub_active then v_max_allowed:=3;
  elsif (v_owner.subscription_plan='basic' and v_is_sub_active) or v_is_active_trial then v_max_allowed:=1;
  else v_max_allowed:=0; end if;
  select count(*) into v_count from public.stadiums where owner_id=p_owner_id and is_deleted_by_owner=false;
  if v_count>=v_max_allowed then return jsonb_build_object('allowed',false,'current_count',v_count,'max_allowed',v_max_allowed,'message','لقد وصلت للحد الأقصى للملاعب المسموح بها في باقتك ('||v_max_allowed||' ملاعب). يرجى ترقية باقتك لإضافة ملاعب جديدة.'); end if;
  return jsonb_build_object('allowed',true,'current_count',v_count,'max_allowed',v_max_allowed);
end; $$;

create or replace function public.check_extension_available(p_booking_id uuid,p_new_end_time timestamptz)
returns boolean language sql security definer set search_path=public as $$
  select exists (
    select 1 from public.bookings b
    where b.id=p_booking_id and (b.created_by_user_id=auth.uid() or b.user_id=auth.uid() or b.owner_id=auth.uid()
      or exists(select 1 from public.users u where u.id=auth.uid() and u.role in ('admin','co_founder','cofounder','super_admin')))
  )
  and not exists (
    select 1 from public.bookings b2
    where b2.stadium_id=(select stadium_id from public.bookings where id=p_booking_id)
      and b2.id<>p_booking_id and b2.status<>'cancelled'
      and b2.start_time<p_new_end_time
      and b2.end_time>(select end_time from public.bookings where id=p_booking_id)
  );
$$;

create or replace function public.submit_owner_verification(p_owner_id uuid,p_additional_data jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=coalesce(p_owner_id,auth.uid()); v_caller_role text;
begin
  if v_uid is null then return jsonb_build_object('success',false,'error','Owner ID required'); end if;
  if auth.role()<>'service_role' then
    if auth.uid() is null then return jsonb_build_object('success',false,'error','AUTHENTICATION_REQUIRED'); end if;
    if v_uid is distinct from auth.uid() then
      select role into v_caller_role from public.users where id=auth.uid();
      if coalesce(v_caller_role,'') not in ('admin','co_founder','cofounder','super_admin') then return jsonb_build_object('success',false,'error','UNAUTHORIZED'); end if;
    end if;
  end if;
  update public.users set verification_status='pending',is_registration_complete=true,has_stadium=true,additional_data=coalesce(additional_data,'{}'::jsonb)||p_additional_data,updated_at=timezone('utc',now()) where id=v_uid;
  return jsonb_build_object('success',true,'message','Owner verification submitted successfully');
end; $$;

commit;
