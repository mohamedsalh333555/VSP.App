# -*- coding: utf-8 -*-
"""
Targeted Verification for Tournament SSOT Remediation against Supabase Production.
Tests:
1. record_match_result_and_advance_atomic hardening (negative scores, tied knockout penalties, winner mismatch, confirmed result_status).
2. get_championship_standings excludes non-authoritative (disputed) results.
3. crown_tournament_champion_atomic requires final match victory.
4. transition_championship_status_atomic blocks completion without crowned champion.
"""

import urllib.request
import json
import uuid
import sys

with open('env.json', 'r', encoding='utf-8') as f:
    env = json.load(f)

MANAGEMENT_URL = "https://api.supabase.com/v1/projects/mktqkddbcddrxjxabdua/database/query"

def run_sql(query_str):
    req = urllib.request.Request(
        MANAGEMENT_URL,
        data=json.dumps({"query": query_str}).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {env['SUPABASE_MANAGEMENT_KEY']}",
            "Content-Type": "application/json"
        }
    )
    try:
        res = urllib.request.urlopen(req)
        return json.loads(res.read())
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")
        print("SQL Error Response:", body)
        raise RuntimeError(f"HTTP Error {e.code}: {body}") from e

owner_id = "14e76a71-c5b5-41ff-bed0-0e3d3bccd1de" # Verified test owner

def run_rpc(func_call):
    sql = f"""
    SELECT r.res FROM (
        SELECT set_config('request.jwt.claims', '{{"sub": "{owner_id}", "role": "authenticated"}}', true) AS _cfg
    ) cfg, LATERAL (
        SELECT {func_call} AS res
    ) r;
    """
    return run_sql(sql)[0]["res"]

print("=" * 80)
print("RUNNING TARGETED TOURNAMENT SSOT REMEDIATION VERIFICATION ON SUPABASE PRODUCTION")
print("=" * 80)

# 1. Setup isolated test championship, teams, and matches
test_champ_id = str(uuid.uuid4())
team_a_id = str(uuid.uuid4())
team_b_id = str(uuid.uuid4())
final_match_id = str(uuid.uuid4())
group_match_id = str(uuid.uuid4())
roster_a_id = str(uuid.uuid4())

