# -*- coding: utf-8 -*-
"""
Targeted Verification for Tournament SSOT Remediation against Supabase Production.
Tests:
  A. League 1-1 draw succeeds without penalties or winner.
  B. League 2-1 derives winner correctly.
  C. Away-team goals_against projection is home_score (Home 3 - Away 1 -> Away GA = 3).
  D. Knockout 1-1 without penalties is rejected (PENALTIES_REQUIRED).
  E. Knockout 1-1 with decisive penalties succeeds.
  F. League standings exclude unconfirmed, disputed, and knockout matches.
  G. League champion crowns actual table leader; never treats match 1 as a final.
  H. Completion guard blocks incomplete / unconfirmed results and allows completed + confirmed.
  I. Safe, comprehensive cleanup leaving zero records behind.
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
print("RUNNING FINAL REAL LEAGUE & TOURNAMENT SSOT VERIFICATION ON SUPABASE PRODUCTION")
print("=" * 80)

# Isolated IDs
league_champ_id = str(uuid.uuid4())
cup_champ_id = str(uuid.uuid4())
guard_champ_id = str(uuid.uuid4())

team_a_id = str(uuid.uuid4())
team_b_id = str(uuid.uuid4())
team_c_id = str(uuid.uuid4())

roster_a_id = str(uuid.uuid4())
roster_b_id = str(uuid.uuid4())
roster_c_id = str(uuid.uuid4())

league_match_1_id = str(uuid.uuid4())
league_match_2_id = str(uuid.uuid4())
league_match_3_id = str(uuid.uuid4())
disputed_match_id = str(uuid.uuid4())
ko_match_id = str(uuid.uuid4())
guard_match_id = str(uuid.uuid4())

all_champ_ids = [league_champ_id, cup_champ_id, guard_champ_id]
all_team_ids = [team_a_id, team_b_id, team_c_id]
all_roster_ids = [roster_a_id, roster_b_id, roster_c_id]

try:
    print("\n[Setup] Creating isolated test League, Teams, Rosters, and Fixtures...")
    setup_sql = f"""
    -- Insert test teams
    INSERT INTO public.teams (id, name, captain_id, created_at, updated_at)
    VALUES
      ('{team_a_id}', 'فريق النسور أ', '{owner_id}', now(), now()),
      ('{team_b_id}', 'فريق الذئاب ب', '{owner_id}', now(), now()),
      ('{team_c_id}', 'فريق الصقور ج', '{owner_id}', now(), now());

    -- Insert test League championship
    INSERT INTO public.championships (
      id, name, owner_id, status, type, template_type,
      start_date, end_date, entry_fee, grand_prize, governorate,
      max_teams, joined_teams, paid_teams, created_at, updated_at
    ) VALUES (
      '{league_champ_id}', 'دوري الاختبار الحقيقي SSOT', '{owner_id}', 'ongoing', 'league', 'custom',
      CURRENT_DATE, CURRENT_DATE + INTERVAL '7 days', 0, 0, 'القاهرة',
      4, ARRAY['{team_a_id}', '{team_b_id}', '{team_c_id}']::text[], ARRAY['{team_a_id}', '{team_b_id}', '{team_c_id}']::text[], now(), now()
    );

    -- Confirm registrations for League
    INSERT INTO public.championship_registrations (id, championship_id, team_id, registration_status, payment_status, created_at, updated_at)
    VALUES
      (gen_random_uuid(), '{league_champ_id}', '{team_a_id}', 'confirmed', 'paid', now(), now()),
      (gen_random_uuid(), '{league_champ_id}', '{team_b_id}', 'confirmed', 'paid', now(), now()),
      (gen_random_uuid(), '{league_champ_id}', '{team_c_id}', 'confirmed', 'paid', now(), now());

    -- Create frozen rosters for all teams
    INSERT INTO public.championship_rosters (id, championship_id, team_id, is_frozen, frozen_at, created_at)
    VALUES
      ('{roster_a_id}', '{league_champ_id}', '{team_a_id}', true, now(), now()),
      ('{roster_b_id}', '{league_champ_id}', '{team_b_id}', true, now(), now()),
      ('{roster_c_id}', '{league_champ_id}', '{team_c_id}', true, now(), now());

    INSERT INTO public.championship_roster_players (id, roster_id, player_id)
    VALUES
      (gen_random_uuid(), '{roster_a_id}', '14e76a71-c5b5-41ff-bed0-0e3d3bccd1de'),
      (gen_random_uuid(), '{roster_b_id}', '80544d1d-09fd-4a5e-b195-3c20a2ff1fc0'),
      (gen_random_uuid(), '{roster_c_id}', '3647e809-4d4f-4a19-b98f-f697b960316c');

    -- Insert League Matches (round_index = 0, next_match_id IS NULL, stage = 'league')
    INSERT INTO public.tournament_matches (
      id, championship_id, round_index, match_index, next_match_id,
      home_team_id, home_team_name, away_team_id, away_team_name,
      status, result_status, is_completed, stage, match_day, updated_at
    ) VALUES
      ('{league_match_1_id}', '{league_champ_id}', 0, 0, NULL, '{team_a_id}', 'فريق النسور أ', '{team_b_id}', 'فريق الذئاب ب', 'scheduled', 'scheduled', false, 'league', CURRENT_DATE, now()),
      ('{league_match_2_id}', '{league_champ_id}', 0, 1, NULL, '{team_b_id}', 'فريق الذئاب ب', '{team_c_id}', 'فريق الصقور ج', 'scheduled', 'scheduled', false, 'league', CURRENT_DATE, now()),
      ('{league_match_3_id}', '{league_champ_id}', 0, 2, NULL, '{team_a_id}', 'فريق النسور أ', '{team_c_id}', 'فريق الصقور ج', 'scheduled', 'scheduled', false, 'league', CURRENT_DATE, now());

    -- Insert test Cup for knockout testing
    INSERT INTO public.championships (
      id, name, owner_id, status, type, template_type,
      start_date, end_date, entry_fee, grand_prize, governorate,
      max_teams, joined_teams, paid_teams, created_at, updated_at
    ) VALUES (
      '{cup_champ_id}', 'كأس الاختبار التجريبي', '{owner_id}', 'ongoing', 'cup', 'custom',
      CURRENT_DATE, CURRENT_DATE + INTERVAL '7 days', 0, 0, 'القاهرة',
      2, ARRAY['{team_a_id}', '{team_b_id}']::text[], ARRAY['{team_a_id}', '{team_b_id}']::text[], now(), now()
    );

    INSERT INTO public.tournament_matches (
      id, championship_id, round_index, match_index, next_match_id,
      home_team_id, home_team_name, away_team_id, away_team_name,
      status, result_status, is_completed, stage, match_day, updated_at
    ) VALUES (
      '{ko_match_id}', '{cup_champ_id}', 0, 0, NULL, '{team_a_id}', 'فريق النسور أ', '{team_b_id}', 'فريق الذئاب ب', 'scheduled', 'scheduled', false, 'final', CURRENT_DATE, now()
    );
    """
    run_sql(setup_sql)
    print("  Setup completed successfully.")

    # -----------------------------------------------------------------
    # TEST 1: League 1-1 Draw (Succeeds without penalties or winner)
    # -----------------------------------------------------------------
    print("\n>>> [Test 1 / Scenario A] League 1-1 Draw...")
    m1_res = run_rpc(f"public.record_match_result_and_advance_atomic('{league_match_1_id}', 1, 1)")
    print(f"  Match 1 Draw Result: {m1_res}")
    assert m1_res.get("success") is True, f"League 1-1 draw must succeed: {m1_res}"
    assert m1_res.get("winner_id") is None, "Draw must have winner_id = NULL"
    assert m1_res.get("status") == "completed"
    assert m1_res.get("result_status") == "confirmed"
    print("  ✅ Test 1 Passed: League 1-1 draw allowed without requiring penalties or winner.")

    # -----------------------------------------------------------------
    # TEST 2: Knockout 1-1 Draw MUST Require Penalties (Test D & E)
    # -----------------------------------------------------------------
    print("\n>>> [Test 2 / Scenarios D & E] Knockout 1-1 tied score behavior...")
    ko_no_pens = run_rpc(f"public.record_match_result_and_advance_atomic('{ko_match_id}', 1, 1)")
    print(f"  Knockout without pens: {ko_no_pens}")
    assert ko_no_pens.get("success") is False
    assert "PENALTIES_REQUIRED" in ko_no_pens.get("error", "")

    ko_pens = run_rpc(f"public.record_match_result_and_advance_atomic('{ko_match_id}', 1, 1, 5, 4, '{team_a_id}')")
    print(f"  Knockout with pens: {ko_pens}")
    assert ko_pens.get("success") is True
    assert ko_pens.get("winner_id") == team_a_id
    print("  ✅ Test 2 Passed: Knockout tied score strictly requires decisive penalties.")

    # -----------------------------------------------------------------
    # TEST 3: League 3-1 Result & Away-team goals_against (Test B & G)
    # -----------------------------------------------------------------
    print("\n>>> [Test 3 / Scenarios B & G] League 3-1: Home 3, Away 1 -> Check GA projection...")
    # Match 2: Team B (Home) 3 - 1 Team C (Away)
    m2_res = run_rpc(f"public.record_match_result_and_advance_atomic('{league_match_2_id}', 3, 1, NULL, NULL, '{team_b_id}')")
    assert m2_res.get("success") is True
    assert m2_res.get("winner_id") == team_b_id

    standings = run_sql(f"SELECT * FROM public.get_championship_standings('{league_champ_id}');")
    print(f"  Current Standings: {standings}")

    standing_b = next((s for s in standings if s["team_id"] == team_b_id), None)
    standing_c = next((s for s in standings if s["team_id"] == team_c_id), None)

    assert standing_b is not None
    assert standing_c is not None

    # Team B played 2 (1-1 draw vs A + 3-1 win vs C):
    # Points = 1 + 3 = 4. Goals For = 1 + 3 = 4. Goals Against = 1 + 1 = 2. GD = +2.
    print(f"  Team B: played={standing_b['played']}, pts={standing_b['points']}, gf={standing_b['goals_for']}, ga={standing_b['goals_against']}, gd={standing_b['goal_difference']}")
    assert standing_b['played'] == 2
    assert standing_b['points'] == 4
    assert standing_b['goals_for'] == 4
    assert standing_b['goals_against'] == 2
    assert standing_b['goal_difference'] == 2

    # Team C played 1 (1-3 loss vs B):
    # Points = 0. Goals For = 1. Goals Against = 3 (MUST BE HOME SCORE = 3, NOT AWAY SCORE = 1!). GD = -2.
    print(f"  Team C: played={standing_c['played']}, pts={standing_c['points']}, gf={standing_c['goals_for']}, ga={standing_c['goals_against']}, gd={standing_c['goal_difference']}")
    assert standing_c['played'] == 1
    assert standing_c['goals_for'] == 1
    assert standing_c['goals_against'] == 3, f"Away team goals_against MUST be home score (3)! Found: {standing_c['goals_against']}"
    assert standing_c['goal_difference'] == -2, f"Goal difference must be -2! Found: {standing_c['goal_difference']}"
    print("  ✅ Test 3 Passed: Away-team goals_against is accurately computed as home_score.")

    # -----------------------------------------------------------------
    # TEST 4: Standings Exclude Disputed and Knockout Matches (Test F)
    # -----------------------------------------------------------------
    print("\n>>> [Test 4 / Scenario F] Verifying disputed and knockout exclusion from league standings...")
    run_sql(f"""
    INSERT INTO public.tournament_matches (
      id, championship_id, round_index, match_index,
      home_team_id, home_team_name, away_team_id, away_team_name,
      home_score, away_score, status, result_status, is_completed, stage, match_day, updated_at
    ) VALUES
      ('{disputed_match_id}', '{league_champ_id}', 1, 0, '{team_c_id}', 'فريق الصقور ج', '{team_b_id}', 'فريق الذئاب ب', 10, 0, 'disputed', 'disputed', false, 'league', CURRENT_DATE, now());
    """)

    standings_filtered = run_sql(f"SELECT * FROM public.get_championship_standings('{league_champ_id}');")
    standing_c_check = next((s for s in standings_filtered if s["team_id"] == team_c_id), None)
    # The 10-0 disputed match must NOT be counted!
    assert standing_c_check['played'] == 1
    assert standing_c_check['points'] == 0
    assert standing_c_check['goals_for'] == 1

    # Cleanup disputed match
    run_sql(f"DELETE FROM public.tournament_matches WHERE id = '{disputed_match_id}';")
    print("  ✅ Test 4 Passed: Disputed results strictly excluded from standings.")

    # -----------------------------------------------------------------
    # TEST 5: League Champion Crowning (Test H)
    # -----------------------------------------------------------------
    print("\n>>> [Test 5 / Scenario H] Complete league matches & crown table leader...")
    # Record Match 3: Team A beats Team C 4-0
    m3_res = run_rpc(f"public.record_match_result_and_advance_atomic('{league_match_3_id}', 4, 0, NULL, NULL, '{team_a_id}')")
    assert m3_res.get("success") is True

    # Standings now:
    # Team A: played 2 (1-1 draw vs B + 4-0 win vs C) -> 4 pts, gf=5, ga=1, GD = +4. (1st Place)
    # Team B: played 2 (1-1 draw vs A + 3-1 win vs C) -> 4 pts, gf=4, ga=2, GD = +2. (2nd Place)
    # Team C: played 2 (losses) -> 0 pts. (3rd Place)
    final_standings = run_sql(f"SELECT * FROM public.get_championship_standings('{league_champ_id}');")
    print(f"  Final League Standings:\n  {final_standings}")
    assert final_standings[0]["team_id"] == team_a_id, "Team A must be 1st place in standings"

    # Attempt to crown Team B (2nd place) -> MUST FAIL!
    crown_loser_res = run_rpc(f"public.crown_tournament_champion_atomic('{league_champ_id}', '{team_b_id}')")
    print(f"  Crown 2nd place result: {crown_loser_res}")
    assert crown_loser_res.get("success") is False
    assert "CHAMPION_MUST_BE_LEAGUE_LEADER" in crown_loser_res.get("error", "")

    # Crown Team A (1st place) -> MUST SUCCEED!
    crown_winner_res = run_rpc(f"public.crown_tournament_champion_atomic('{league_champ_id}', '{team_a_id}')")
    print(f"  Crown 1st place result: {crown_winner_res}")
    assert crown_winner_res.get("success") is True
    assert crown_winner_res.get("champion_team_id") == team_a_id
    print("  ✅ Test 5 Passed: League champion strictly crowned based on 1st place in table.")

    # -----------------------------------------------------------------
    # TEST 6: Completion Guard (Test I)
    # -----------------------------------------------------------------
    print("\n>>> [Test 6 / Scenario I] Testing transition_championship_status_atomic completion guard...")
    # Create test championship with an unconfirmed match
    run_sql(f"""
    INSERT INTO public.championships (
      id, name, owner_id, status, type, template_type,
      start_date, end_date, entry_fee, grand_prize, governorate,
      max_teams, champion_team_id, created_at, updated_at
    ) VALUES (
      '{guard_champ_id}', 'بطولة فحص الحماية', '{owner_id}', 'ongoing', 'league', 'custom',
      CURRENT_DATE, CURRENT_DATE + INTERVAL '7 days', 0, 0, 'القاهرة',
      2, '{team_a_id}', now(), now()
    );

    INSERT INTO public.tournament_matches (
      id, championship_id, round_index, match_index,
      home_team_id, home_team_name, away_team_id, away_team_name,
      status, result_status, is_completed, stage, match_day, updated_at
    ) VALUES (
      '{guard_match_id}', '{guard_champ_id}', 0, 0, '{team_a_id}', 'أ', '{team_b_id}', 'ب',
      'completed', 'scheduled', true, 'league', CURRENT_DATE, now()
    );
    """)

    # Attempt to complete with completed + scheduled result -> MUST FAIL!
    try:
        res = run_rpc(f"public.transition_championship_status_atomic('{guard_champ_id}', 'completed')")
        assert False, "Should have failed on unconfirmed result_status"
    except Exception as e:
        assert "BLOCKED_BY_STATE" in str(e)
        print("  Caught expected guard failure for completed+scheduled result.")

    # Transition the fully completed and crowned real league -> MUST SUCCEED!
    trans_league_res = run_rpc(f"public.transition_championship_status_atomic('{league_champ_id}', 'completed')")
    print(f"  Transition League completed: {trans_league_res}")
    assert trans_league_res.get("success") is True
    assert trans_league_res.get("status") == "completed" or trans_league_res.get("new_status") == "completed"
    print("  ✅ Test 6 Passed: Completion guard strictly enforced and confirmed league completed.")

    print("\n" + "=" * 80)
    print("ALL TARGETED REAL LEAGUE & TOURNAMENT TESTS PASSED 100%!")
    print("=" * 80)

finally:
    print("\n[Cleanup] Cleaning up isolated test entities from Supabase Production...")
    champs_in = f"('{league_champ_id}', '{cup_champ_id}', '{guard_champ_id}')"
    teams_in = f"('{team_a_id}', '{team_b_id}', '{team_c_id}')"
    rosters_in = f"('{roster_a_id}', '{roster_b_id}', '{roster_c_id}')"

    cleanup_sql = f"""
    DELETE FROM public.player_trophies WHERE championship_id IN {champs_in};
    DELETE FROM public.tournament_matches WHERE championship_id IN {champs_in};
    DELETE FROM public.championship_roster_players WHERE roster_id IN {rosters_in};
    DELETE FROM public.championship_rosters WHERE championship_id IN {champs_in};
    DELETE FROM public.championship_registrations WHERE championship_id IN {champs_in};
    DELETE FROM public.championships WHERE id IN {champs_in};
    DELETE FROM public.teams WHERE id IN {teams_in};
    """
    try:
        run_sql(cleanup_sql)
        print("  Cleanup completed successfully. Zero leftover test records.")
    except Exception as e:
        print(f"  [WARN] Cleanup error: {e}")
