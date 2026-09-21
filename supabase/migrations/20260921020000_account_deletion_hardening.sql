-- Production schema change already applied via Supabase migration 20260921020000_account_deletion_hardening.
-- This file mirrors the deployed DDL for source control and future database reconstruction.
create or replace function public.delete_user_permanently(p_user_id uuid)
returns jsonb language plpgsql security definer
set search_path = public, pg_temp
as $function$
declare v_uid uuid := auth.uid(); v_role text;
begin
  if v_uid is null then return jsonb_build_object('success',false,'message','جلسة المستخدم غير صالحة.'); end if;
  if p_user_id is distinct from v_uid then
    select role into v_role from public.users where id=v_uid;
    if coalesce(v_role,'') not in ('admin','co_founder') then
      return jsonb_build_object('success',false,'message','غير مصرح بحذف هذا الحساب.');
    end if;
  end if;
  if exists (select 1 from public.bookings b where (b.created_by_user_id=p_user_id or b.user_id=p_user_id or b.owner_id=p_user_id) and b.status in ('pending','confirmed') and b.start_time>now()) then
    return jsonb_build_object('success',false,'message','لا يمكن حذف الحساب قبل انتهاء أو إلغاء الحجوزات القادمة.');
  end if;
  update public.bookings set owner_id=null,created_by_user_id=null,user_id=null
    where owner_id=p_user_id or created_by_user_id=p_user_id or user_id=p_user_id;
  update public.matchup_results set recorded_by=null where recorded_by=p_user_id;
  update public.matchup_teams set added_by_user_id=null where added_by_user_id=p_user_id;
  update public.vsp_1v1_tournaments set created_by=null where created_by=p_user_id;
  delete from public.user_blocks where blocker_id=p_user_id or blocked_user_id=p_user_id;
  delete from public.chat_messages where sender_id=p_user_id;
  delete from public.reports where reporter_id=p_user_id;
  delete from public.reviews where user_id=p_user_id;
  delete from public.notifications where user_id=p_user_id;
  delete from public.copilot_messages where user_id=p_user_id;
  delete from public.copilot_conversations where user_id=p_user_id;
  delete from public.owner_documents where owner_id=p_user_id;
  delete from public.player_trophies where user_id=p_user_id;
  delete from public.points_ledger where user_id=p_user_id;
  delete from public.referrals where inviter_user_id=p_user_id or invitee_user_id=p_user_id;
  delete from public.booking_players where user_id=p_user_id;
  delete from public.team_members where user_id=p_user_id;
  delete from public.vsp_1v1_registrations where user_id=p_user_id;
  delete from public.vsp_1v1_tournament_orders where user_id=p_user_id;
  delete from public.vsp_1v1_tournament_players where user_id=p_user_id;
  delete from public.payout_settlements where owner_id=p_user_id;
  delete from public.stadiums where owner_id=p_user_id;
  delete from public.teams where captain_id=p_user_id;
  update public.championships set champion_user_id=null where champion_user_id=p_user_id;
  update public.championships set prize_delivered_by=null where prize_delivered_by=p_user_id;
  update public.vsp_1v1_tournaments set champion_user_id=null where champion_user_id=p_user_id;
  update public.vsp_1v1_tournaments set prize_delivered_by=null where prize_delivered_by=p_user_id;
  update public.ai_copilot_audit_events set user_id=null where user_id=p_user_id;
  update public.banners set created_by=null where created_by=p_user_id;
  delete from public.users where id=p_user_id;
  delete from auth.users where id=p_user_id;
  return jsonb_build_object('success',true);
exception when others then return jsonb_build_object('success',false,'message','تعذر إكمال حذف الحساب بالكامل. لم يتم اعتماد العملية.');
end;
$function$;
revoke execute on function public.delete_user_permanently(uuid) from public,anon,authenticated;
grant execute on function public.delete_user_permanently(uuid) to authenticated,service_role;