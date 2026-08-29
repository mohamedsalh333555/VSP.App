-- =========================================================================
-- VSP DATABASE SECURITY & BUG FIXES MIGRATION (2026)
-- =========================================================================

-- 1. إصلاح وتأمين حماية حقول المستخدمين الحساسة (قبل الإدخال والتعديل)
CREATE OR REPLACE FUNCTION public.protect_user_verification_fields()
RETURNS TRIGGER AS $$
DECLARE
    v_is_admin BOOLEAN := FALSE;
    v_jwt_role TEXT;
BEGIN
    -- استخراج رتبة الطلب من التوكن
    BEGIN
        v_jwt_role := current_setting('request.jwt.claims', true)::json->>'role';
    EXCEPTION WHEN OTHERS THEN
        v_jwt_role := NULL;
    END;

    -- التحقق إذا كان المستدعي مسؤول نظام (Admin / Co-Founder)
    SELECT EXISTS (
        SELECT 1 FROM public.users 
        WHERE id = auth.uid() AND role IN ('admin', 'co_founder')
    ) INTO v_is_admin;

    -- إذا كانت العملية ليست من Service Role وليست من الأدمن
    IF v_jwt_role IS DISTINCT FROM 'service_role' AND NOT v_is_admin THEN
        IF (TG_OP = 'INSERT') THEN
            -- فرض الرتبة الافتراضية والحالات الآمنة عند الإنشاء
            NEW.role := COALESCE(NEW.role, 'player');
            IF NEW.role NOT IN ('player', 'owner') THEN
                NEW.role := 'player';
            END IF;
            NEW.is_blocked := FALSE;
            NEW.no_show_count := 0;
            NEW.cash_booking_banned := FALSE;
            NEW.subscription_plan := 'free_trial';
            NEW.is_identity_verified := FALSE;
            NEW.verification_status := 'pending';
            NEW.has_stadium := FALSE;
        ELSIF (TG_OP = 'UPDATE') THEN
            -- منع التعديل على الحقول الحساسة
            NEW.role := OLD.role;
            NEW.is_blocked := OLD.is_blocked;
            NEW.no_show_count := OLD.no_show_count;
            NEW.cash_booking_banned := OLD.cash_booking_banned;
            NEW.subscription_plan := OLD.subscription_plan;
            NEW.subscription_expires_at := OLD.subscription_expires_at;
            NEW.trial_ends_at := OLD.trial_ends_at;
            NEW.is_identity_verified := OLD.is_identity_verified;
            NEW.verification_status := OLD.verification_status;
            NEW.has_stadium := OLD.has_stadium;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- إعادة ربط التريجر ليعمل مع الـ INSERT والـ UPDATE
DROP TRIGGER IF EXISTS trg_protect_user_verification ON public.users;
CREATE TRIGGER trg_protect_user_verification
    BEFORE INSERT OR UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.protect_user_verification_fields();


-- 2. تأمين سياسات RLS لجدول المستخدمين (منع تسريب الهواتف والحسابات للـ anon)
DROP POLICY IF EXISTS "users_select_authenticated" ON public.users;
DROP POLICY IF EXISTS "users_insert_own" ON public.users;

-- السماح للمستخدمين المسجلين فقط بالقراءة
CREATE POLICY "users_select_authenticated" ON public.users
    FOR SELECT
    TO authenticated
    USING (true);

-- تقييد الإدراج بـ auth.uid() الخاص بالمستخدم فقط
CREATE POLICY "users_insert_own" ON public.users
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = id);


-- 3. تأمين جدول الإشعارات (منع إرسال إشعارات عشوائية للمستخدمين من الـ Client)
DROP POLICY IF EXISTS "notifications_insert" ON public.notifications;

