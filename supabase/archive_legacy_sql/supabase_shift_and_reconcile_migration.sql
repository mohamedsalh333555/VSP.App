-- =============================================================================
-- VSP PLATFORM - SHIFT CLOSEOUT & CHALLENGE RECONCILIATION MIGRATION
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. دالة تقفيل الوردية اليومية واستلام كامل كاش الملعب بضغطة واحدة
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.close_owner_daily_shift(
    p_owner_id uuid,
    p_stadium_id uuid,
    p_operational_date date
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_updated_count INT := 0;
    v_total_cash_collected NUMERIC := 0;
BEGIN
    -- التحقق من صلاحية المالك أو المشرف
    IF auth.uid() != p_owner_id AND NOT EXISTS (
        SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'co_founder')
    ) THEN
        RAISE EXCEPTION 'غير مصرح لك بإجراء تسوية هذا الملعب.';
    END IF;

    -- تحديث جميع الحجوزات النقدية غير المدفوعة أو المعلقة في هذه الوردية
    WITH updated_rows AS (
        UPDATE public.bookings
        SET 
            is_paid = TRUE,
            payment_status = 'paid',
            deposit_paid = total_price,
            updated_at = NOW()
        WHERE stadium_id = p_stadium_id
          AND owner_id = p_owner_id
          AND (operational_date = p_operational_date OR (operational_date IS NULL AND DATE(start_time AT TIME ZONE 'Africa/Cairo') = p_operational_date))
          AND status != 'cancelled'
          AND (is_paid = FALSE OR payment_status != 'paid')
        RETURNING total_price, deposit_paid
    )
    SELECT 
        COUNT(*),
        COALESCE(SUM(total_price), 0)
    INTO v_updated_count, v_total_cash_collected
    FROM updated_rows;

    RETURN jsonb_build_object(
        'success', true,
        'updated_bookings_count', v_updated_count,
        'total_cash_collected', v_total_cash_collected,
        'message', 'تم تقفيل الوردية بنجاح وتأكيد استلام كامل النقدية.'
    );
END;
$$;

-- -----------------------------------------------------------------------------
-- 2. دالة اعتماد نتائج التحديات تلقائياً مع خصم 5 نقاط لعب نظيف عند المماطلة
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.auto_reconcile_single_entry_results()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    r RECORD;
    v_submitted_by uuid;
    v_stalling_team_id uuid;
    v_stalling_captain_id uuid;
    v_outcome text;
BEGIN
    FOR r IN 
        SELECT 
            id, player_team_id, opponent_team_id, 
            pending_outcome, result_submitted_by_team_id,
            updated_at
        FROM public.bookings
        WHERE booking_type = 'challenge'
          AND match_result_status = 'waitingOpponent'
          AND status != 'cancelled'
          AND updated_at <= NOW() - INTERVAL '24 hours'
    LOOP
        v_outcome := r.pending_outcome;
        v_submitted_by := r.result_submitted_by_team_id;

        -- تحديد الفريق المماطل
        IF v_submitted_by = r.player_team_id THEN
            v_stalling_team_id := r.opponent_team_id;
        ELSE
            v_stalling_team_id := r.player_team_id;
        END IF;

        -- 1. اعتماد النتيجة رسمياً
        UPDATE public.bookings
        SET 
            final_outcome = v_outcome,
            match_result_status = 'confirmed',
            status = 'completed',
            pending_outcome = NULL,
            result_submitted_by_team_id = NULL,
            notes = COALESCE(notes, '') || E'\n[SYSTEM: Auto-Approved after 24h timeout. 5 Fair-Play pts deducted from stalling team]',
            updated_at = NOW()
        WHERE id = r.id;

        -- 2. خصم 5 نقاط من تقييم اللعب النظيف للفريق المتجاهل
        IF v_stalling_team_id IS NOT NULL THEN
            UPDATE public.teams
            SET 
                fair_play_score = GREATEST(0, fair_play_score - 5),
                updated_at = NOW()
            WHERE id = v_stalling_team_id;

            -- إرسال إشعار تحذيري لكابتن الفريق
            SELECT captain_id INTO v_stalling_captain_id FROM public.teams WHERE id = v_stalling_team_id;
            IF v_stalling_captain_id IS NOT NULL THEN
                INSERT INTO public.notifications (user_id, title, body, type, booking_id, created_at, is_read)
                VALUES (
                    v_stalling_captain_id,
                    '⚠️ خصم نقاط اللعب النظيف لتجاهل النتيجة',
                    'تم اعتماد نتيجة المباراة تلقائياً وخصم 5 نقاط من تقييم فريقك لعدم الرد خلال مهلة الـ 24 ساعة.',
                    'info',
                    r.id,
                    NOW(),
                    FALSE
                );
            END IF;
        END IF;
    END LOOP;
END;
$$;

COMMIT;
