import urllib.request
import urllib.error
import json
import uuid

# Load credentials
with open('env.json', 'r', encoding='utf-8') as f:
    env = json.load(f)

MANAGEMENT_TOKEN = env.get('SUPABASE_MANAGEMENT_KEY') or 'sbp_de5a1fcaf401fdf49b8c0003f784ee42cb7bef2b'
PROJECT_REF = 'mktqkddbcddrxjxabdua'
URL = f"https://api.supabase.com/v1/projects/{PROJECT_REF}/database/query"

def query_sql(sql: str):
    req = urllib.request.Request(
        URL,
        data=json.dumps({"query": sql}).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {MANAGEMENT_TOKEN}",
            "Content-Type": "application/json",
            "User-Agent": "Mozilla/5.0",
        },
        method="POST"
    )
    with urllib.request.urlopen(req) as resp:
        body = resp.read().decode("utf-8")
        return json.loads(body)

def main():
    print("==========================================================")
    print("STEP 1: Create Tournament #1 (Draft, 3 Players)")
    print("==========================================================")
    # 1. Create Tournament 1
    t1_name = "بطولة الاختبار 1vs1 الأولى"
    sql_t1 = f"""
    INSERT INTO public.vsp_1v1_tournaments (name, target_player_count, status)
    VALUES ('{t1_name}', 3, 'draft')
    RETURNING id, name, target_player_count, status, created_at;
    """
    res_t1 = query_sql(sql_t1)
    print("Tournament 1 Created:", res_t1)
    t1_id = res_t1[0]['id']

    print("\n==========================================================")
    print("STEP 2: Insert 3 Players with Raw Tackles, Goals, Skills")
    print("        (Verifying PostgreSQL GENERATED ALWAYS AS total_points)")
    print("==========================================================")
    # Insert players WITHOUT total_points
    sql_p1 = f"""
    INSERT INTO public.vsp_1v1_tournament_players (tournament_id, player_name, tackles, goals, skills)
    VALUES 
      ('{t1_id}', 'أحمد حسام', 4, 3, 5),   -- total = 12
      ('{t1_id}', 'كريم يوسف', 6, 7, 2),   -- total = 15
      ('{t1_id}', 'علي محمود', 2, 1, 3)    -- total = 6
    RETURNING id, player_name, tackles, goals, skills, total_points;
    """
    res_p1 = query_sql(sql_p1)
    print("Players Inserted in T1 (with DB-computed total_points):")
    for p in res_p1:
        print(f"  - {p['player_name']}: Tackles={p['tackles']}, Goals={p['goals']}, Skills={p['skills']} => DB total_points={p['total_points']}")

    print("\n==========================================================")
    print("STEP 3: Publish Tournament #1 using publish_1v1_tournament_atomic")
    print("==========================================================")
    sql_pub1 = f"""
    SELECT public.publish_1v1_tournament_atomic('{t1_id}'::uuid) as result;
    """
    res_pub1 = query_sql(sql_pub1)
    print("Atomic Publish Result for T1:", res_pub1[0]['result'])
    assert res_pub1[0]['result']['success'] == True, "Failed to publish T1!"

    # Verify status in database
    status_check1 = query_sql(f"SELECT id, name, status, published_at FROM public.vsp_1v1_tournaments WHERE id = '{t1_id}';")
    print("T1 Database Record:", status_check1)
    assert status_check1[0]['status'] == 'published', "T1 is not published!"

    print("\n==========================================================")
    print("STEP 4: Verify Mobile App Query Logic (champion_screen.dart)")
    print("==========================================================")
    sql_mobile = """
    WITH pub_t AS (
      SELECT id, name FROM public.vsp_1v1_tournaments WHERE status = 'published' LIMIT 1
    )
    SELECT p.player_name, p.tackles, p.goals, p.skills, p.total_points,
           ROW_NUMBER() OVER (ORDER BY p.total_points DESC) as rank
    FROM public.vsp_1v1_tournament_players p
    JOIN pub_t ON p.tournament_id = pub_t.id
    ORDER BY p.total_points DESC;
    """
    res_mobile = query_sql(sql_mobile)
    print("Mobile Screen Realtime Standings Feed:")
    for m in res_mobile:
        rank_icon = "🥇 Gold (Center)" if m['rank'] == 1 else ("🥈 Silver (Left)" if m['rank'] == 2 else "🥉 Bronze (Right)")
        print(f"  {rank_icon} Rank #{m['rank']}: {m['player_name']} - Total: {m['total_points']} pts (Tackles: {m['tackles']}, Goals: {m['goals']}, Skills: {m['skills']})")

    assert res_mobile[0]['player_name'] == 'كريم يوسف', "Rank 1 should be Karim Youssef (15 pts)"
    assert res_mobile[1]['player_name'] == 'أحمد حسام', "Rank 2 should be Ahmed Hossam (12 pts)"
    assert res_mobile[2]['player_name'] == 'علي محمود', "Rank 3 should be Ali Mahmoud (6 pts)"

    print("\n==========================================================")
    print("STEP 5: Create & Publish Tournament #2 (Verifying Auto-Archive of T1)")
    print("==========================================================")
    t2_name = "بطولة الاختبار 1vs1 الثانية"
    sql_t2 = f"""
    INSERT INTO public.vsp_1v1_tournaments (name, target_player_count, status)
    VALUES ('{t2_name}', 4, 'draft')
    RETURNING id, name;
    """
    res_t2 = query_sql(sql_t2)
    t2_id = res_t2[0]['id']
    print("Tournament 2 Created:", res_t2)

    # Insert 4 players
    sql_p2 = f"""
    INSERT INTO public.vsp_1v1_tournament_players (tournament_id, player_name, tackles, goals, skills)
    VALUES 
      ('{t2_id}', 'محمد صلاح', 1, 15, 8),  -- total = 24
      ('{t2_id}', 'عمر مرموش', 3, 11, 6),  -- total = 20
      ('{t2_id}', 'إمام عاشور', 5, 4, 4),  -- total = 13
      ('{t2_id}', 'طارق حامد', 10, 2, 1)   -- total = 13
    RETURNING player_name, total_points;
    """
    res_p2 = query_sql(sql_p2)
    print("Players in T2:", res_p2)

    # Publish Tournament 2
    res_pub2 = query_sql(f"SELECT public.publish_1v1_tournament_atomic('{t2_id}'::uuid) as result;")
    print("Atomic Publish Result for T2:", res_pub2[0]['result'])
    assert res_pub2[0]['result']['success'] == True, "Failed to publish T2!"

    print("\n==========================================================")
    print("STEP 6: Verify Tournament 1 was ARCHIVED and NOT DELETED")
    print("==========================================================")
    sql_history = "SELECT id, name, status, published_at FROM public.vsp_1v1_tournaments ORDER BY created_at ASC;"
    res_history = query_sql(sql_history)
    print("All Tournaments in Database:")
    for t in res_history:
        print(f"  - [{t['status'].upper()}] {t['name']} (ID: {t['id']})")

    t1_record = next(t for t in res_history if t['id'] == t1_id)
    t2_record = next(t for t in res_history if t['id'] == t2_id)

    assert t1_record['status'] == 'archived', f"Expected T1 status to be 'archived', got {t1_record['status']}"
    assert t2_record['status'] == 'published', f"Expected T2 status to be 'published', got {t2_record['status']}"
    print("\n>>> ALL VERIFICATION CHECKS PASSED 100% SUCCESSFULLY! <<<")

if __name__ == '__main__':
    main()