CREATE POLICY "notifications_insert" ON public.notifications
    FOR INSERT
    TO authenticated
    WITH CHECK (
        -- السماح للمستخدم بإرسال إشعار إذا كان طرفاً في الحجز المعني
        EXISTS (
            SELECT 1 FROM public.bookings b
            WHERE b.id = notifications.booking_id
              AND (b.user_id = auth.uid() OR b.owner_id = auth.uid() OR b.created_by_user_id = auth.uid() OR auth.uid() = ANY(COALESCE(b.joined_user_ids, ARRAY[]::uuid[])))
        )
        OR
        -- أو إذا كان المشرف هو المرسل
        EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = auth.uid() AND u.role IN ('admin', 'co_founder')
        )
    );


-- 4. إزالة دالة الترتيب القديمة المكسورة (التي تشير إلى tournament_teams غير الموجودة)
DROP FUNCTION IF EXISTS public.get_championship_standings(uuid);

-- التأكد من وجود الدالة الصحيحة الشاملة
CREATE OR REPLACE FUNCTION public.get_championship_standings(
    p_championship_id uuid,
    p_group_name text DEFAULT NULL::text
)
RETURNS TABLE(
    team_id uuid,
    team_name text,
    played bigint,
    won bigint,
    drawn bigint,
    lost bigint,
    goals_for bigint,
    goals_against bigint,
    goal_difference bigint,
    points bigint
) AS $$
BEGIN
    RETURN QUERY
    WITH all_roster_teams AS (
        SELECT cr.team_id AS t_id, t.name AS t_name
        FROM public.championship_rosters cr
        JOIN public.teams t ON t.id = cr.team_id
        WHERE cr.championship_id = p_championship_id
    ),
    match_results AS (
        SELECT
            m.home_team_id AS t_id,
            m.home_team_name AS t_name,
            1 AS p,
            CASE WHEN m.home_score > m.away_score THEN 1 ELSE 0 END AS w,
            CASE WHEN m.home_score = m.away_score THEN 1 ELSE 0 END AS d,
            CASE WHEN m.home_score < m.away_score THEN 1 ELSE 0 END AS l,
            COALESCE(m.home_score, 0) AS gf,
            COALESCE(m.away_score, 0) AS ga,
            CASE
                WHEN m.home_score > m.away_score THEN 3
                WHEN m.home_score = m.away_score THEN 1
                ELSE 0
            END AS pts
        FROM public.tournament_matches m
        WHERE m.championship_id = p_championship_id
          AND m.home_score IS NOT NULL
          AND m.away_score IS NOT NULL
          AND (p_group_name IS NULL OR m.group_name = p_group_name)

        UNION ALL

        SELECT
            m.away_team_id AS t_id,
            m.away_team_name AS t_name,
            1 AS p,
            CASE WHEN m.away_score > m.home_score THEN 1 ELSE 0 END AS w,
            CASE WHEN m.away_score = m.home_score THEN 1 ELSE 0 END AS d,
            CASE WHEN m.away_score < m.home_score THEN 1 ELSE 0 END AS l,
            COALESCE(m.away_score, 0) AS gf,
            COALESCE(m.away_score, 0) AS ga,
            CASE
                WHEN m.away_score > m.home_score THEN 3
                WHEN m.away_score = m.home_score THEN 1
                ELSE 0
            END AS pts
        FROM public.tournament_matches m
        WHERE m.championship_id = p_championship_id
          AND m.home_score IS NOT NULL
          AND m.away_score IS NOT NULL
          AND (p_group_name IS NULL OR m.group_name = p_group_name)
    )
    SELECT
        art.t_id AS team_id,
        MAX(art.t_name) AS team_name,
        COALESCE(SUM(r.p), 0) AS played,
        COALESCE(SUM(r.w), 0) AS won,
        COALESCE(SUM(r.d), 0) AS drawn,
        COALESCE(SUM(r.l), 0) AS lost,
        COALESCE(SUM(r.gf), 0) AS goals_for,
        COALESCE(SUM(r.ga), 0) AS goals_against,
        COALESCE((SUM(r.gf) - SUM(r.ga)), 0) AS goal_difference,
        COALESCE(SUM(r.pts), 0) AS points
    FROM all_roster_teams art
    LEFT JOIN match_results r ON r.t_id = art.t_id
    GROUP BY art.t_id
    ORDER BY points DESC, goal_difference DESC, goals_for DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
