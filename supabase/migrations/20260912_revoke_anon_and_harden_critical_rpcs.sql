-- Migration: 20260912_revoke_anon_and_harden_critical_rpcs
-- Description: Revoke EXECUTE from PUBLIC and anon for 22 critical RPC functions, and restrict payment confirmation/refunds to service_role only.

-- ============================================================================
-- 1. سحب صلاحيات التنفيذ من PUBLIC و anon لجميع الدوال الـ 22
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.admin_approve_championship_atomic(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_reject_championship_atomic(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.confirm_1v1_payment_atomic(text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.create_1v1_payment_order_atomic(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_owner_financial_summary(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.check_rate_limit(uuid, text, integer, integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.check_team_has_1v1_champion(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.crown_tournament_champion_atomic(uuid, uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_log_sensitive_changes() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.generate_tournament_bracket_atomic(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.global_search(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.increment_banner_clicks(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.increment_banner_views(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.join_1v1_tournament_atomic(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.join_championship_atomic(uuid, uuid, boolean, uuid[], text[], numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.leave_1v1_tournament_atomic(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.leave_championship_atomic(uuid, uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_1v1_prize_delivered_atomic(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.publish_1v1_final_standings_atomic(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.publish_1v1_tournament_atomic(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.record_1v1_refund_status_atomic(text, boolean, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.record_tournament_refund_status_atomic(text, boolean, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.record_tournament_refund_status_atomic(text, text, text, text) FROM PUBLIC, anon;

-- ============================================================================
-- 2. حصر دوال السيرفر والـ Webhooks على service_role فقط (منع المستخدم العادي)
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.confirm_1v1_payment_atomic(text, text) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.record_1v1_refund_status_atomic(text, boolean, text, text) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.record_tournament_refund_status_atomic(text, boolean, text, text) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.record_tournament_refund_status_atomic(text, text, text, text) FROM authenticated;

GRANT EXECUTE ON FUNCTION public.confirm_1v1_payment_atomic(text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.record_1v1_refund_status_atomic(text, boolean, text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.record_tournament_refund_status_atomic(text, boolean, text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.record_tournament_refund_status_atomic(text, text, text, text) TO service_role;

-- ============================================================================
-- 3. منح الصلاحية للمستخدمين المسجلين (authenticated) فقط للدوال التشغيلية
-- ============================================================================
GRANT EXECUTE ON FUNCTION public.create_1v1_payment_order_atomic(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_owner_financial_summary(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.check_rate_limit(uuid, text, integer, integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.check_team_has_1v1_champion(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.global_search(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.increment_banner_clicks(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.increment_banner_views(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.join_1v1_tournament_atomic(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.join_championship_atomic(uuid, uuid, boolean, uuid[], text[], numeric) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.leave_1v1_tournament_atomic(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.leave_championship_atomic(uuid, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_approve_championship_atomic(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_reject_championship_atomic(uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.crown_tournament_champion_atomic(uuid, uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.generate_tournament_bracket_atomic(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.mark_1v1_prize_delivered_atomic(uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.publish_1v1_final_standings_atomic(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.publish_1v1_tournament_atomic(uuid) TO authenticated, service_role;
