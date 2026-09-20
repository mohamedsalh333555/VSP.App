-- ==============================================================================
-- Migration: 202609200001_owner_ai_operational_insights.sql
-- Purpose: Server-authoritative operational analytics for Owner AI.
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.get_owner_ai_operational_insights(
    p_owner_id uuid,
    p_period text DEFAULT '30d'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
    v_caller_id uuid := auth.uid();
    v_caller_role text;
    v_now timestamptz := now();
    v_from timestamptz;
    v_to timestamptz := v_now;
    v_period text := lower(coalesce(trim(p_period), '30d'));
    v_period_days numeric := 30;
    v_total_bookings int := 0;
    v_completed_bookings int := 0;
    v_confirmed_bookings int := 0;
    v_cancelled_bookings int := 0;
    v_gross_booking_value numeric := 0;
    v_realized_revenue numeric := 0;
    v_booked_hours numeric := 0;
    v_available_hours numeric := 0;
    v_utilization_pct numeric := 0;
    v_cancellation_rate_pct numeric := 0;
    v_avg_booking_value numeric := 0;
    v_peak_hour int := null;
    v_peak_hour_bookings int := 0;
    v_stadium_count int := 0;
    v_debt numeric := 0;
    v_debt_limit numeric := 0;
    v_is_debt_blocked boolean := false;
    v_top_stadiums jsonb := '[]'::jsonb;
BEGIN
    IF v_caller_id IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
    END IF;

    IF v_caller_id IS NOT NULL THEN
        SELECT role INTO v_caller_role
        FROM public.users
        WHERE id = v_caller_id;

        IF v_caller_id <> p_owner_id
           AND coalesce(v_caller_role, '') NOT IN ('admin', 'co_founder')
           AND current_user NOT IN ('postgres', 'service_role') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized access to owner insights');
        END IF;
    END IF;

    v_from := CASE v_period
        WHEN '7d' THEN v_now - interval '7 days'
        WHEN '30d' THEN v_now - interval '30 days'
        WHEN '90d' THEN v_now - interval '90 days'
        WHEN 'all' THEN '1970-01-01 00:00:00+00'::timestamptz
        ELSE v_now - interval '30 days'
    END;

    v_period_days := greatest(
        1,
        extract(epoch FROM (v_to - v_from)) / 86400.0
    );

    SELECT
        count(*)::int,
        count(*) FILTER (WHERE status = 'completed')::int,
        count(*) FILTER (WHERE status = 'confirmed')::int,
        count(*) FILTER (WHERE status = 'cancelled')::int,
        coalesce(sum(total_price), 0)
    INTO
        v_total_bookings,
        v_completed_bookings,
        v_confirmed_bookings,
        v_cancelled_bookings,
        v_gross_booking_value
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND created_at >= v_from
      AND created_at <= v_to;

    SELECT coalesce(sum(total_price), 0)
    INTO v_realized_revenue
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND created_at >= v_from
      AND created_at <= v_to
      AND status = 'completed'
      AND (payment_status = 'paid' OR is_paid = true);

    SELECT coalesce(sum(
        greatest(
            0,
            extract(epoch FROM (
                least(end_time, v_to) - greatest(start_time, v_from)
            )) / 3600.0
        )
    ), 0)
    INTO v_booked_hours
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND status <> 'cancelled'
      AND end_time > v_from
      AND start_time < v_to;

    SELECT count(*)::int
    INTO v_stadium_count
    FROM public.stadiums
    WHERE owner_id = p_owner_id
      AND coalesce(is_deleted_by_owner, false) = false;

    SELECT coalesce(sum(
        (
            CASE
                WHEN s.closing_time > s.opening_time
                    THEN extract(epoch FROM (s.closing_time - s.opening_time)) / 3600.0
                ELSE
                    (extract(epoch FROM (s.closing_time - s.opening_time)) / 3600.0) + 24.0
            END
        )
        -
        CASE
            WHEN coalesce(s.is_split_shift, false)
             AND s.break_start_time IS NOT NULL
             AND s.break_end_time IS NOT NULL
            THEN
                CASE
                    WHEN s.break_end_time >= s.break_start_time
                        THEN extract(epoch FROM (s.break_end_time - s.break_start_time)) / 3600.0
                    ELSE
                        (extract(epoch FROM (s.break_end_time - s.break_start_time)) / 3600.0) + 24.0
                END
            ELSE 0
        END
        * v_period_days
    ), 0)
    INTO v_available_hours
    FROM public.stadiums s
    WHERE s.owner_id = p_owner_id
      AND coalesce(s.is_deleted_by_owner, false) = false
      AND s.opening_time IS NOT NULL
      AND s.closing_time IS NOT NULL;

    IF v_available_hours > 0 THEN
        v_utilization_pct := round((v_booked_hours / v_available_hours) * 100.0, 2);
    END IF;

    IF v_total_bookings > 0 THEN
        v_cancellation_rate_pct := round((v_cancelled_bookings::numeric / v_total_bookings::numeric) * 100.0, 2);
        v_avg_booking_value := round(v_gross_booking_value / v_total_bookings::numeric, 2);
    END IF;

    SELECT extract(hour FROM timezone('Africa/Cairo', start_time))::int, count(*)::int
    INTO v_peak_hour, v_peak_hour_bookings
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND created_at >= v_from
      AND created_at <= v_to
      AND status <> 'cancelled'
    GROUP BY extract(hour FROM timezone('Africa/Cairo', start_time))
    ORDER BY count(*) DESC, extract(hour FROM timezone('Africa/Cairo', start_time))
    LIMIT 1;

    SELECT
        coalesce(sum(accumulated_cash_debt), 0),
        coalesce(max(debt_limit), 500),
        coalesce(bool_or(is_debt_blocked), false)
    INTO v_debt, v_debt_limit, v_is_debt_blocked
    FROM public.users
    WHERE id = p_owner_id;

    SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.realized_revenue DESC), '[]'::jsonb)
    INTO v_top_stadiums
    FROM (
        SELECT
            s.id,
            s.name,
            count(b.id)::int AS bookings_count,
            round(coalesce(sum(b.total_price) FILTER (
                WHERE b.status = 'completed'
                  AND (b.payment_status = 'paid' OR b.is_paid = true)
            ), 0), 2) AS realized_revenue,
            round(coalesce(sum(
                CASE
                    WHEN b.id IS NULL OR b.status = 'cancelled' THEN 0
                    ELSE greatest(
                        0,
                        extract(epoch FROM (
                            least(b.end_time, v_to) - greatest(b.start_time, v_from)
                        )) / 3600.0
                    )
                END
            ), 0), 2) AS booked_hours
        FROM public.stadiums s
        LEFT JOIN public.bookings b
          ON b.stadium_id = s.id
         AND b.created_at >= v_from
         AND b.created_at <= v_to
        WHERE s.owner_id = p_owner_id
          AND coalesce(s.is_deleted_by_owner, false) = false
        GROUP BY s.id, s.name
        ORDER BY realized_revenue DESC
        LIMIT 10
    ) x;

    RETURN jsonb_build_object(
        'success', true,
        'owner_id', p_owner_id,
        'period', v_period,
        'period_start', v_from,
        'period_end', v_to,
        'stadium_count', v_stadium_count,
        'total_bookings', v_total_bookings,
        'completed_bookings', v_completed_bookings,
        'confirmed_bookings', v_confirmed_bookings,
        'cancelled_bookings', v_cancelled_bookings,
        'gross_booking_value', round(v_gross_booking_value, 2),
        'realized_revenue', round(v_realized_revenue, 2),
        'booked_hours', round(v_booked_hours, 2),
        'available_hours_estimate', round(v_available_hours, 2),
        'utilization_pct', v_utilization_pct,
        'cancellation_rate_pct', v_cancellation_rate_pct,
        'average_booking_value', v_avg_booking_value,
        'peak_start_hour_cairo', v_peak_hour,
        'peak_hour_bookings', v_peak_hour_bookings,
        'accumulated_cash_debt', round(v_debt, 2),
        'debt_limit', round(v_debt_limit, 2),
        'is_debt_blocked', v_is_debt_blocked,
        'top_stadiums', v_top_stadiums
    );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.get_owner_ai_operational_insights(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_owner_ai_operational_insights(uuid, text) TO authenticated, service_role;
