import sys
import json
import uuid
sys.path.append('.')
from scripts.db_client import run_sql

def run_section2_live_test():
    print("=" * 80)
    print("SECTION 2 LIVE ACCEPTANCE TEST: TEAM CHAMPION TO PLAYER TROPHIES")
    print("=" * 80)

    # Identifiers
    test_owner_id = str(uuid.uuid4())
    captain_id = str(uuid.uuid4())
    member1_id = str(uuid.uuid4())
    member2_id = str(uuid.uuid4())
    member3_id = str(uuid.uuid4())
    test_team_id = str(uuid.uuid4())
    test_champ_id = str(uuid.uuid4())

    all_user_ids = [test_owner_id, captain_id, member1_id, member2_id, member3_id]
    team_player_ids = [captain_id, member1_id, member2_id, member3_id]

    try:
        # 1. SETUP: Create users in auth.users & public.users
        print("\n--- [SETUP] Creating Owner, Captain, and 3 Team Members ---")
        run_sql(f"""
            INSERT INTO auth.users (id, aud, role, email, is_sso_user, is_anonymous, raw_user_meta_data)
            VALUES 
            ('{test_owner_id}', 'authenticated', 'authenticated', 'owner_{test_owner_id[:8]}@vsp.test', false, false, '{{"role": "owner", "name": "Test Owner"}}'),
            ('{captain_id}', 'authenticated', 'authenticated', 'capt_{captain_id[:8]}@vsp.test', false, false, '{{"role": "player", "name": "Team Captain"}}'),
            ('{member1_id}', 'authenticated', 'authenticated', 'm1_{member1_id[:8]}@vsp.test', false, false, '{{"role": "player", "name": "Member One"}}'),
            ('{member2_id}', 'authenticated', 'authenticated', 'm2_{member2_id[:8]}@vsp.test', false, false, '{{"role": "player", "name": "Member Two"}}'),
            ('{member3_id}', 'authenticated', 'authenticated', 'm3_{member3_id[:8]}@vsp.test', false, false, '{{"role": "player", "name": "Member Three"}}');
        """)
        run_sql(f"""
            UPDATE public.users SET role = 'owner' WHERE id = '{test_owner_id}';
            UPDATE public.users SET role = 'player' WHERE id IN ('{captain_id}', '{member1_id}', '{member2_id}', '{member3_id}');
        """)
        print("Users created: 1 Owner + 1 Captain + 3 Members.")

        # 2. SETUP: Create Team with Captain
        print("\n--- [SETUP] Creating Team and Registering Members ---")
        run_sql(f"""
            INSERT INTO public.teams (
                id, name, captain_id, points, wins, matches_played, championships_won, governorate
            ) VALUES (
                '{test_team_id}', 'Al-Nasr FC Champions', '{captain_id}', 150, 5, 5, 0, 'Cairo'
            );

            -- Captain is also listed in team_members to strictly test deduplication
            INSERT INTO public.team_members (team_id, user_id, joined_at)
            VALUES 
            ('{test_team_id}', '{captain_id}', NOW()),
            ('{test_team_id}', '{member1_id}', NOW()),
            ('{test_team_id}', '{member2_id}', NOW()),
            ('{test_team_id}', '{member3_id}', NOW());
        """)
        team_members_check = run_sql(f"SELECT user_id FROM public.team_members WHERE team_id = '{test_team_id}';")
        print(f"Team created with {len(team_members_check)} members in team_members table.")

        # 3. SETUP: Create Championship with Prize Pool
        print("\n--- [SETUP] Creating Active Championship with 5000 EGP Prize Pool ---")
        run_sql(f"""
            INSERT INTO public.championships (
                id, name, type, sport_type, start_date, end_date, entry_fee, grand_prize, prize_pool,
                max_teams, owner_id, governorate, rules, status, is_approved, joined_teams, paid_teams
            ) VALUES (
                '{test_champ_id}', 'Ramadan Super Cup 2026', 'cup', 'Football',
                NOW() - interval '2 days', NOW() + interval '1 day', 250, 5000, 5000,
                16, '{test_owner_id}', 'Cairo', 'Official Cup Rules', 'ongoing', true,
                ARRAY['{test_team_id}'::text], ARRAY['{test_team_id}'::text]
            );
        """)
        print("Championship created: ID=" + test_champ_id)

        # 4. EXECUTION: Crown the Team Champion via atomic RPC
        print("\n--- [EXECUTION] Crown Tournament Champion via atomic RPC ---")
        sql_crown = f"""
        DO $$
        DECLARE
            v_res JSONB;
        BEGIN
            SET LOCAL ROLE authenticated;
            PERFORM set_config('request.jwt.claims', '{{\"sub\": \"{test_owner_id}\", \"role\": \"authenticated\"}}', true);
            v_res := public.crown_tournament_champion_atomic(
                '{test_champ_id}'::uuid,
                '{test_team_id}'::uuid,
                'Al-Nasr FC Champions'
            );
            RAISE NOTICE 'RPC Result: %', v_res;
        END $$;
        """
        run_sql(sql_crown)
        print("RPC executed successfully.")

        # 5. VERIFICATION: Check player_trophies table via direct SQL
        print("\n--- [VERIFICATION 1] Inspecting player_trophies Records ---")
        trophies = run_sql(f"""
            SELECT id, user_id, championship_id, title, prize_won, created_at
            FROM public.player_trophies
            WHERE championship_id = '{test_champ_id}'
            ORDER BY created_at ASC;
        """)
        print(f"Total Trophies Awarded: {len(trophies)}")
        assert len(trophies) == 4, f"FAIL: Expected exactly 4 trophies, got {len(trophies)}"

        awarded_user_ids = [str(t['user_id']) for t in trophies]
        print(f"Awarded User IDs: {awarded_user_ids}")

        # Ensure all 4 distinct players received exactly one trophy
        for pid in team_player_ids:
            occurrences = awarded_user_ids.count(pid)
            assert occurrences == 1, f"FAIL: User {pid} has {occurrences} trophies (expected 1)"
            print(f"  - Player {pid[:8]}... : EXACTLY 1 Trophy verified")

        # Verify prize_won reflects documentary full prize value
        for t in trophies:
            assert float(t['prize_won']) == 5000.0, f"FAIL: Prize won was {t['prize_won']} (expected 5000.0)"
            assert "Ramadan Super Cup 2026" in t['title'], f"FAIL: Title was {t['title']}"

        print("SUCCESS: Every team member (Captain + 3 Squad Members) received exactly 1 documentary trophy with full prize value!")

        # 6. VERIFICATION: Check notifications delivered to all 4 players
        print("\n--- [VERIFICATION 2] Inspecting Notifications Delivered to Champions ---")
        notifs = run_sql(f"""
            SELECT user_id, title, type, metadata
            FROM public.notifications
            WHERE user_id IN ('{captain_id}', '{member1_id}', '{member2_id}', '{member3_id}')
              AND type = 'tournament_champion';
        """)
        print(f"Total Champion Notifications Delivered: {len(notifs)}")
        assert len(notifs) == 4, f"FAIL: Expected 4 notifications, got {len(notifs)}"
        print("SUCCESS: All 4 players received real-time celebratory championship notifications.")

        # 7. VERIFICATION: Team State and Idempotency
        print("\n--- [VERIFICATION 3] Checking Team Stats and Idempotency ---")
        team_row = run_sql(f"SELECT championships_won, points FROM public.teams WHERE id = '{test_team_id}';")[0]
        assert team_row['championships_won'] == 1, f"FAIL: championships_won was {team_row['championships_won']}"
        assert team_row['points'] == 250, f"FAIL: points was {team_row['points']} (150 initial + 100)"
        print(f"Team stats: championships_won={team_row['championships_won']}, points={team_row['points']}")

        # Re-run crowning to verify no duplicate trophies or double point increments
        print("Re-running crown_tournament_champion_atomic to test idempotency...")
        run_sql(sql_crown)
        recheck_trophies = run_sql(f"SELECT count(*) FROM public.player_trophies WHERE championship_id = '{test_champ_id}';")[0]['count']
        recheck_team = run_sql(f"SELECT championships_won, points FROM public.teams WHERE id = '{test_team_id}';")[0]
        assert int(recheck_trophies) == 4, f"FAIL: Idempotency failed, trophy count changed to {recheck_trophies}"
        assert recheck_team['championships_won'] == 1, f"FAIL: championships_won incremented again to {recheck_team['championships_won']}"
        assert recheck_team['points'] == 250, f"FAIL: points incremented again to {recheck_team['points']}"
        print("SUCCESS: Idempotency verified. Re-invoking did not create duplicate trophies or double count points.")

        print("\nALL SECTION 2 ACCEPTANCE CRITERIA PASSED WITH 100% SUCCESS!")

    finally:
        # CLEANUP
        print("\n--- [CLEANUP] Purging all test artifacts ---")
        run_sql(f"""
            DELETE FROM public.player_trophies WHERE championship_id = '{test_champ_id}';
            DELETE FROM public.notifications WHERE user_id IN ('{test_owner_id}', '{captain_id}', '{member1_id}', '{member2_id}', '{member3_id}');
            DELETE FROM public.championships WHERE id = '{test_champ_id}';
            DELETE FROM public.team_members WHERE team_id = '{test_team_id}';
            DELETE FROM public.teams WHERE id = '{test_team_id}';
            DELETE FROM public.users WHERE id IN ('{test_owner_id}', '{captain_id}', '{member1_id}', '{member2_id}', '{member3_id}');
            DELETE FROM auth.users WHERE id IN ('{test_owner_id}', '{captain_id}', '{member1_id}', '{member2_id}', '{member3_id}');
        """)

        # VERIFY CLEANUP WITH COUNT(*)
        c_trophies = run_sql(f"SELECT count(*) FROM public.player_trophies WHERE championship_id = '{test_champ_id}';")[0]['count']
        c_notifs = run_sql(f"SELECT count(*) FROM public.notifications WHERE user_id IN ('{test_owner_id}', '{captain_id}', '{member1_id}', '{member2_id}', '{member3_id}');")[0]['count']
        c_champ = run_sql(f"SELECT count(*) FROM public.championships WHERE id = '{test_champ_id}';")[0]['count']
        c_members = run_sql(f"SELECT count(*) FROM public.team_members WHERE team_id = '{test_team_id}';")[0]['count']
        c_team = run_sql(f"SELECT count(*) FROM public.teams WHERE id = '{test_team_id}';")[0]['count']
        c_users = run_sql(f"SELECT count(*) FROM public.users WHERE id IN ('{test_owner_id}', '{captain_id}', '{member1_id}', '{member2_id}', '{member3_id}');")[0]['count']
        c_auth = run_sql(f"SELECT count(*) FROM auth.users WHERE id IN ('{test_owner_id}', '{captain_id}', '{member1_id}', '{member2_id}', '{member3_id}');")[0]['count']

        print("\nVerification count(*) results:")
        print(f"  - Test trophies remaining: {c_trophies}")
        print(f"  - Test notifications remaining: {c_notifs}")
        print(f"  - Test championships remaining: {c_champ}")
        print(f"  - Test team members remaining: {c_members}")
        print(f"  - Test teams remaining: {c_team}")
        print(f"  - Test public.users remaining: {c_users}")
        print(f"  - Test auth.users remaining: {c_auth}")

        assert (int(c_trophies) == 0 and int(c_notifs) == 0 and int(c_champ) == 0 and 
                int(c_members) == 0 and int(c_team) == 0 and int(c_users) == 0 and int(c_auth) == 0), "Cleanup verification failed!"
        print("\nCLEANUP VERIFIED 100%: All test data cleanly wiped with 0 remaining rows.")

if __name__ == "__main__":
    run_section2_live_test()
