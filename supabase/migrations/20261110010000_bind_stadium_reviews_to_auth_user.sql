-- Bind stadium review writes to the authenticated caller.
-- Prepared on the working branch only; do not apply to production without
-- reviewing the migration and running the database security/advisor checks.

create or replace function public.submit_stadium_review_atomic(
    p_stadium_id     uuid,
    p_user_id        uuid,
    p_user_name      text,
    p_user_image_url text,
    p_rating         int,
    p_comment        text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id       uuid := auth.uid();
    v_owner_id      uuid;
    v_has_booking   boolean;
    v_avg_rating    numeric(3, 2);
    v_total_reviews int;
begin
    if v_user_id is null then
        raise exception 'authentication_required';
    end if;

    -- Keep the legacy parameter for API compatibility, but never trust it as
    -- an authorization source.
    if p_user_id is distinct from v_user_id then
        raise exception 'review_user_mismatch';
    end if;

    if p_rating < 1 or p_rating > 5 then
        raise exception 'invalid_review_rating';
    end if;

    if char_length(coalesce(p_comment, '')) > 500 then
        raise exception 'review_comment_too_long';
    end if;

    select s.owner_id
      into v_owner_id
      from public.stadiums as s
     where s.id = p_stadium_id
       and coalesce(s.is_deleted_by_owner, false) = false;

    if v_owner_id is null then
        raise exception 'stadium_not_found';
    end if;

    if v_owner_id = v_user_id then
        raise exception 'cannot_review_own_stadium';
    end if;

    -- A rating represents a played visit, not merely a confirmed future slot.
    select exists (
        select 1
          from public.bookings as b
         where b.stadium_id = p_stadium_id
           and (
               b.user_id = v_user_id
               or b.created_by_user_id = v_user_id::text
               or v_user_id = any(coalesce(b.joined_user_ids, array[]::uuid[]))
           )
           and b.status = 'completed'
    )
      into v_has_booking;

    if not v_has_booking then
        raise exception 'must_have_completed_booking';
    end if;

    insert into public.reviews (
        stadium_id,
        user_id,
        user_name,
        user_image_url,
        rating,
        review_text,
        created_at
    )
    values (
        p_stadium_id,
        v_user_id,
        left(trim(coalesce(p_user_name, '')), 120),
        trim(coalesce(p_user_image_url, '')),
        p_rating,
        trim(coalesce(p_comment, '')),
        timezone('utc', now())
    )
    on conflict (stadium_id, user_id)
    do update set
        rating = excluded.rating,
        review_text = excluded.review_text,
        user_name = excluded.user_name,
        user_image_url = excluded.user_image_url,
        created_at = timezone('utc', now());

    select round(coalesce(avg(r.rating::numeric), 5.0), 1), count(*)
      into v_avg_rating, v_total_reviews
      from public.reviews as r
     where r.stadium_id = p_stadium_id;

    update public.stadiums
       set rating = v_avg_rating,
           reviews_count = v_total_reviews,
           updated_at = timezone('utc', now())
     where id = p_stadium_id;

    return jsonb_build_object(
        'success', true,
        'new_rating', v_avg_rating,
        'total_reviews', v_total_reviews
    );
end;
$$;

revoke all on function public.submit_stadium_review_atomic(
    uuid, uuid, text, text, int, text
) from public, anon, authenticated, service_role;

grant execute on function public.submit_stadium_review_atomic(
    uuid, uuid, text, text, int, text
) to authenticated;
