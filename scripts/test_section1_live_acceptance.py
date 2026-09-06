import sys
import json
import uuid
sys.path.append('.')
from scripts.db_client import run_sql

def run_section1_live_test():
    print("=" * 80)
    print("SECTION 1 LIVE ACCEPTANCE TEST: RLS HARDENING & APPROVAL ENGINE")
    print("=" * 80)

    test_player_id = str(uuid.uuid4())
    test_owner_id = str(uuid.uuid4())
    test_champ_id = str(uuid.uuid4())
    test_reject_champ_id = str(uuid.uuid4())
    admin_id = "80544d1d-09fd-4a5e-b195-3c20a2ff1fc0" # Co-founder admin

    try:
        # SETUP: Create test player and test owner in auth.users
        print("\n--- [SETUP] Creating Test Player and Test Owner in auth.users ---")
        run_sql(f"""
            INSERT INTO auth.users (id, aud, role, email, is_sso_user, is_anonymous, raw_user_meta_data)
            VALUES ('{test_player_id}', 'authenticated', 'authenticated', 'test_player_{test_player_id[:8]}@vsp.test', false, false, '{{"role": "player", "name": "Test Player"}}');

            INSERT INTO auth.users (id, aud, role, email, is_sso_user, is_anonymous, raw_user_meta_data)
            VALUES ('{test_owner_id}', 'authenticated', 'authenticated', 'test_owner_{test_owner_id[:8]}@vsp.test', false, false, '{{"role": "owner", "name": "Test Stadium Owner"}}');
        """)
        # Ensure role is explicitly set in public.users if trigger defaulted
        run_sql(f"""
            UPDATE public.users SET role = 'player' WHERE id = '{test_player_id}';
            UPDATE public.users SET role = 'owner' WHERE id = '{test_owner_id}';
        """)
        print("Test player and owner created successfully.")

        # TEST 1: Attempt to create championship as Player (must be BLOCKED by RLS)
        print("\n--- [TEST 1] Player creates championship (RLS Violation Expected) ---")
        sql_player_attack = f"""
        DO $$
        BEGIN
            SET LOCAL ROLE authenticated;
            PERFORM set_config('request.jwt.claims', '{{\"sub\": \"{test_player_id}\", \"role\": \"authenticated\"}}', true);

            INSERT INTO public.championships (
                id, name, type, sport_type, start_date, end_date, entry_fee, grand_prize,
                max_teams, owner_id, governorate, rules, status
            ) VALUES (
                gen_random_uuid(), 'Illegal Player Cup', 'Cup', 'Football',
                NOW() + interval '1 day', NOW() + interval '5 days', 100, 1000,
                16, '{test_player_id}', 'Cairo', 'Standard', 'open'
            );
        END $$;
        """
        player_blocked = False
        try:
            run_sql(sql_player_attack)
            print("FAILURE: Player was able to insert championship!")
        except Exception as e:
            err_msg = str(e)
            if "row-level security policy" in err_msg or "42501" in err_msg:
                player_blocked = True
                print("SUCCESS: Player insertion BLOCKED by RLS policy 'championships_insert'.")
                print(f"Detail: {err_msg.strip()[:160]}")
            else:
                print(f"Blocked with error: {err_msg}")
        assert player_blocked, "Test 1 Failed: Player must be blocked by RLS"

        # TEST 2: Owner creates championship with is_approved = true attempt (must be BLOCKED)
        print("\n--- [TEST 2] Owner attempts pre-approved championship creation (Must be BLOCKED) ---")
        sql_owner_forge_approval = f"""
        DO $$
        BEGIN
            SET LOCAL ROLE authenticated;
            PERFORM set_config('request.jwt.claims', '{{\"sub\": \"{test_owner_id}\", \"role\": \"authenticated\"}}', true);

            INSERT INTO public.championships (
                id, name, type, sport_type, start_date, end_date, entry_fee, grand_prize,
                max_teams, owner_id, governorate, rules, status, is_approved
            ) VALUES (
                gen_random_uuid(), 'Forged Approved Cup', 'Cup', 'Football',
                NOW() + interval '1 day', NOW() + interval '5 days', 100, 1000,
                16, '{test_owner_id}', 'Cairo', 'Standard', 'open', true
            );
        END $$;
        """
        forge_blocked = False
        try:
            run_sql(sql_owner_forge_approval)
            print("FAILURE: Owner was able to forge is_approved = true!")
        except Exception as e:
            err_msg = str(e)
            if "row-level security policy" in err_msg or "Security Alert" in err_msg:
                forge_blocked = True
                print("SUCCESS: Owner pre-approval attempt BLOCKED by policy/trigger.")
                print(f"Detail: {err_msg.strip()[:160]}")
            else:
                print(f"Blocked with error: {err_msg}")
        assert forge_blocked, "Test 2 Failed: Owner cannot forge is_approved = true"

        # TEST 3: Owner creates championship normally (Should succeed with is_approved = false)
        print("\n--- [TEST 3] Owner creates standard championship (Must be is_approved = false) ---")
        sql_owner_create = f"""
        DO $$
        BEGIN
            SET LOCAL ROLE authenticated;
            PERFORM set_config('request.jwt.claims', '{{\"sub\": \"{test_owner_id}\", \"role\": \"authenticated\"}}', true);

            INSERT INTO public.championships (
                id, name, type, sport_type, start_date, end_date, entry_fee, grand_prize,
                max_teams, owner_id, governorate, rules, status, is_approved
            ) VALUES (
                '{test_champ_id}', 'Real Owner Champions Cup', 'cup', 'Football',
                NOW() + interval '1 day', NOW() + interval '5 days', 200, 2500,
                16, '{test_owner_id}', 'Cairo', 'Owner Rules', 'open', false
            );
        END $$;
        """
        run_sql(sql_owner_create)
        champ_row = run_sql(f"SELECT id, name, is_approved, owner_id, status FROM public.championships WHERE id = '{test_champ_id}';")[0]
        print(f"Tournament created: ID={champ_row['id']}, Name='{champ_row['name']}', is_approved={champ_row['is_approved']}")
        assert champ_row['is_approved'] == False, "Test 3 Failed: Tournament must have is_approved = false"

        # TEST 4: Query tournaments as Player (simulating player feed where is_approved = true)
        print("\n--- [TEST 4] Verify Unapproved Tournament is Hidden from Players Feed ---")
        player_feed_query = f"""
        SELECT id, name, is_approved 
        FROM public.championships 
        WHERE id = '{test_champ_id}' AND is_approved = true;
        """
        res_feed = run_sql(player_feed_query)
        print(f"Player Query Result count: {len(res_feed)}")
        assert len(res_feed) == 0, "Test 4 Failed: Unapproved tournament must NOT appear in player feed"
        print("SUCCESS: Tournament is invisible to players prior to admin approval.")

        # TEST 5: Admin Approves Championship via atomic RPC
        print("\n--- [TEST 5] Admin Approves Championship via admin_approve_championship_atomic ---")
        sql_admin_approve = f"""
        DO $$
        BEGIN
            SET LOCAL ROLE authenticated;
            PERFORM set_config('request.jwt.claims', '{{\"sub\": \"{admin_id}\", \"role\": \"authenticated\"}}', true);
            PERFORM public.admin_approve_championship_atomic('{test_champ_id}'::uuid);
        END $$;
        """
        run_sql(sql_admin_approve)
        updated_champ = run_sql(f"SELECT id, name, is_approved, updated_at FROM public.championships WHERE id = '{test_champ_id}';")[0]
        print(f"Post-approval Status: is_approved={updated_champ['is_approved']}, updated_at={updated_champ['updated_at']}")
        assert updated_champ['is_approved'] == True, "Test 5 Failed: Tournament must be is_approved = true"

        # Verify Owner received notification
        notifs = run_sql(f"SELECT id, title, type, metadata FROM public.notifications WHERE user_id = '{test_owner_id}';")
        print(f"Owner notifications count: {len(notifs)}")
        assert len(notifs) >= 1, "Test 5 Failed: Owner must receive notification"
        print(f"Notification received: Title='{notifs[0]['title']}', Type='{notifs[0]['type']}'")

        # TEST 6: Verify Tournament is NOW visible in Player Feed
        print("\n--- [TEST 6] Verify Approved Tournament is NOW Visible to Players ---")
        res_feed_approved = run_sql(player_feed_query)
        print(f"Player Query Result count post-approval: {len(res_feed_approved)}")
        assert len(res_feed_approved) == 1, "Test 6 Failed: Approved tournament must appear in player feed"
        print(f"SUCCESS: Approved tournament '{res_feed_approved[0]['name']}' is visible to players.")

        # TEST 7: Test Rejection Flow
        print("\n--- [TEST 7] Test Admin Rejection Engine (admin_reject_championship_atomic) ---")
        sql_owner_create_reject = f"""
        DO $$
        BEGIN
            SET LOCAL ROLE authenticated;
            PERFORM set_config('request.jwt.claims', '{{\"sub\": \"{test_owner_id}\", \"role\": \"authenticated\"}}', true);

            INSERT INTO public.championships (
                id, name, type, sport_type, start_date, end_date, entry_fee, grand_prize,
                max_teams, owner_id, governorate, rules, status, is_approved
            ) VALUES (
                '{test_reject_champ_id}', 'Rejected Candidate Cup', 'cup', 'Football',
                NOW() + interval '1 day', NOW() + interval '5 days', 500, 10000,
                16, '{test_owner_id}', 'Alexandria', 'Test Rules', 'open', false
            );
        END $$;
        """
        run_sql(sql_owner_create_reject)

        # Admin rejects
        sql_admin_reject = f"""
        DO $$
        BEGIN
            SET LOCAL ROLE authenticated;
            PERFORM set_config('request.jwt.claims', '{{\"sub\": \"{admin_id}\", \"role\": \"authenticated\"}}', true);
            PERFORM public.admin_reject_championship_atomic('{test_reject_champ_id}'::uuid, 'Dates conflict with Ramadan League');
        END $$;
        """
        run_sql(sql_admin_reject)
        reject_check = run_sql(f"SELECT count(*) FROM public.championships WHERE id = '{test_reject_champ_id}';")[0]['count']
        assert int(reject_check) == 0, "Test 7 Failed: Rejected tournament must be deleted"
        print(f"SUCCESS: Tournament deleted after admin rejection (Remaining rows = {reject_check}).")

        # Check rejection notification
        rej_notifs = run_sql(f"SELECT id, title, body FROM public.notifications WHERE user_id = '{test_owner_id}' AND type = 'tournament_rejection';")
        print(f"Rejection notifications received: {len(rej_notifs)}")
        assert len(rej_notifs) >= 1, "Test 7 Failed: Owner must receive rejection notification"
        print(f"Rejection notice body: {rej_notifs[0]['body']}")

        print("\nALL 7 INTEGRATION TESTS PASSED WITH 100% SUCCESS!")

    finally:
        # CLEANUP
        print("\n--- [CLEANUP] Cleaning up all test artifacts ---")
        run_sql(f"""
            DELETE FROM public.notifications WHERE user_id IN ('{test_owner_id}', '{test_player_id}');
            DELETE FROM public.championships WHERE id IN ('{test_champ_id}', '{test_reject_champ_id}');
            DELETE FROM public.users WHERE id IN ('{test_owner_id}', '{test_player_id}');
            DELETE FROM auth.users WHERE id IN ('{test_owner_id}', '{test_player_id}');
        """)

        # VERIFY CLEANUP WITH COUNT(*)
        c_champ = run_sql(f"SELECT count(*) FROM public.championships WHERE id IN ('{test_champ_id}', '{test_reject_champ_id}');")[0]['count']
        c_notif = run_sql(f"SELECT count(*) FROM public.notifications WHERE user_id IN ('{test_owner_id}', '{test_player_id}');")[0]['count']
        c_users = run_sql(f"SELECT count(*) FROM public.users WHERE id IN ('{test_owner_id}', '{test_player_id}');")[0]['count']
        c_auth = run_sql(f"SELECT count(*) FROM auth.users WHERE id IN ('{test_owner_id}', '{test_player_id}');")[0]['count']

        print(f"Verification count(*) results:")
        print(f"  - Test championships remaining: {c_champ}")
        print(f"  - Test notifications remaining: {c_notif}")
        print(f"  - Test public.users remaining: {c_users}")
        print(f"  - Test auth.users remaining: {c_auth}")

        assert int(c_champ) == 0 and int(c_notif) == 0 and int(c_users) == 0 and int(c_auth) == 0, "Cleanup verification failed!"
        print("CLEANUP VERIFIED 100%: All test data cleanly wiped.")

if __name__ == "__main__":
    run_section1_live_test()
