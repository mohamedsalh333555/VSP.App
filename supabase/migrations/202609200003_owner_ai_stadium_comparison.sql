CREATE OR REPLACE FUNCTION public.get_owner_ai_stadium_comparison(
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
    v_period text := lower(coalesce(trim(p_period), '30d'));
    v_days numeric;
    v_prev_from timestamptz;
    v_prev_to timestamptz;
    v_rows jsonb;
BEGIN
    IF v_caller_id IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
    END IF;

    IF v_caller_id IS NOT NULL THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
        IF v_caller_id <> p_owner_id
           AND coalesce(v_caller_role, '') NOT IN ('admin', 'co_founder')
           AND current_user NOT IN ('postgres', 'service_role') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized access to stadium comparison');
        END IF;
    END IF;

    v_from := CASE v_period
        WHEN '7d' THEN v_now - interval '7 days'
        WHEN '90d' THEN v_now - interval '90 days'
        WHEN 'all' THEN '1970-01-01 00:00:00+00'::timestamptz
        ELSE v_now - interval '30 days'
    END;

    v_days := greatest(1, extract(epoch FROM (v_now - v_from)) / 86400.0);

    IF v_period <> 'all' THEN
        v_prev_to := v_from;
        v_prev_from := v_prev_to - (v_now - v_from);
    END IF;

    SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.realized_revenue DESC, x.bookings_count DESC), '[]'::jsonb)
    INTO v_rows
    FROM (
        SELECT
            s.id AS stadium_id,
            s.name AS stadium_name,
            count(b.id)::int AS bookings_count,
            count(*) FILTER (WHERE b.status = 'completed')::int AS completed_bookings,
            count(*) FILTER (WHERE b.status = 'cancelled')::int AS cancelled_bookings,
            round(coalesce(sum(b.total_price),0),2) AS gross_booking_value,
            round(coalesce(sum(b.total_price) FILTER (
                WHERE b.status = 'completed'
                  AND (b.payment_status = 'paid' OR b.is_paid = true)
            ),0),2) AS realized_revenue,
            round(coalesce(sum(
                CASE
                    WHEN b.id IS NULL OR b.status = 'cancelled' THEN 0
                    ELSE greatest(0, extract(epoch FROM (
                        least(b.end_time, v_now) - greatest(b.start_time, v_from)
                    )) / 3600.0)
                END
            ),0),2) AS booked_hours,
            CASE
                WHEN count(b.id) > 0
                THEN round((count(*) FILTER (WHERE b.status = 'cancelled')::numeric / count(b.id)::numeric) * 100.0, 2)
                ELSE 0
            END AS cancellation_rate_pct,

            CASE WHEN v_period <> 'all' THEN (
                SELECT count(*)::int FROM public.bookings pb
                WHERE pb.stadium_id = s.id
                  AND pb.created_at >= v_prev_from
                  AND pb.created_at < v_prev_to
            ) ELSE NULL END AS previous_bookings_count,

            CASE WHEN v_period <> 'all' THEN (
                SELECT round(coalesce(sum(pb.total_price) FILTER (
                    WHERE pb.status = 'completed'
                      AND (pb.payment_status = 'paid' OR pb.is_paid = true)
                ),0),2)
                FROM public.bookings pb
                WHERE pb.stadium_id = s.id
                  AND pb.created_at >= v_prev_from
                  AND pb.created_at < v_prev_to
            ) ELSE NULL END AS previous_realized_revenue

        FROM public.stadiums s
        LEFT JOIN public.bookings b
          ON b.stadium_id = s.id
         AND b.created_at >= v_from
         AND b.created_at <= v_now
        WHERE s.owner_id = p_owner_id
          AND coalesce(s.is_deleted_by_owner, false) = false
        GROUP BY s.id, s.name
    ) x;

    RETURN jsonb_build_object(
        'success', true,
        'owner_id', p_owner_id,
        'period', v_period,
        'period_start', v_from,
        'period_end', v_now,
        'stadiums', v_rows
    );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.get_owner_ai_stadium_comparison(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_owner_ai_stadium_comparison(uuid, text) TO authenticated, service_role;