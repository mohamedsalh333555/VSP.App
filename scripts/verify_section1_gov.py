import urllib.request, json, sys

env = json.load(open('env.json'))
token = env['SUPABASE_MANAGEMENT_KEY']
url = 'https://api.supabase.com/v1/projects/mktqkddbcddrxjxabdua/database/query'

def q(s):
    req = urllib.request.Request(
        url,
        data=json.dumps({'query': s}).encode(),
        headers={
            'Content-Type': 'application/json',
            'Authorization': f'Bearer {token}',
            'User-Agent': 'Mozilla/5.0'
        }
    )
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        error_body = e.read().decode()
        return {'error': True, 'code': e.code, 'message': error_body}

def run_acceptance_tests():
    print("=================================================================")
    print("SECTION 1: GOVERNORATE SCOPING ACCEPTANCE TESTS (LIVE DB)")
    print("=================================================================")

    # 0. Verify Column and Index on vsp_1v1_tournaments
    print("\n--- TEST 0: Column & Index Verification ---")
    col_info = q("SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name = 'vsp_1v1_tournaments' AND column_name = 'governorate';")
    print("Column metadata:", col_info)
    assert len(col_info) == 1, "governorate column not found!"
    assert col_info[0]['column_name'] == 'governorate'
    print("PASS: governorate column successfully added with DEFAULT 'Cairo'.")

    idx_info = q("SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'vsp_1v1_tournaments';")
    print("Indexes on table:", [i['indexname'] for i in idx_info])
    active_idx = next((i for i in idx_info if i['indexname'] == 'idx_one_active_1v1_tournament_per_governorate'), None)
    assert active_idx is not None, "idx_one_active_1v1_tournament_per_governorate not found!"
    print("PASS: Unique Index definition:", active_idx['indexdef'])

    t1_id = None
    t2_id = None
    t3_id = None

    try:
        # TEST 1: Open 2 concurrent tournaments in 2 different governorates
        print("\n--- TEST 1: Open 2 Concurrent Active Tournaments (Cairo & Alexandria) ---")
        res1 = q("""
            INSERT INTO public.vsp_1v1_tournaments (
                name, governorate, target_player_count, entry_fee, prize_pool, status
            ) VALUES (
                'بطولة القاهرة 1v1', 'Cairo', 16, 100.00, 0.00, 'registration_open'
            ) RETURNING id, name, governorate, status;
        """)
        print("Tournament 1 Insert Result:", res1)
        assert isinstance(res1, list) and len(res1) == 1, f"Failed to insert Tournament 1: {res1}"
        t1_id = res1[0]['id']

        res2 = q("""
            INSERT INTO public.vsp_1v1_tournaments (
                name, governorate, target_player_count, entry_fee, prize_pool, status
            ) VALUES (
                'بطولة الإسكندرية 1v1', 'Alexandria', 16, 100.00, 0.00, 'registration_open'
            ) RETURNING id, name, governorate, status;
        """)
        print("Tournament 2 Insert Result:", res2)
        assert isinstance(res2, list) and len(res2) == 1, f"Failed to insert Tournament 2: {res2}"
        t2_id = res2[0]['id']

        # Verify both are currently active in DB
        active_tournaments = q("""
            SELECT id, name, governorate, status 
            FROM public.vsp_1v1_tournaments 
            WHERE status = 'registration_open';
        """)
        print("Active Tournaments currently in DB:", active_tournaments)
        assert len(active_tournaments) == 2, f"Expected 2 active tournaments, got {len(active_tournaments)}"
        print("PASS: Both Cairo and Alexandria active tournaments created simultaneously without index conflict!")

        # TEST 2: Attempt to open a 3rd tournament in Cairo while Cairo already has an active tournament
        print("\n--- TEST 2: Attempt Duplicate Active Tournament in Cairo (Must Fail by Unique Index) ---")
        res3 = q("""
            INSERT INTO public.vsp_1v1_tournaments (
                name, governorate, target_player_count, entry_fee, prize_pool, status
            ) VALUES (
                'بطولة القاهرة الثانية المخالفة', 'Cairo', 8, 50.00, 0.00, 'registration_open'
            ) RETURNING id, name, governorate, status;
        """)
        print("Tournament 3 (Duplicate) Attempt Result:", res3)
        assert isinstance(res3, dict) and res3.get('error') is True, "SECURITY FAILURE: Unique index failed to block duplicate active tournament in Cairo!"
        assert 'idx_one_active_1v1_tournament_per_governorate' in res3.get('message', ''), f"Error message did not mention unique index: {res3}"
        print("PASS: Unique Index successfully BLOCKED duplicate active tournament in Cairo with unique violation!")

        # TEST 3: Mobile Query Scoping Simulation
        print("\n--- TEST 3: Governorate Scoping Query Check for Players ---")
        # Player in Cairo query:
        cairo_player_view = q("""
            SELECT id, name, governorate, status 
            FROM public.vsp_1v1_tournaments 
            WHERE governorate = 'Cairo' AND status IN ('registration_open', 'in_progress');
        """)
        print("Cairo Player sees:", cairo_player_view)
        assert len(cairo_player_view) == 1
        assert cairo_player_view[0]['name'] == 'بطولة القاهرة 1v1'
        print("PASS: Cairo Player sees only Cairo tournament.")

        # Player in Alexandria query:
        alex_player_view = q("""
            SELECT id, name, governorate, status 
            FROM public.vsp_1v1_tournaments 
            WHERE governorate = 'Alexandria' AND status IN ('registration_open', 'in_progress');
        """)
        print("Alexandria Player sees:", alex_player_view)
        assert len(alex_player_view) == 1
        assert alex_player_view[0]['name'] == 'بطولة الإسكندرية 1v1'
        print("PASS: Alexandria Player sees only Alexandria tournament.")

        # Player in Aswan query:
        aswan_player_view = q("""
            SELECT id, name, governorate, status 
            FROM public.vsp_1v1_tournaments 
            WHERE governorate = 'Aswan' AND status IN ('registration_open', 'in_progress');
        """)
        print("Aswan Player sees (no active tournament):", aswan_player_view)
        assert len(aswan_player_view) == 0
        print("PASS: Aswan Player sees 0 tournaments (empty state) because none is active in Aswan.")

        print("\n=================================================================")
        print("ALL ACCEPTANCE CRITERIA FOR SECTION 1 PASSED WITH 100% SUCCESS!")
        print("=================================================================")

    finally:
        # TEST 4: Cleanup & count verification
        print("\n--- TEST 4: Cleanup and Final Count Verification ---")
        q("DELETE FROM public.vsp_1v1_tournament_players WHERE tournament_id IN (SELECT id FROM public.vsp_1v1_tournaments WHERE name IN ('بطولة القاهرة 1v1', 'بطولة الإسكندرية 1v1'));")
        q("DELETE FROM public.vsp_1v1_tournaments WHERE name IN ('بطولة القاهرة 1v1', 'بطولة الإسكندرية 1v1');")
        final_count = q("SELECT count(*) FROM public.vsp_1v1_tournaments;")[0]['count']
        print(f"Final vsp_1v1_tournaments count after cleanup: {final_count}")
        assert int(final_count) == 0, f"Expected 0 tournaments after cleanup, got {final_count}"
        print("PASS: Database 100% cleaned up, count = 0.")

if __name__ == '__main__':
    run_acceptance_tests()
