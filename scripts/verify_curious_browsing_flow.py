import urllib.request, json, sys

env = json.load(open('env.json'))
token = env['SUPABASE_MANAGEMENT_KEY']
url = 'https://api.supabase.com/v1/projects/mktqkddbcddrxjxabdua/database/query'

def run_sql(query):
    req = urllib.request.Request(
        url,
        data=json.dumps({"query": query}).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "User-Agent": "Mozilla/5.0"
        },
        method="POST",
    )
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode("utf-8"))

print("=== STARTING CURIOUS BROWSING & GOVERNORATE SCOPING VERIFICATION ===")

# 1. Clean previous state
run_sql("DELETE FROM public.vsp_1v1_tournament_players WHERE tournament_id IN (SELECT id FROM public.vsp_1v1_tournaments WHERE name LIKE 'TEST_CURIOUS%');")
run_sql("DELETE FROM public.vsp_1v1_tournaments WHERE name LIKE 'TEST_CURIOUS%';")
run_sql("DELETE FROM public.users WHERE id IN ('00000000-0000-0000-0000-000000000991', '00000000-0000-0000-0000-000000000992');")

# 2. Create test users: User 991 (Alexandria), User 992 (Cairo)
run_sql("""
INSERT INTO public.users (id, email, role, name, phone, governorate)
VALUES 
  ('00000000-0000-0000-0000-000000000991', 'alex_curious@test.com', 'player', 'لاعب الإسكندرية', '01011111111', 'Alexandria'),
  ('00000000-0000-0000-0000-000000000992', 'cairo_player@test.com', 'player', 'لاعب القاهرة', '01022222222', 'Cairo');
""")

# 3. Create active tournaments in Cairo and Alexandria simultaneously
cairo_res = run_sql("""
INSERT INTO public.vsp_1v1_tournaments (name, governorate, status, entry_fee, target_player_count)
VALUES ('TEST_CURIOUS_CAIRO', 'Cairo', 'registration_open', 50, 8)
RETURNING id, name, governorate, status;
""")
cairo_id = cairo_res[0]['id']

alex_res = run_sql("""
INSERT INTO public.vsp_1v1_tournaments (name, governorate, status, entry_fee, target_player_count)
VALUES ('TEST_CURIOUS_ALEX', 'Alexandria', 'registration_open', 75, 8)
RETURNING id, name, governorate, status;
""")
alex_id = alex_res[0]['id']

# Test 1: Query for Cairo returns Cairo tournament
cairo_query = run_sql(f"""
SELECT id, name, governorate FROM public.vsp_1v1_tournaments 
WHERE status IN ('registration_open', 'in_progress', 'completed', 'published')
  AND governorate = 'Cairo'
ORDER BY created_at DESC LIMIT 1;
""")
assert cairo_query[0]['name'] == 'TEST_CURIOUS_CAIRO', "Failed to filter Cairo tournament"
print("✓ Filter by Cairo correctly returns Cairo tournament!")

# Test 2: Query for Alexandria returns Alexandria tournament
alex_query = run_sql(f"""
SELECT id, name, governorate FROM public.vsp_1v1_tournaments 
WHERE status IN ('registration_open', 'in_progress', 'completed', 'published')
  AND governorate = 'Alexandria'
ORDER BY created_at DESC LIMIT 1;
""")
assert alex_query[0]['name'] == 'TEST_CURIOUS_ALEX', "Failed to filter Alexandria tournament"
print("✓ Filter by Alexandria correctly returns Alexandria tournament!")

# Test 3: Query for Aswan (empty governorate) returns 0 records
aswan_query = run_sql(f"""
SELECT id, name, governorate FROM public.vsp_1v1_tournaments 
WHERE status IN ('registration_open', 'in_progress', 'completed', 'published')
  AND governorate = 'Aswan'
ORDER BY created_at DESC LIMIT 1;
""")
assert len(aswan_query) == 0, "Aswan should have 0 tournaments"
print("✓ Filter by Aswan correctly returns empty (no active tournament in Aswan)!")

# Test 4: Alexandria player joins their own home tournament (Alexandria) -> Should SUCCEED
join_home = run_sql(f"""
SELECT public.create_1v1_payment_order_atomic(
  '{alex_id}'::uuid,
  '00000000-0000-0000-0000-000000000991'::uuid
) as result;
""")
res_home = join_home[0]['result']
assert res_home.get('success') is True, f"Expected success for home city, got: {res_home}"
print("✓ Player successfully joins their own governorate tournament!")

# Test 5: Alexandria player attempts to join Cairo tournament out of curiosity -> MUST BE REJECTED BY RPC
join_foreign = run_sql(f"""
SELECT public.create_1v1_payment_order_atomic(
  '{cairo_id}'::uuid,
  '00000000-0000-0000-0000-000000000991'::uuid
) as result;
""")
res_foreign = join_foreign[0]['result']
assert res_foreign.get('success') is False, "Foreign governorate join should be rejected"
assert 'خارج محافظتك' in res_foreign.get('error', ''), f"Unexpected error: {res_foreign}"
print("✓ Foreign governorate registration strictly rejected with message: " + res_foreign.get('error'))

# Test 6: Clean up completely (Zero dummy records)
run_sql("DELETE FROM public.vsp_1v1_tournament_players WHERE tournament_id IN (SELECT id FROM public.vsp_1v1_tournaments WHERE name LIKE 'TEST_CURIOUS%');")
run_sql("DELETE FROM public.vsp_1v1_tournaments WHERE name LIKE 'TEST_CURIOUS%';")
run_sql("DELETE FROM public.users WHERE id IN ('00000000-0000-0000-0000-000000000991', '00000000-0000-0000-0000-000000000992');")

count_tourneys = run_sql("SELECT COUNT(*) as count FROM public.vsp_1v1_tournaments;")
assert count_tourneys[0]['count'] == 0, "Database should be clean"
print(f"Final tournaments count in database: {count_tourneys[0]['count']}")
print("✓ Database cleaned up completely! Zero dummy data left.")
print("=== ALL CURIOUS BROWSING & GOVERNORATE SCOPING CHECKS PASSED 100% ===")
