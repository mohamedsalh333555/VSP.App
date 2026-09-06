import sys
import json
import uuid
sys.path.append('.')
from scripts.db_client import run_sql

def run_section3_live_test():
    print("=" * 80)
    print("SECTION 3 LIVE ACCEPTANCE TEST: MINIMUM PLAYERS SOFT WARNING")
    print("=" * 80)

    # Identifiers
    test_owner_id = str(uuid.uuid4())
    capt_a_id = str(uuid.uuid4())
    mem_a1_id = str(uuid.uuid4())
    mem_a2_id = str(uuid.uuid4())
    mem_a3_id = str(uuid.uuid4())
    mem_a4_id = str(uuid.uuid4())

    capt_b_id = str(uuid.uuid4())
    mem_b1_id = str(uuid.uuid4())
    mem_b2_id = str(uuid.uuid4())
    mem_b3_id = str(uuid.uuid4())
    mem_b4_id = str(uuid.uuid4())

    team_a_id = str(uuid.uuid4())
    team_b_id = str(uuid.uuid4())
    test_champ_id = str(uuid.uuid4())
    match1_id = str(uuid.uuid4())
    match2_id = str(uuid.uuid4())

    created_user_ids = [
        test_owner_id, capt_a_id, mem_a1_id, mem_a2_id, mem_a3_id, mem_a4_id,
        capt_b_id, mem_b1_id, mem_b2_id, mem_b3_id, mem_b4_id
    ]

    try:
        # 1. SETUP: Create test users
        print("\n--- [SETUP] Creating Test Users ---")
        user_inserts = []
        user_inserts.append(f"('{test_owner_id}', 'authenticated', 'authenticated', 'owner_{test_owner_id[:8]}@vsp.test', false, false, '{{\"role\": \"owner\", \"name\": \"Tournament Owner\"}}')")
        for u_id in [capt_a_id, mem_a1_id, mem_a2_id, mem_a3_id, mem_a4_id]:
            user_inserts.append(f"('{u_id}', 'authenticated', 'authenticated', 'ta_{u_id[:8]}@vsp.test', false, false, '{{\"role\": \"player\", \"name\": \"Team A Player\"}}')")
        for u_id in [capt_b_id, mem_b1_id, mem_b2_id, mem_b3_id, mem_b4_id]:
            user_inserts.append(f"('{u_id}', 'authenticated', 'authenticated', 'tb_{u_id[:8]}@vsp.test', false, false, '{{\"role\": \"player\", \"name\": \"Team B Player\"}}')")

        run_sql(f"""
            INSERT INTO auth.users (id, aud, role, email, is_sso_user, is_anonymous, raw_user_meta_data)
            VALUES {','.join(user_inserts)};
        """)
        run_sql(f"UPDATE public.users SET role = 'owner' WHERE id = '{test_owner_id}';")
        print("Users registered in auth and public tables.")

        # 2. SETUP: Create Teams
        # Team A initially has ONLY 2 PLAYERS (Captain + 1 Member) -> Below min_players=5!
        # Team B has 5 PLAYERS (Captain + 4 Members) -> Compliant
        print("\n--- [SETUP] Creating Teams (Team A with 2 players, Team B with 5 players) ---")
        run_sql(f"""
            INSERT INTO public.teams (id, name, captain_id, points, wins, matches_played, governorate)
            VALUES 
            ('{team_a_id}', 'Short Squad Team A', '{capt_a_id}', 10, 1, 1, 'Cairo'),
            ('{team_b_id}', 'Full Squad Team B', '{capt_b_id}', 10, 1, 1, 'Cairo');

            -- Team A: 2 players total
            INSERT INTO public.team_members (team_id, user_id, joined_at)
            VALUES 
            ('{team_a_id}', '{capt_a_id}', NOW()),
            ('{team_a_id}', '{mem_a1_id}', NOW());

            -- Team B: 5 players total
            INSERT INTO public.team_members (team_id, user_id, joined_at)
            VALUES 
            ('{team_b_id}', '{capt_b_id}', NOW()),
            ('{team_b_id}', '{mem_b1_id}', NOW()),
            ('{team_b_id}', '{mem_b2_id}', NOW()),
            ('{team_b_id}', '{mem_b3_id}', NOW()),
            ('{team_b_id}', '{mem_b4_id}', NOW());
        """)
        print("Teams registered. Team A has 2 members, Team B has 5 members.")

        # 3. SETUP: Championship with min_players_per_team = 5
        print("\n--- [SETUP] Creating Championship with min_players_per_team = 5 ---")
        run_sql(f"""
            INSERT INTO public.championships (
                id, name, type, sport_type, start_date, end_date, entry_fee, grand_prize,
                min_players_per_team, max_players_per_team, max_teams, owner_id, governorate,
                rules, status, is_approved
            ) VALUES (
                '{test_champ_id}', 'Fair Play Summer Cup', 'cup', 'Football',
                NOW() - interval '1 day', NOW() + interval '5 days', 100, 2000,
                5, 11, 16, '{test_owner_id}', 'Cairo',
                'Official Tournament Rules', 'ongoing', true
            );
        """)

        # 4. SETUP: Create Match 1 (Short Squad Team A vs Full Squad Team B)
        print("\n--- [SETUP] Scheduling Match 1 (Team A with 2 players vs Team B with 5 players) ---")
        run_sql(f"""
            INSERT INTO public.tournament_matches (
                id, championship_id, round_index, match_index,
                home_team_id, home_team_name, away_team_id, away_team_name,
                status, is_completed
            ) VALUES (
                '{match1_id}', '{test_champ_id}', 1, 1,
                '{team_a_id}', 'Short Squad Team A', '{team_b_id}', 'Full Squad Team B',
                'scheduled', false
            );
        """)
        print("Match 1 created: ID=" + match1_id)

        # 5. EXECUTION 1: Record Match 1 Result (Should SUCCEED and dispatch warning to admins)
        print("\n--- [EXECUTION 1] Recording Match 1 Result with Shortage ---")
        sql_record_match1 = f"""
        DO $$
        DECLARE
            v_res JSONB;
        BEGIN
            SET LOCAL ROLE authenticated;
            PERFORM set_config('request.jwt.claims', '{{\"sub\": \"{test_owner_id}\", \"role\": \"authenticated\"}}', true);

            v_res := public.record_match_result_and_advance_atomic(
                '{match1_id}'::uuid,
                3, -- home_score
                1, -- away_score
                NULL, NULL,
                '{team_a_id}'::uuid,
                'Short Squad Team A'
            );
            RAISE NOTICE 'Result: %', v_res;
        END $$;
        """
        run_sql(sql_record_match1)

        # 6. VERIFICATION 1: Verify Match 1 Completed Successfully
        print("\n--- [VERIFICATION 1] Checking Match 1 Completion State ---")
        m1_row = run_sql(f"SELECT home_score, away_score, winner_id, status, is_completed FROM public.tournament_matches WHERE id = '{match1_id}';")[0]
        print(f"Match 1 status: {m1_row['status']}, score: {m1_row['home_score']}-{m1_row['away_score']}, winner: {m1_row['winner_id']}")
        assert m1_row['status'] == 'completed', "FAIL: Match 1 was not marked completed"
        assert m1_row['is_completed'] == True, "FAIL: is_completed was false"
        assert m1_row['home_score'] == 3 and m1_row['away_score'] == 1, "FAIL: Scores were not saved"
        print("SUCCESS: Match result was saved successfully without blocking execution!")

        # 7. VERIFICATION 2: Verify Warning Notification was Dispatched to Admins
        print("\n--- [VERIFICATION 2] Checking Admin Notifications for Roster Warning ---")
        admin_notifs = run_sql(f"""
            SELECT n.id, n.user_id, n.title, n.body, n.type, n.metadata, u.role
            FROM public.notifications n
            JOIN public.users u ON u.id = n.user_id
            WHERE n.type = 'match_roster_warning'
              AND n.metadata->>'match_id' = '{match1_id}';
        """)
        print(f"Total Warning Notifications Found: {len(admin_notifs)}")
        assert len(admin_notifs) >= 1, "FAIL: Expected at least 1 admin warning notification"

        first_notif = admin_notifs[0]
        print(f"Recipient Role: {first_notif['role']}")
        print(f"Notification Title: {first_notif['title']}")
        print(f"Notification Body: {first_notif['body']}")
        print(f"Metadata: {json.dumps(first_notif['metadata'], indent=2)}")

        meta = first_notif['metadata']
        assert meta['min_players_required'] == 5, f"FAIL: Expected min 5, got {meta['min_players_required']}"
        assert meta['home_player_count'] == 2, f"FAIL: Expected 2 home players, got {meta['home_player_count']}"
        assert 'Short Squad Team A' in meta['shortage_details'], "FAIL: Missing team name in shortage details"
        print("SUCCESS: Admin notification contains accurate shortage details (2 players vs 5 min required)!")

        # 8. SCENARIO 2: Test Compliant Match (No warning should be triggered)
        print("\n--- [SCENARIO 2] Adding missing players to Team A and testing compliant match ---")
        run_sql(f"""
            INSERT INTO public.team_members (team_id, user_id, joined_at)
            VALUES 
            ('{team_a_id}', '{mem_a2_id}', NOW()),
            ('{team_a_id}', '{mem_a3_id}', NOW()),
            ('{team_a_id}', '{mem_a4_id}', NOW());

            INSERT INTO public.tournament_matches (
                id, championship_id, round_index, match_index,
                home_team_id, home_team_name, away_team_id, away_team_name,
                status, is_completed
            ) VALUES (
                '{match2_id}', '{test_champ_id}', 1, 2,
                '{team_a_id}', 'Full Squad Team A', '{team_b_id}', 'Full Squad Team B',
                'scheduled', false
            );
        """)

        # Record compliant match 2
        sql_record_match2 = f"""
        DO $$
        BEGIN
            SET LOCAL ROLE authenticated;
            PERFORM set_config('request.jwt.claims', '{{\"sub\": \"{test_owner_id}\", \"role\": \"authenticated\"}}', true);

            PERFORM public.record_match_result_and_advance_atomic(
                '{match2_id}'::uuid,
                2, 2, 4, 3,
                '{team_a_id}'::uuid,
                'Full Squad Team A'
            );
        END $$;
        """
        run_sql(sql_record_match2)

        # Check NO notification for match 2
        m2_notifs = run_sql(f"SELECT count(*) FROM public.notifications WHERE metadata->>'match_id' = '{match2_id}';")[0]['count']
        assert int(m2_notifs) == 0, f"FAIL: Expected 0 notifications for compliant match, got {m2_notifs}"
        print("SUCCESS: Compliant match recorded cleanly with 0 warning notifications triggered.")

        print("\nALL SECTION 3 ACCEPTANCE CRITERIA PASSED WITH 100% SUCCESS!")

    finally:
        # CLEANUP
        print("\n--- [CLEANUP] Purging all test artifacts ---")
        run_sql(f"""
            DELETE FROM public.notifications WHERE metadata->>'championship_id' = '{test_champ_id}';
            DELETE FROM public.notifications WHERE metadata->>'match_id' IN ('{match1_id}', '{match2_id}');
            DELETE FROM public.tournament_matches WHERE championship_id = '{test_champ_id}';
            DELETE FROM public.championships WHERE id = '{test_champ_id}';
            DELETE FROM public.team_members WHERE team_id IN ('{team_a_id}', '{team_b_id}');
            DELETE FROM public.teams WHERE id IN ('{team_a_id}', '{team_b_id}');
            DELETE FROM public.users WHERE id IN ({','.join([f"'{uid}'" for uid in created_user_ids])});
            DELETE FROM auth.users WHERE id IN ({','.join([f"'{uid}'" for uid in created_user_ids])});
        """)

        # VERIFY CLEANUP WITH COUNT(*)
        c_notifs = run_sql(f"SELECT count(*) FROM public.notifications WHERE metadata->>'championship_id' = '{test_champ_id}' OR metadata->>'match_id' IN ('{match1_id}', '{match2_id}');")[0]['count']
        c_matches = run_sql(f"SELECT count(*) FROM public.tournament_matches WHERE championship_id = '{test_champ_id}';")[0]['count']
        c_champ = run_sql(f"SELECT count(*) FROM public.championships WHERE id = '{test_champ_id}';")[0]['count']
        c_members = run_sql(f"SELECT count(*) FROM public.team_members WHERE team_id IN ('{team_a_id}', '{team_b_id}');")[0]['count']
        c_teams = run_sql(f"SELECT count(*) FROM public.teams WHERE id IN ('{team_a_id}', '{team_b_id}');")[0]['count']
        c_users = run_sql(f"SELECT count(*) FROM public.users WHERE id IN ({','.join([f"'{uid}'" for uid in created_user_ids])});")[0]['count']
        c_auth = run_sql(f"SELECT count(*) FROM auth.users WHERE id IN ({','.join([f"'{uid}'" for uid in created_user_ids])});")[0]['count']

        print("\nVerification count(*) results:")
        print(f"  - Test notifications remaining: {c_notifs}")
        print(f"  - Test matches remaining: {c_matches}")
        print(f"  - Test championships remaining: {c_champ}")
        print(f"  - Test team members remaining: {c_members}")
        print(f"  - Test teams remaining: {c_teams}")
        print(f"  - Test public.users remaining: {c_users}")
        print(f"  - Test auth.users remaining: {c_auth}")

        assert (int(c_notifs) == 0 and int(c_matches) == 0 and int(c_champ) == 0 and
                int(c_members) == 0 and int(c_teams) == 0 and int(c_users) == 0 and int(c_auth) == 0), "Cleanup verification failed!"
        print("\nCLEANUP VERIFIED 100%: All test data cleanly wiped with 0 remaining rows.")

if __name__ == "__main__":
    run_section3_live_test()
