-- ============================================================================
-- VSP Aswan Seed Data Rollback / Cleanup Script & Stored Procedure
-- ============================================================================

CREATE OR REPLACE FUNCTION public.purge_aswan_seed_data()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_del_bookings int := 0;
    v_del_matches int := 0;
    v_del_champs int := 0;
    v_del_1v1_tp int := 0;
    v_del_1v1_t int := 0;
    v_del_1v1_p int := 0;
    v_del_trophies int := 0;
    v_del_tm int := 0;
    v_del_h2h int := 0;
    v_del_teams int := 0;
    v_del_stadiums int := 0;
    v_del_auth_users int := 0;
    v_del_public_users int := 0;
BEGIN
    -- 1. Delete booking players and bookings
    DELETE FROM public.booking_players
    WHERE booking_id IN (
        SELECT id FROM public.bookings
        WHERE stadium_id >= 'b1000000-0000-0000-0000-000000000001'::uuid 
          AND stadium_id <= 'b1000000-0000-0000-0000-000000000010'::uuid
           OR id = 'f1000000-0000-0000-0000-000000000001'::uuid
    );

    WITH deleted AS (
        DELETE FROM public.bookings
        WHERE stadium_id >= 'b1000000-0000-0000-0000-000000000001'::uuid 
          AND stadium_id <= 'b1000000-0000-0000-0000-000000000010'::uuid
           OR id = 'f1000000-0000-0000-0000-000000000001'::uuid
           OR created_by_user_id IN (SELECT id FROM public.users WHERE email LIKE '%@aswan.seed.vsp.app')
        RETURNING id
    )
    SELECT COUNT(*) INTO v_del_bookings FROM deleted;

    -- 2. Delete tournament matches & championships
    WITH del_m AS (
        DELETE FROM public.tournament_matches
        WHERE championship_id = 'd1000000-0000-0000-0000-000000000001'::uuid
        RETURNING id
    )
    SELECT COUNT(*) INTO v_del_matches FROM del_m;

    WITH del_c AS (
        DELETE FROM public.championships
        WHERE id = 'd1000000-0000-0000-0000-000000000001'::uuid
        RETURNING id
    )
    SELECT COUNT(*) INTO v_del_champs FROM del_c;

    -- 3. Delete 1v1 data and trophies
    WITH del_tp AS (
        DELETE FROM public.vsp_1v1_tournament_players
        WHERE tournament_id = 'e1000000-0000-0000-0000-000000000001'::uuid
        RETURNING id
    )
    SELECT COUNT(*) INTO v_del_1v1_tp FROM del_tp;

    WITH del_t AS (
        DELETE FROM public.vsp_1v1_tournaments
        WHERE id = 'e1000000-0000-0000-0000-000000000001'::uuid
        RETURNING id
    )
    SELECT COUNT(*) INTO v_del_1v1_t FROM del_t;

    WITH del_p AS (
        DELETE FROM public.vsp_1vs1_players
        WHERE id IN (SELECT id FROM public.users WHERE email LIKE '%@aswan.seed.vsp.app')
        RETURNING id
    )
    SELECT COUNT(*) INTO v_del_1v1_p FROM del_p;

    WITH del_tr AS (
        DELETE FROM public.player_trophies
        WHERE user_id IN (SELECT id FROM public.users WHERE email LIKE '%@aswan.seed.vsp.app')
        RETURNING id
    )
    SELECT COUNT(*) INTO v_del_trophies FROM del_tr;

    -- 4. Delete team head to head and matchup results
    WITH del_h2h_rows AS (
        DELETE FROM public.team_head_to_head
        WHERE team_a_id >= 'c1000000-0000-0000-0000-000000000001'::uuid 
          AND team_a_id <= 'c1000000-0000-0000-0000-000000000010'::uuid
           OR team_b_id >= 'c1000000-0000-0000-0000-000000000001'::uuid 
          AND team_b_id <= 'c1000000-0000-0000-0000-000000000010'::uuid
        RETURNING team_a_id
    )
    SELECT COUNT(*) INTO v_del_h2h FROM del_h2h_rows;

    -- 5. Delete team members and teams
    WITH del_tm_rows AS (
        DELETE FROM public.team_members
        WHERE team_id >= 'c1000000-0000-0000-0000-000000000001'::uuid 
          AND team_id <= 'c1000000-0000-0000-0000-000000000010'::uuid
           OR user_id IN (SELECT id FROM public.users WHERE email LIKE '%@aswan.seed.vsp.app')
        RETURNING team_id
    )
    SELECT COUNT(*) INTO v_del_tm FROM del_tm_rows;

    WITH del_teams_rows AS (
        DELETE FROM public.teams
        WHERE id >= 'c1000000-0000-0000-0000-000000000001'::uuid 
          AND id <= 'c1000000-0000-0000-0000-000000000010'::uuid
        RETURNING id
    )
    SELECT COUNT(*) INTO v_del_teams FROM del_teams_rows;

    -- 6. Delete stadiums
    WITH del_s_rows AS (
        DELETE FROM public.stadiums
        WHERE id >= 'b1000000-0000-0000-0000-000000000001'::uuid 
          AND id <= 'b1000000-0000-0000-0000-000000000010'::uuid
           OR owner_id IN (SELECT id FROM public.users WHERE email LIKE '%@aswan.seed.vsp.app')
        RETURNING id
    )
    SELECT COUNT(*) INTO v_del_stadiums FROM del_s_rows;

    -- 7. Delete users from auth.users (cascades automatically to public.users via users_id_fkey)
    WITH del_auth_rows AS (
        DELETE FROM auth.users
        WHERE email LIKE '%@aswan.seed.vsp.app'
        RETURNING id
    )
    SELECT COUNT(*) INTO v_del_auth_users FROM del_auth_rows;

    -- Fallback cleanup on public.users just in case
    WITH del_pub_rows AS (
        DELETE FROM public.users
        WHERE email LIKE '%@aswan.seed.vsp.app'
        RETURNING id
    )
    SELECT COUNT(*) INTO v_del_public_users FROM del_pub_rows;

    RETURN jsonb_build_object(
        'success', true,
        'deleted_auth_users', v_del_auth_users,
        'deleted_public_users', v_del_public_users,
        'deleted_stadiums', v_del_stadiums,
        'deleted_teams', v_del_teams,
        'deleted_team_members', v_del_tm,
        'deleted_team_h2h', v_del_h2h,
        'deleted_championships', v_del_champs,
        'deleted_tournament_matches', v_del_matches,
        'deleted_1v1_tournament_players', v_del_1v1_tp,
        'deleted_1v1_tournaments', v_del_1v1_t,
        'deleted_1vs1_players', v_del_1v1_p,
        'deleted_trophies', v_del_trophies,
        'deleted_bookings', v_del_bookings
    );
END;
$$;

-- To execute rollback anytime:
-- SELECT public.purge_aswan_seed_data();