try:
    print("\n[Setup] Creating isolated test entities in Supabase...")
    setup_sql = f"""
    -- Insert test teams
    INSERT INTO public.teams (id, name, captain_id, created_at, updated_at)
    VALUES
      ('{team_a_id}', 'فريق الأبطال أ', '{owner_id}', now(), now()),
      ('{team_b_id}', 'فريق الفرسان ب', '{owner_id}', now(), now());

    -- Insert test championship
    INSERT INTO public.championships (
      id, name, owner_id, status, type, template_type,
      start_date, end_date, entry_fee, grand_prize, governorate,
      max_teams, joined_teams, paid_teams, created_at, updated_at
    ) VALUES (
      '{test_champ_id}', 'بطولة الاختبار الموحدة SSOT', '{owner_id}', 'ongoing', 'cup', 'custom',
      CURRENT_DATE, CURRENT_DATE + INTERVAL '7 days', 0, 0, 'القاهرة',
      4, ARRAY['{team_a_id}', '{team_b_id}']::text[], ARRAY['{team_a_id}', '{team_b_id}']::text[], now(), now()
    );

    -- Confirm registrations
    INSERT INTO public.championship_registrations (id, championship_id, team_id, registration_status, payment_status, created_at, updated_at)
    VALUES
      (gen_random_uuid(), '{test_champ_id}', '{team_a_id}', 'confirmed', 'paid', now(), now()),
      (gen_random_uuid(), '{test_champ_id}', '{team_b_id}', 'confirmed', 'paid', now(), now());

    -- Create frozen roster for Team A
    INSERT INTO public.championship_rosters (id, championship_id, team_id, is_frozen, frozen_at, created_at)
    VALUES ('{roster_a_id}', '{test_champ_id}', '{team_a_id}', true, now(), now());

    INSERT INTO public.championship_roster_players (id, roster_id, player_id)
    VALUES (gen_random_uuid(), '{roster_a_id}', '{owner_id}');

    -- Create Final Match (round_index = 0, next_match_id IS NULL)
    INSERT INTO public.tournament_matches (
      id, championship_id, round_index, match_index, next_match_id,
      home_team_id, home_team_name, away_team_id, away_team_name,
      status, result_status, is_completed, stage, match_day, updated_at
    ) VALUES (
      '{final_match_id}', '{test_champ_id}', 0, 0, NULL,
      '{team_a_id}', 'فريق الأبطال أ', '{team_b_id}', 'فريق الفرسان ب',
      'scheduled', 'scheduled', false, 'final', CURRENT_DATE, now()
    );
    """
    run_sql(setup_sql)
    print("  Isolated test entities created successfully.")

    # -------------------------------------------------------------
    # TEST 1: Negative Score Rejection
    # -------------------------------------------------------------
    print("\n>>> [Test 1] Testing negative score rejection in record_match_result_and_advance_atomic...")
    neg_res = run_rpc(f"public.record_match_result_and_advance_atomic('{final_match_id}', -1, 2)")
    print(f"  Negative score result: {neg_res}")
    assert neg_res.get("success") is False, "Must reject negative home score"
    assert "INVALID_SCORE" in neg_res.get("error", ""), "Error must indicate INVALID_SCORE"
    print("  ✅ Test 1 Passed: Negative scores strictly rejected.")

    # -------------------------------------------------------------
    # TEST 2: Tied Knockout Match Requires Penalties
    # -------------------------------------------------------------
    print("\n>>> [Test 2] Testing tied knockout match without penalties...")
    tied_res = run_rpc(f"public.record_match_result_and_advance_atomic('{final_match_id}', 1, 1)")
    print(f"  Tied score result: {tied_res}")
    assert tied_res.get("success") is False, "Must reject tied knockout match without penalties"
    assert "PENALTIES_REQUIRED" in tied_res.get("error", ""), "Error must indicate PENALTIES_REQUIRED"

    tied_pens_res = run_rpc(f"public.record_match_result_and_advance_atomic('{final_match_id}', 1, 1, 3, 3)")
    print(f"  Tied penalties result: {tied_pens_res}")
    assert tied_pens_res.get("success") is False, "Must reject tied penalties in knockout match"
    assert "PENALTIES_TIED" in tied_pens_res.get("error", ""), "Error must indicate PENALTIES_TIED"
    print("  ✅ Test 2 Passed: Tied knockout matches strictly require decisive penalties.")

    # -------------------------------------------------------------
    # TEST 3: Score vs Winner Mismatch Rejection
    # -------------------------------------------------------------
    print("\n>>> [Test 3] Testing winner/score mismatch rejection...")
    # Home score 2, away score 1 -> Winner must be Team A. Attempting to declare Team B:
    mismatch_res = run_rpc(f"public.record_match_result_and_advance_atomic('{final_match_id}', 2, 1, NULL, NULL, '{team_b_id}')")
    print(f"  Mismatch result: {mismatch_res}")
    assert mismatch_res.get("success") is False, "Must reject declaring losing team as winner"
    assert "WINNER_MISMATCH" in mismatch_res.get("error", ""), "Error must indicate WINNER_MISMATCH"
    print("  ✅ Test 3 Passed: Winner/score mismatch strictly rejected.")

    # -------------------------------------------------------------
    # TEST 4: Valid Result Records status=completed & result_status=confirmed
    # -------------------------------------------------------------
    print("\n>>> [Test 4] Testing valid result recording with confirmed result_status...")
    valid_res = run_rpc(f"public.record_match_result_and_advance_atomic('{final_match_id}', 2, 1, NULL, NULL, '{team_a_id}')")
    print(f"  Valid recording result: {valid_res}")
    assert valid_res.get("success") is True, f"Valid match result must succeed: {valid_res}"
    assert valid_res.get("result_status") == "confirmed"
    assert valid_res.get("status") == "completed"

    # Verify directly from table
    match_row = run_sql(f"SELECT status, result_status, is_completed, winner_id FROM public.tournament_matches WHERE id = '{final_match_id}';")[0]
    print(f"  DB match row: {match_row}")
    assert match_row["status"] == "completed"
    assert match_row["result_status"] == "confirmed"
    assert match_row["is_completed"] is True
    assert match_row["winner_id"] == team_a_id
    print("  ✅ Test 4 Passed: Authoritative status=completed & result_status=confirmed persisted in DB.")

    # -------------------------------------------------------------
    # TEST 5: Standings SSOT Excludes Disputed / Unconfirmed Matches
    # -------------------------------------------------------------
    print("\n>>> [Test 5] Testing standings exclusion of disputed results...")
    # Create a disputed league match between Team A and Team B
    disputed_match_id = str(uuid.uuid4())
    run_sql(f"""
    INSERT INTO public.tournament_matches (
      id, championship_id, round_index, match_index,
      home_team_id, home_team_name, away_team_id, away_team_name,
      home_score, away_score, status, result_status, is_completed, stage, match_day, updated_at
    ) VALUES (
      '{disputed_match_id}', '{test_champ_id}', 1, 0,
      '{team_b_id}', 'فريق الفرسان ب', '{team_a_id}', 'فريق الأبطال أ',
      5, 0, 'disputed', 'disputed', false, 'league', CURRENT_DATE, now()
    );
    """)

    standings = run_sql(f"SELECT * FROM public.get_championship_standings('{test_champ_id}');")
    print(f"  Standings with disputed match: {standings}")
    # The disputed 5-0 match must NOT be counted in standings
    team_b_standing = next((s for s in standings if s["team_id"] == team_b_id), None)
    if team_b_standing:
        assert team_b_standing["played"] == 1, "Disputed match must not increment played count"
        assert team_b_standing["won"] == 0, "Disputed match must not count as win"
        assert team_b_standing["points"] == 0, "Disputed match must not award points"
    print("  ✅ Test 5 Passed: Standings SSOT strictly excludes disputed/unconfirmed results.")

    # -------------------------------------------------------------
    # TEST 6: Champion SSOT Requires Final Match Victory
    # -------------------------------------------------------------
    print("\n>>> [Test 6] Testing crown_tournament_champion_atomic final winner requirement...")
    # Attempt to crown Team B (who lost the final match 1-2):
    crown_loser_res = run_rpc(f"public.crown_tournament_champion_atomic('{test_champ_id}', '{team_b_id}')")
    print(f"  Crown loser result: {crown_loser_res}")
    assert crown_loser_res.get("success") is False, "Must reject crowning losing finalist"
    assert "CHAMPION_IS_NOT_FINAL_WINNER" in crown_loser_res.get("error", "")

    # Clean up the disputed match so no unfinished matches block completion
    run_sql(f"DELETE FROM public.tournament_matches WHERE id = '{disputed_match_id}';")

    # Crown Team A (who won the final match):
    crown_winner_res = run_rpc(f"public.crown_tournament_champion_atomic('{test_champ_id}', '{team_a_id}')")
    print(f"  Crown winner result: {crown_winner_res}")
    assert crown_winner_res.get("success") is True, f"Crowning actual final winner must succeed: {crown_winner_res}"
    assert crown_winner_res.get("champion_team_id") == team_a_id
    print("  ✅ Test 6 Passed: Only actual final winner can be crowned champion.")

    # -------------------------------------------------------------
    # TEST 7: Completion Guard Blocks Ongoing -> Completed Bypass
    # -------------------------------------------------------------
    print("\n>>> [Test 7] Testing transition_championship_status_atomic completion guard...")
    # Create another championship in 'ongoing' with no crowned champion
    test_champ_uncrowned = str(uuid.uuid4())
    run_sql(f"""
    INSERT INTO public.championships (
      id, name, owner_id, status, type, template_type,
      start_date, end_date, entry_fee, grand_prize, governorate,
      max_teams, joined_teams, paid_teams, created_at, updated_at
    ) VALUES (
      '{test_champ_uncrowned}', 'بطولة غير متوجة', '{owner_id}', 'ongoing', 'cup', 'custom',
      CURRENT_DATE, CURRENT_DATE + INTERVAL '7 days', 0, 0, 'القاهرة',
      4, ARRAY['{team_a_id}', '{team_b_id}']::text[], ARRAY['{team_a_id}', '{team_b_id}']::text[], now(), now()
    );
    """)

    # Try to jump to completed without crowning champion
    try:
        res = run_rpc(f"public.transition_championship_status_atomic('{test_champ_uncrowned}', 'completed')")
        print(f"  Unexpected success: {res}")
        assert False, "Should have failed to transition ongoing -> completed without champion"
    except Exception as e:
        err_msg = str(e)
        print(f"  Caught expected transition exception: {err_msg}")
        assert "BLOCKED_BY_STATE" in err_msg or "crowning champion" in err_msg
        print("  ✅ Test 7 Passed: Ongoing -> Completed cannot bypass crowning and completion requirements.")

    # Cleanup test_champ_uncrowned
    run_sql(f"DELETE FROM public.championships WHERE id = '{test_champ_uncrowned}';")

    print("\n" + "=" * 80)
    print("ALL 7 TARGETED TOURNAMENT SSOT INTEGRATION TESTS PASSED (100%)!")
    print("=" * 80)

finally:
    # Cleanup test data
    print("\n[Cleanup] Cleaning up isolated test entities...")
    cleanup_sql = f"""
    DELETE FROM public.player_trophies WHERE championship_id = '{test_champ_id}';
    DELETE FROM public.tournament_matches WHERE championship_id = '{test_champ_id}';
    DELETE FROM public.championship_roster_players WHERE roster_id = '{roster_a_id}';
    DELETE FROM public.championship_rosters WHERE championship_id = '{test_champ_id}';
    DELETE FROM public.championship_registrations WHERE championship_id = '{test_champ_id}';
    DELETE FROM public.championships WHERE id = '{test_champ_id}';
    DELETE FROM public.teams WHERE id IN ('{team_a_id}', '{team_b_id}');
    """
    try:
        run_sql(cleanup_sql)
        print("  Cleanup completed successfully.")
    except Exception as e:
        print(f"  [WARN] Cleanup error: {e}")
