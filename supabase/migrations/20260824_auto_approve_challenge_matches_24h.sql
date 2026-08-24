-- =============================================================================
-- VSP PLATFORM - CHALLENGE MATCH 24-HOUR AUTO-APPROVAL & FAIR-PLAY CRON
-- =============================================================================
-- هذا الملف يسد الفجوة بين وعد الواجهة (خصم 5 نقاط واعتماد النتيجة بعد 24 ساعة)
-- وبين قاعدة بيانات Supabase.

CREATE OR REPLACE FUNCTION public.auto_approve_challenge_matches_24h()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_match RECORD;
    v_resolved_count INT := 0;
    v_stalling_team_id UUID;
BEGIN
    FOR v_match IN
        SELECT 
            b.id,
            b.player_team_id,
            b.opponent_team_id,
            b.result_submitted_by_team_id,
            b.pending_outcome,
            b.stadium_name
        FROM public.bookings b
        WHERE b.booking_type = 'challenge'
          AND b.match_result_status = 'waiting_opponent'
          AND b.pending_outcome IS NOT NULL
          AND COALESCE(b.cancelled_at, b.updated_at, b.created_at) < (NOW() - INTERVAL '24 hours')
    LOOP
        -- تحديد الفريق المماطل الذي لم يؤكد النتيجة خلال 24 ساعة
        IF v_match.result_submitted_by_team_id = v_match.player_team_id THEN
            v_stalling_team_id := v_match.opponent_team_id;
        ELSE
            v_stalling_team_id := v_match.player_team_id;
        END IF;

        -- 1. اعتماد النتيجة المعلقة رسمياً
        UPDATE public.bookings
        SET 
            match_result_status = 'confirmed',
            final_outcome = v_match.pending_outcome,
            updated_at = NOW()
        WHERE id = v_match.id;

        -- 2. خصم 5 نقاط لعب نظيف من الفريق المماطل (Fair Play Penalty)
        IF v_stalling_team_id IS NOT NULL THEN
            UPDATE public.teams
            SET 
                fair_play_score = GREATEST(0, COALESCE(fair_play_score, 100) - 5),
                updated_at = NOW()
            WHERE id = v_stalling_team_id;
        END IF;

        -- 3. تسجيل إشعار تلقائي للنظام
        INSERT INTO public.notifications (
            user_id,
            title,
            body,
            type,
            data,
            created_at
        )
        SELECT 
            tm.user_id,
            'اعتماد نتيجة المباراة تلقائياً ⚽',
            'تم اعتماد نتيجة مباراة التحدي على ملعب ' || v_match.stadium_name || ' تلقائياً لمرور 24 ساعة دون رد.',
            'challenge_auto_approved',
            jsonb_build_object('booking_id', v_match.id),
            NOW()
        FROM public.team_members tm
        WHERE tm.team_id IN (v_match.player_team_id, v_match.opponent_team_id);

        v_resolved_count := v_resolved_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'resolved_matches_count', v_resolved_count,
        'message', 'تم فحص واعتماد مباريات التحدي المتجاوزة لمهلة 24 ساعة بنجاح.'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.auto_approve_challenge_matches_24h() TO authenticated, service_role;

-- جدولة الدالة لتعمل دورياً كل ساعة بواسطة pg_cron إن وُجد
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        PERFORM cron.schedule(
            'auto_approve_challenge_matches_hourly',
            '0 * * * *',
            'SELECT public.auto_approve_challenge_matches_24h();'
        );
    END IF;
EXCEPTION WHEN OTHERS THEN
    NULL;
END;
$$;
