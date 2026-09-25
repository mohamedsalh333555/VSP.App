-- Prevent direct authenticated updates from changing booking identity, financial or lifecycle fields.
CREATE OR REPLACE FUNCTION public.vsp_guard_direct_booking_mutation()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE v_role text;
BEGIN
 IF coalesce(auth.role(),'')='service_role' OR current_user IN ('postgres','service_role') THEN RETURN NEW; END IF;
 SELECT role INTO v_role FROM public.users WHERE id=auth.uid();
 IF coalesce(v_role,'') IN ('admin','co_founder','cofounder','super_admin') THEN RETURN NEW; END IF;
 IF NEW.owner_id IS DISTINCT FROM OLD.owner_id OR NEW.user_id IS DISTINCT FROM OLD.user_id
 OR NEW.created_by_user_id IS DISTINCT FROM OLD.created_by_user_id OR NEW.stadium_id IS DISTINCT FROM OLD.stadium_id
 OR NEW.total_price IS DISTINCT FROM OLD.total_price OR NEW.vsp_commission IS DISTINCT FROM OLD.vsp_commission
 OR NEW.gateway_fee IS DISTINCT FROM OLD.gateway_fee OR NEW.platform_fee IS DISTINCT FROM OLD.platform_fee
 OR NEW.deposit_paid IS DISTINCT FROM OLD.deposit_paid OR NEW.is_deposit_paid IS DISTINCT FROM OLD.is_deposit_paid
 OR NEW.is_paid IS DISTINCT FROM OLD.is_paid OR NEW.payment_status IS DISTINCT FROM OLD.payment_status
 OR NEW.payment_method IS DISTINCT FROM OLD.payment_method OR NEW.payment_transaction_id IS DISTINCT FROM OLD.payment_transaction_id
 OR NEW.status IS DISTINCT FROM OLD.status OR NEW.cancelled_at IS DISTINCT FROM OLD.cancelled_at
 OR NEW.cancellation_reason IS DISTINCT FROM OLD.cancellation_reason OR NEW.created_at IS DISTINCT FROM OLD.created_at
 THEN RAISE EXCEPTION 'BOOKING_CORE_FIELDS_REQUIRE_SERVER_WORKFLOW'; END IF;
 RETURN NEW;
END;$function$;
DROP TRIGGER IF EXISTS trg_guard_direct_booking_mutation ON public.bookings;
CREATE TRIGGER trg_guard_direct_booking_mutation BEFORE UPDATE ON public.bookings FOR EACH ROW EXECUTE FUNCTION public.vsp_guard_direct_booking_mutation();
REVOKE EXECUTE ON FUNCTION public.vsp_guard_direct_booking_mutation() FROM anon,public,authenticated;
GRANT EXECUTE ON FUNCTION public.vsp_guard_direct_booking_mutation() TO service_role;