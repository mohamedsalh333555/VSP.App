-- Fix: submit_stadium_review_atomic
-- Bugs fixed:
--   1. "operator does not exist: uuid = text" -> cast created_by_user_id to UUID
--   2. review_count column -> reviews_count (correct column name)
--   3. Add UPSERT so a user can update their review (no duplicate key crash)

DROP FUNCTION IF EXISTS public.submit_stadium_review_atomic(UUID, UUID, TEXT, TEXT, INT, TEXT);
DROP FUNCTION IF EXISTS public.submit_stadium_review_atomic(UUID, UUID, TEXT, TEXT, NUMERIC, TEXT);

CREATE OR REPLACE FUNCTION public.submit_stadium_review_atomic(
    p_stadium_id     UUID,
    p_user_id        UUID,
    p_user_name      TEXT,
    p_user_image_url TEXT,
    p_rating         INT,
    p_comment        TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_owner_id      UUID;
    v_has_booking   BOOLEAN;
    v_avg_rating    NUMERIC(3, 2);
    v_total_reviews INT;
BEGIN
    -- 1. Prevent owner from reviewing their own stadium
    SELECT owner_id INTO v_owner_id
    FROM public.stadiums
    WHERE id = p_stadium_id;

    IF v_owner_id = p_user_id THEN
        RAISE EXCEPTION 'cannot_review_own_stadium';
    END IF;

    -- 2. Verify at least one confirmed/completed booking exists for this user
    --    FIX: cast created_by_user_id::uuid so the comparison types match
    SELECT EXISTS (
        SELECT 1
        FROM public.bookings
        WHERE stadium_id = p_stadium_id
          AND (
              user_id                     = p_user_id
              OR created_by_user_id::uuid = p_user_id
              OR p_user_id = ANY(COALESCE(joined_user_ids, ARRAY[]::uuid[]))
          )
          AND status IN ('confirmed', 'completed')
    ) INTO v_has_booking;

    IF NOT v_has_booking THEN
        RAISE EXCEPTION 'must_have_completed_booking';
    END IF;

    -- 3. Upsert the review (update if user already reviewed this stadium)
    INSERT INTO public.reviews (
        stadium_id, user_id, user_name, user_image_url, rating, review_text, created_at
    )
    VALUES (
        p_stadium_id, p_user_id, p_user_name, p_user_image_url,
        p_rating, p_comment, timezone('utc', now())
    )
    ON CONFLICT (stadium_id, user_id)
    DO UPDATE SET
        rating         = EXCLUDED.rating,
        review_text    = EXCLUDED.review_text,
        user_name      = EXCLUDED.user_name,
        user_image_url = EXCLUDED.user_image_url,
        created_at     = timezone('utc', now());

    -- 4. Recalculate stadium average rating
    SELECT ROUND(COALESCE(AVG(rating::numeric), 5.0), 1), COUNT(*)
    INTO v_avg_rating, v_total_reviews
    FROM public.reviews
    WHERE stadium_id = p_stadium_id;

    -- FIX: correct column name is reviews_count (not review_count)
    UPDATE public.stadiums
    SET rating        = v_avg_rating,
        reviews_count = v_total_reviews,
        updated_at    = timezone('utc', now())
    WHERE id = p_stadium_id;

    RETURN jsonb_build_object(
        'success',       true,
        'new_rating',    v_avg_rating,
        'total_reviews', v_total_reviews
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_stadium_review_atomic(UUID, UUID, TEXT, TEXT, INT, TEXT)
    TO authenticated, service_role;
