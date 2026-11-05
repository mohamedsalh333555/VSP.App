-- Restore the booking trigger contract that exists in Production but was
-- absent from the isolated Staging project. Trigger functions already exist;
-- this migration only attaches the canonical triggers to public.bookings.

DROP TRIGGER IF EXISTS aaa_trg_enforce_booking_state_machine ON public.bookings;
CREATE TRIGGER aaa_trg_enforce_booking_state_machine
BEFORE UPDATE ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.trg_fn_enforce_booking_state_machine();

DROP TRIGGER IF EXISTS trg_audit_bookings ON public.bookings;
CREATE TRIGGER trg_audit_bookings
AFTER DELETE OR UPDATE ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.fn_log_sensitive_changes();

DROP TRIGGER IF EXISTS trg_bookings_operating_window ON public.bookings;
CREATE TRIGGER trg_bookings_operating_window
BEFORE INSERT OR UPDATE OF start_time, end_time ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.vsp_enforce_booking_operating_window();

DROP TRIGGER IF EXISTS trg_calculate_elo ON public.bookings;
CREATE TRIGGER trg_calculate_elo
BEFORE UPDATE OF status, final_outcome, match_result_status ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.calculate_elo_on_match_completion();

DROP TRIGGER IF EXISTS trg_guard_direct_booking_mutation ON public.bookings;
CREATE TRIGGER trg_guard_direct_booking_mutation
BEFORE UPDATE ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.vsp_guard_direct_booking_mutation();

DROP TRIGGER IF EXISTS trg_normalize_booking_pending_fees ON public.bookings;
CREATE TRIGGER trg_normalize_booking_pending_fees
BEFORE INSERT OR UPDATE ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.normalize_booking_pending_fees();

DROP TRIGGER IF EXISTS trg_notify_cash_booking_parties ON public.bookings;
CREATE TRIGGER trg_notify_cash_booking_parties
AFTER INSERT ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.notify_cash_booking_parties();

DROP TRIGGER IF EXISTS trg_prepare_collective_booking_fields ON public.bookings;
CREATE TRIGGER trg_prepare_collective_booking_fields
BEFORE INSERT OR UPDATE ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.prepare_collective_booking_fields();

DROP TRIGGER IF EXISTS trg_prevent_late_cancellation ON public.bookings;
CREATE TRIGGER trg_prevent_late_cancellation
BEFORE UPDATE ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.prevent_late_cancellation();

DROP TRIGGER IF EXISTS trg_protect_booking_sensitive_fields ON public.bookings;
CREATE TRIGGER trg_protect_booking_sensitive_fields
BEFORE UPDATE ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.protect_booking_sensitive_fields();

DROP TRIGGER IF EXISTS trg_protect_bookings_payment_fields ON public.bookings;
CREATE TRIGGER trg_protect_bookings_payment_fields
BEFORE UPDATE ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.protect_booking_payment_fields();

DROP TRIGGER IF EXISTS trg_sync_booking_players ON public.bookings;
CREATE TRIGGER trg_sync_booking_players
AFTER INSERT OR UPDATE OF joined_user_ids ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.sync_booking_players_table();

DROP TRIGGER IF EXISTS trg_sync_booking_public_feed ON public.bookings;
CREATE TRIGGER trg_sync_booking_public_feed
AFTER INSERT OR DELETE OR UPDATE ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.sync_booking_public_feed();

DROP TRIGGER IF EXISTS trg_sync_booking_user_ids ON public.bookings;
CREATE TRIGGER trg_sync_booking_user_ids
BEFORE INSERT OR UPDATE ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.sync_booking_user_ids();

DROP TRIGGER IF EXISTS trg_sync_challenge_booking_status ON public.bookings;
CREATE TRIGGER trg_sync_challenge_booking_status
BEFORE UPDATE OF status ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.trg_sync_challenge_booking_status();

DROP TRIGGER IF EXISTS trg_sync_player_phone_on_booking_insert ON public.bookings;
CREATE TRIGGER trg_sync_player_phone_on_booking_insert
BEFORE INSERT ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.sync_player_phone_on_booking_insert();

DROP TRIGGER IF EXISTS trg_validate_challenge_rosters ON public.bookings;
CREATE TRIGGER trg_validate_challenge_rosters
BEFORE INSERT OR UPDATE OF booking_type, player_team_id, opponent_team_id ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.validate_challenge_rosters();

DROP TRIGGER IF EXISTS trigger_enforce_cash_restrictions ON public.bookings;
CREATE TRIGGER trigger_enforce_cash_restrictions
BEFORE INSERT ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.enforce_cash_booking_restrictions();

DROP TRIGGER IF EXISTS trigger_log_booking_payment ON public.bookings;
CREATE TRIGGER trigger_log_booking_payment
AFTER INSERT OR UPDATE OF is_paid, payment_status ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.log_booking_payment_transaction();

DROP TRIGGER IF EXISTS trigger_sync_payment_reconcile ON public.bookings;
CREATE TRIGGER trigger_sync_payment_reconcile
BEFORE INSERT OR UPDATE ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.sync_payment_reconcile_state();
