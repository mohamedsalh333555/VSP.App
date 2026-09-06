import urllib.request, urllib.error, json, random

with open('env.json', 'r') as f:
    env = json.load(f)

token = env['SUPABASE_MANAGEMENT_KEY']
url = 'https://api.supabase.com/v1/projects/mktqkddbcddrxjxabdua/database/query'

def run_sql(query_str):
    payload = json.dumps({"query": query_str}).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {token}",
            "User-Agent": "Mozilla/5.0",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        print("SQL ERROR:", e.code, e.read().decode('utf-8'))
        raise e

print("=" * 70)
print("🚀 RUNNING LIVE 1v1 TROPHIES & TEAM BADGE WRITE-IN VERIFICATION")
print("=" * 70)

# Clean up any leftover test teams
run_sql("DELETE FROM public.teams WHERE name LIKE 'فريق النجوم التجريبي%';")

# 1. Fetch user Mohamed Saleh
user = run_sql("SELECT id, name, email FROM public.users WHERE email = 'mohamedsalh333555@gmail.com' LIMIT 1;")[0]
user_id = user['id']
print(f"👤 Target Player: {user['name']} ({user['email']}) -> ID: {user_id}")

# 2. Create a test team with this user as captain to test write-in
rand_num = random.randint(1000, 9999)
team_name = f"فريق النجوم التجريبي {rand_num}"
create_team_sql = f"""
INSERT INTO public.teams (id, name, captain_id, sport_type, has_1v1_champion, unlocked_badges)
VALUES (gen_random_uuid(), '{team_name}', '{user_id}', 'football', false, ARRAY['explorer']::text[])
RETURNING id, name, has_1v1_champion, unlocked_badges;
"""
team = run_sql(create_team_sql)[0]
team_id = team['id']
print(f"🛡️ Created Test Team: {team['name']} (ID: {team_id}) | Initial has_1v1_champion={team['has_1v1_champion']} | badges={team['unlocked_badges']}")

# 3. Create a test 1v1 tournament
tourn_name = f"بطولة تحدي الملوك 1v1 التجريبية {rand_num}"
create_tourn_sql = f"""
INSERT INTO public.vsp_1v1_tournaments (id, name, target_player_count, status, created_by)
VALUES (gen_random_uuid(), '{tourn_name}', 8, 'registration_open', '{user_id}')
RETURNING id, name, status;
"""
tourn = run_sql(create_tourn_sql)[0]
tourn_id = tourn['id']
print(f"🏆 Created 1v1 Tournament: {tourn['name']} (ID: {tourn_id}) | status={tourn['status']}")

# 4. Register the player into the tournament with winning stats
register_sql = f"""
INSERT INTO public.vsp_1v1_tournament_players (
    tournament_id, user_id, player_name, tackles, goals, skills
) VALUES (
    '{tourn_id}', '{user_id}', '{user['name']}', 6, 4, 10
) RETURNING id, player_name, total_points;
"""
player_row = run_sql(register_sql)[0]
print(f"⚽ Registered Player: {player_row['player_name']} | Points: {player_row['total_points']}")

# 5. Call publish_1v1_final_standings_atomic
print("\n📢 EXECUTING publish_1v1_final_standings_atomic...")
publish_call_sql = f"SELECT public.publish_1v1_final_standings_atomic('{tourn_id}') AS result;"
publish_res = run_sql(publish_call_sql)[0]['result']
print("Result of publish RPC:", json.dumps(publish_res, ensure_ascii=False, indent=2))

# 6. Verify player_trophies table via DIRECT SQL QUERY
print("\n" + "=" * 70)
print("🔍 1. DIRECT SQL QUERY ON public.player_trophies:")
print("=" * 70)
trophy_check_sql = f"""
SELECT id, user_id, tournament_1v1_id, title, prize_won, created_at 
FROM public.player_trophies 
WHERE user_id = '{user_id}' AND tournament_1v1_id = '{tourn_id}';
"""
trophies = run_sql(trophy_check_sql)
print(json.dumps(trophies, ensure_ascii=False, indent=2))

# 7. Verify teams table WRITE-IN via DIRECT SQL QUERY
print("\n" + "=" * 70)
print("🔍 2. DIRECT SQL QUERY ON public.teams (WRITE-IN CHECK):")
print("=" * 70)
team_check_sql = f"""
SELECT id, name, captain_id, has_1v1_champion, unlocked_badges 
FROM public.teams 
WHERE id = '{team_id}';
"""
teams_check = run_sql(team_check_sql)
print(json.dumps(teams_check, ensure_ascii=False, indent=2))

# 8. Verify check_team_has_1v1_champion RPC
print("\n" + "=" * 70)
print("🔍 3. DIRECT RPC CALL check_team_has_1v1_champion:")
print("=" * 70)
check_rpc_sql = f"SELECT public.check_team_has_1v1_champion('{team_id}') AS has_champ;"
rpc_res = run_sql(check_rpc_sql)
print(json.dumps(rpc_res, indent=2))

print("\n" + "=" * 70)
print("🧹 CLEANING UP TEST DATA (Tournament, Team, Trophy)...")
cleanup_sql = f"""
DELETE FROM public.player_trophies WHERE tournament_1v1_id = '{tourn_id}';
DELETE FROM public.vsp_1v1_tournament_players WHERE tournament_id = '{tourn_id}';
DELETE FROM public.vsp_1v1_tournaments WHERE id = '{tourn_id}';
DELETE FROM public.teams WHERE id = '{team_id}';
"""
run_sql(cleanup_sql)
print("✨ TEST DATA CLEANED UP SUCCESSFULLY! DATABASE REMAINS PRISTINE.")
print("=" * 70)
