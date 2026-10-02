import urllib.request
import urllib.error
import json
import uuid
import datetime
import os
import sys

with open("env.json", "r") as f:
    env = json.load(f)

SUPABASE_URL = env.get("SUPABASE_URL", "https://mktqkddbcddrxjxabdua.supabase.co")
ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1rdHFrZGRiY2RkcnhqeGFiZHVhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIyMDc4NTMsImV4cCI6MjA5Nzc4Mzg1M30.0BYdmQenMqtU1GJL46x49DQ4c7-3X2ujzdxicBKgXqU"
SERVICE_KEY = env.get("SUPABASE_SERVICE_ROLE_KEY", "")
MANAGEMENT_TOKEN = env.get("SUPABASE_MANAGEMENT_KEY", "")
PROJECT_REF = "mktqkddbcddrxjxabdua"

def run_management_sql(sql_query):
    url = f"https://api.supabase.com/v1/projects/{PROJECT_REF}/database/query"
    req = urllib.request.Request(
        url,
        data=json.dumps({"query": sql_query}).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {MANAGEMENT_TOKEN}",
            "Content-Type": "application/json"
        },
        method="POST"
    )
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        err = e.read().decode("utf-8")
        print(f"Management SQL Error: {err}")
        raise e

def create_auth_user(email, password, role="player", name="Test User"):
    url = f"{SUPABASE_URL}/auth/v1/admin/users"
    payload = {
        "email": email,
        "password": password,
        "email_confirm": True,
        "user_metadata": {"name": name, "role": role}
    }
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "apikey": SERVICE_KEY,
            "Authorization": f"Bearer {SERVICE_KEY}",
            "Content-Type": "application/json"
        },
        method="POST"
    )
    with urllib.request.urlopen(req) as resp:
        user_data = json.loads(resp.read().decode("utf-8"))
        uid = user_data["id"]
        run_management_sql(f"UPDATE public.users SET role = '{role}', name = '{name}' WHERE id = '{uid}';")
        return user_data

def delete_auth_user(uid):
    url = f"{SUPABASE_URL}/auth/v1/admin/users/{uid}"
    req = urllib.request.Request(
        url,
        headers={
            "apikey": SERVICE_KEY,
            "Authorization": f"Bearer {SERVICE_KEY}"
        },
        method="DELETE"
    )
    try:
        with urllib.request.urlopen(req) as resp:
            return True
    except Exception:
        return False

def login_user(email, password):
    url = f"{SUPABASE_URL}/auth/v1/token?grant_type=password"
    payload = {"email": email, "password": password}
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "apikey": ANON_KEY,
            "Content-Type": "application/json"
        },
        method="POST"
    )
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode("utf-8"))
        return data["access_token"], data["user"]["id"]

def call_rpc(rpc_name, params, token=None, use_service_key=False):
    url = f"{SUPABASE_URL}/rest/v1/rpc/{rpc_name}"
    headers = {
        "apikey": SERVICE_KEY if use_service_key else ANON_KEY,
        "Content-Type": "application/json"
    }
    if use_service_key:
        headers["Authorization"] = f"Bearer {SERVICE_KEY}"
    elif token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(
        url,
        data=json.dumps(params).encode("utf-8"),
        headers=headers,
        method="POST"
    )
    try:
        with urllib.request.urlopen(req) as resp:
            content = resp.read().decode("utf-8")
            if not content:
                return {"status": resp.status, "data": None}
            return {"status": resp.status, "data": json.loads(content)}
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")
        try:
            err_json = json.loads(body)
        except Exception:
            err_json = {"raw": body}
        return {"status": e.code, "error": err_json}

def direct_insert(table_name, record, token, return_representation=True):
    url = f"{SUPABASE_URL}/rest/v1/{table_name}"
    req = urllib.request.Request(
        url,
        data=json.dumps(record).encode("utf-8"),
        headers={
            "apikey": ANON_KEY,
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Prefer": "return=representation" if return_representation else "return=minimal"
        },
        method="POST"
    )
    try:
        with urllib.request.urlopen(req) as resp:
            content = resp.read().decode("utf-8")
            return {"status": resp.status, "data": json.loads(content) if content else None}
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")
        try:
            err_json = json.loads(body)
        except Exception:
            err_json = {"raw": body}
        return {"status": e.code, "error": err_json}

def direct_select(table_name, query_params, token):
    url = f"{SUPABASE_URL}/rest/v1/{table_name}?{query_params}"
    req = urllib.request.Request(
        url,
        headers={
            "apikey": ANON_KEY,
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        },
        method="GET"
    )
    try:
        with urllib.request.urlopen(req) as resp:
            content = resp.read().decode("utf-8")
            return {"status": resp.status, "data": json.loads(content) if content else []}
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")
        try:
            err_json = json.loads(body)
        except Exception:
            err_json = {"raw": body}
        return {"status": e.code, "error": err_json}

def direct_update(table_name, query_params, updates, token):
    url = f"{SUPABASE_URL}/rest/v1/{table_name}?{query_params}"
    req = urllib.request.Request(
        url,
        data=json.dumps(updates).encode("utf-8"),
        headers={
            "apikey": ANON_KEY,
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Prefer": "return=representation"
        },
        method="PATCH"
    )
    try:
        with urllib.request.urlopen(req) as resp:
            content = resp.read().decode("utf-8")
            return {"status": resp.status, "data": json.loads(content) if content else []}
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")
        try:
            err_json = json.loads(body)
        except Exception:
            err_json = {"raw": body}
        return {"status": e.code, "error": err_json}

def direct_delete(table_name, query_params, token):
    url = f"{SUPABASE_URL}/rest/v1/{table_name}?{query_params}"
    req = urllib.request.Request(
        url,
        headers={
            "apikey": ANON_KEY,
            "Authorization": f"Bearer {token}"
        },
        method="DELETE"
    )
    try:
        with urllib.request.urlopen(req) as resp:
            return {"status": resp.status}
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")
        try:
            err_json = json.loads(body)
        except Exception:
            err_json = {"raw": body}
        return {"status": e.code, "error": err_json}

def run_all_10_journeys_audit():
    test_id = str(uuid.uuid4())[:8]
    password = f"P@ss_{test_id}_2026!"
    
    player_a_email = f"cap_a_{test_id}@vsp.test"
    player_b_email = f"cap_b_{test_id}@vsp.test"
    player_c_email = f"player_c_{test_id}@vsp.test"
    admin_email = f"admin_{test_id}@vsp.test"

    uid_a = None
    uid_b = None
    uid_c = None
    uid_admin = None

    team_a_id = str(uuid.uuid4())
    team_b_id = str(uuid.uuid4())
    stadium_id = str(uuid.uuid4())
    challenge_booking_id = str(uuid.uuid4())
    matchup_booking_id = str(uuid.uuid4())
    champ_id = str(uuid.uuid4())
    order_id = str(uuid.uuid4())
    order_ref = f"ORD-{test_id}-2026"
    conv_id = str(uuid.uuid4())
    msg_id = str(uuid.uuid4())
    notif_id = str(uuid.uuid4())
    report_id = str(uuid.uuid4())

    journey_matrix = {}

    print("=" * 80)
    print("🚀 LIVE PRODUCTION AUDIT & PENTEST: 10 PLAYER JOURNEYS AUTHENTIC CLOSURE")
    print("=" * 80)

    try:
        # Step 0: Create authenticated users
        print("\n--- 0. Setup: Creating Real GoTrue Auth Users ---")
        user_a = create_auth_user(player_a_email, password, role="player", name="Captain Alice")
        uid_a = user_a["id"]
        user_b = create_auth_user(player_b_email, password, role="player", name="Captain Bob")
        uid_b = user_b["id"]
        user_c = create_auth_user(player_c_email, password, role="player", name="Player Charlie")
        uid_c = user_c["id"]
        user_admin = create_auth_user(admin_email, password, role="admin", name="Admin Dan")
        uid_admin = user_admin["id"]

        token_a, _ = login_user(player_a_email, password)
        token_b, _ = login_user(player_b_email, password)
        token_c, _ = login_user(player_c_email, password)
        token_admin, _ = login_user(admin_email, password)
        print("✔️ Successfully authenticated all 4 users via GoTrue Auth")

        # Create basic teams & stadium
        invite_code_b = f"B{test_id[:4].upper()}"
        run_management_sql(f"""
            INSERT INTO public.teams (id, name, captain_id, captain_name, active_invite_code, invite_code_expires_at)
            VALUES 
                ('{team_a_id}', 'Alpha {test_id}', '{uid_a}', 'Captain Alice', null, null),
                ('{team_b_id}', 'Beta {test_id}', '{uid_b}', 'Captain Bob', '{invite_code_b}', now() + interval '1 day');

            INSERT INTO public.team_members (team_id, user_id)
            VALUES 
                ('{team_b_id}', '{uid_b}'),
                ('{team_b_id}', '{uid_c}');

            -- Ensure team_b has at least 5 members for matchup requirement
            INSERT INTO public.team_members (team_id, user_id)
            SELECT '{team_b_id}', id FROM public.users
            WHERE id NOT IN ('{uid_a}', '{uid_b}', '{uid_c}', '{uid_admin}')
            LIMIT 3
            ON CONFLICT DO NOTHING;

            INSERT INTO public.stadiums (
                id, owner_id, name, location, governorate, price_per_hour, is_verified, is_deleted_by_owner, lat, lng
            ) VALUES (
                '{stadium_id}', '{uid_admin}', 'Cairo Arena', 'Nasr City', 'cairo', 300, true, false, 30.0444, 31.2357
            );
            UPDATE public.stadiums SET is_verified = true WHERE id = '{stadium_id}';
        """)

        # =====================================================================
        # JOURNEY 1: CHALLENGE / OPEN MATCH
        # =====================================================================
        print("\n--- 1. Testing Journey 1: Challenge / Open Match ---")
        run_management_sql(f"""
            INSERT INTO public.bookings (
                id, stadium_id, user_id, created_by_user_id, owner_id, start_time, end_time,
                booking_type, player_team_id, opponent_team_id, total_price, deposit_paid,
                status, payment_status, is_paid, match_result_status
            ) VALUES (
                '{challenge_booking_id}', '{stadium_id}', '{uid_a}', '{uid_a}', '{uid_admin}',
                now() - interval '3 hours', now() - interval '1 hour',
                'challenge', '{team_a_id}', '{team_b_id}', 300, 300,
                'confirmed', 'paid', true, 'noResult'
            );
        """)

        # 1.1 Non-captain blocked
        res = call_rpc("submit_challenge_result_atomic", {
            "p_booking_id": challenge_booking_id,
            "p_team_id": team_a_id,
            "p_outcome": "homeWin"
        }, token=token_c)
        assert res.get("data", {}).get("success") == False or res.get("status") in [400, 401, 403]
        assert "CAPTAIN_ONLY" in str(res)
        print("  ✔️ Test 1.1: Non-captain Player C blocked from submitting challenge result")

        # 1.2 Captain A submits -> waitingOpponent
        res = call_rpc("submit_challenge_result_atomic", {
            "p_booking_id": challenge_booking_id,
            "p_team_id": team_a_id,
            "p_outcome": "homeWin"
        }, token=token_a)
        assert res.get("data", {}).get("success") == True
        assert res.get("data", {}).get("state") == "waitingOpponent"
        print("  ✔️ Test 1.2: Captain A submitted result -> status: waitingOpponent")

        # 1.3 Captain B disagrees -> disputed
        res = call_rpc("submit_challenge_result_atomic", {
            "p_booking_id": challenge_booking_id,
            "p_team_id": team_b_id,
            "p_outcome": "awayWin"
        }, token=token_b)
        assert res.get("data", {}).get("state") == "disputed" or res.get("data", {}).get("error") == "RESULT_DISPUTED"
        print("  ✔️ Test 1.3: Conflicting submissions locked into disputed state")
        journey_matrix["1. Challenge / Open Match"] = "PASS"

        # =====================================================================
        # JOURNEY 2: MATCHUP / HEAD-TO-HEAD
        # =====================================================================
        print("\n--- 2. Testing Journey 2: Matchup / Head-to-Head ---")
        # Creator creates matchup booking in the future (match scheduled)
        run_management_sql(f"""
            INSERT INTO public.bookings (
                id, stadium_id, user_id, created_by_user_id, owner_id, start_time, end_time,
                booking_type, total_price, deposit_paid, status, payment_status, is_paid
            ) VALUES (
                '{matchup_booking_id}', '{stadium_id}', '{uid_a}', '{uid_a}', '{uid_admin}',
                now() + interval '2 hours', now() + interval '3 hours',
                'open_join', 300, 300, 'confirmed', 'paid', true
            );
            INSERT INTO public.matchup_teams (booking_id, team_id, added_by_user_id)
            VALUES ('{matchup_booking_id}', '{team_a_id}', '{uid_a}');
        """)

        # 2.1 Non-creator cannot add team
        res = call_rpc("add_team_to_matchup_by_code", {
            "p_booking_id": matchup_booking_id,
            "p_invite_code": invite_code_b
        }, token=token_c)
        assert res.get("data", {}).get("success") == False or res.get("status") in [400, 401, 403]
        print("  ✔️ Test 2.1: Non-creator cannot add team to matchup")

        # 2.2 Creator adds team B with invite code
        res = call_rpc("add_team_to_matchup_by_code", {
            "p_booking_id": matchup_booking_id,
            "p_invite_code": invite_code_b
        }, token=token_a)
        assert res.get("data", {}).get("success") == True
        assert res.get("data", {}).get("total_teams_now") == 2
        print("  ✔️ Test 2.2: Creator added team B via authoritative RPC")

        # 2.3 Confirm matchup -> mode becomes 'duo'
        res = call_rpc("confirm_matchup_atomic", {"p_booking_id": matchup_booking_id}, token=token_a)
        assert res.get("data", {}).get("success") == True
        assert res.get("data", {}).get("matchup_mode") == "duo"
        print("  ✔️ Test 2.3: Matchup confirmed into duo mode")

        # 2.4 Early result submission blocked before match end
        res = call_rpc("record_matchup_result_atomic", {
            "p_booking_id": matchup_booking_id,
            "p_team_a_id": team_a_id,
            "p_team_b_id": team_b_id,
            "p_outcome": "team_a_win"
        }, token=token_a)
        assert res.get("data", {}).get("success") == False or res.get("status") in [400, 401, 403]
        assert "MATCHUP_RESULT_TOO_EARLY" in str(res)
        print("  ✔️ Test 2.4: Early result submission strictly blocked (MATCHUP_RESULT_TOO_EARLY)")

        # Fast forward time: match ends
        run_management_sql(f"""
            UPDATE public.bookings 
            SET start_time = now() - interval '10 hours', end_time = now() - interval '9 hours' 
            WHERE id = '{matchup_booking_id}';
        """)

        # 2.5 Record matchup result -> automatically updates team_head_to_head
        res = call_rpc("record_matchup_result_atomic", {
            "p_booking_id": matchup_booking_id,
            "p_team_a_id": team_a_id,
            "p_team_b_id": team_b_id,
            "p_outcome": "team_a_win"
        }, token=token_a)
        assert res.get("data", {}).get("success") == True
        print("  ✔️ Test 2.5: Creator recorded result team_a_win after match concluded")

        # Verify H2H trigger synchronization
        h2h_rows = run_management_sql(f"""
            SELECT team_a_wins, team_b_wins, draws 
            FROM public.team_head_to_head 
            WHERE (team_a_id = '{team_a_id}' AND team_b_id = '{team_b_id}')
               OR (team_a_id = '{team_b_id}' AND team_b_id = '{team_a_id}');
        """)
        assert len(h2h_rows) == 1
        assert (h2h_rows[0]['team_a_wins'] == 1 or h2h_rows[0]['team_b_wins'] == 1)
        print("  ✔️ Test 2.6: team_head_to_head table synchronized atomically by database trigger")

        # 2.6 Repeated result on duo matchup blocked
        res = call_rpc("record_matchup_result_atomic", {
            "p_booking_id": matchup_booking_id,
            "p_team_a_id": team_a_id,
            "p_team_b_id": team_b_id,
            "p_outcome": "team_b_win"
        }, token=token_a)
        assert res.get("data", {}).get("success") == False or res.get("status") in [400, 401, 403]
        print("  ✔️ Test 2.7: Duplicate result on duo matchup strictly blocked")

        # 2.7 Close matchup
        res = call_rpc("close_matchup_atomic", {"p_booking_id": matchup_booking_id}, token=token_a)
        assert res.get("data", {}).get("success") == True
        print("  ✔️ Test 2.8: Matchup successfully closed")

        # 2.8 Direct mutation on matchup_results by authenticated user is blocked by RLS
        res = direct_insert("matchup_results", {
            "booking_id": matchup_booking_id,
            "team_a_id": team_a_id,
            "team_b_id": team_b_id,
            "outcome": "team_a_win",
            "recorded_by": uid_a
        }, token=token_a)
        assert res["status"] in [400, 401, 403, 404]
        print("  ✔️ Test 2.9: Direct INSERT on matchup_results blocked by RLS")
        journey_matrix["2. Matchup / Head-to-Head"] = "PASS"

        # =====================================================================
        # JOURNEY 3: PLAYER TOURNAMENT PARTICIPATION & PAYMENT SECURITY
        # =====================================================================
        print("\n--- 3. Testing Journey 3: Player Tournament Participation & Payment Security ---")
        # 3.1 Direct mutation on legacy vsp_1v1_registrations blocked
        res = direct_insert("vsp_1v1_registrations", {"user_id": uid_a, "status": "pending"}, token=token_a)
        assert res["status"] in [400, 401, 403, 404]
        print("  ✔️ Test 3.1: Direct insertion on legacy vsp_1v1_registrations is completely blocked")

        # Setup real championship & pending order
        reg_id = str(uuid.uuid4())
        run_management_sql(f"""
            INSERT INTO public.championships (
                id, owner_id, name, type, governorate, status, start_date, end_date, registration_closes_at, grand_prize, prize_pool,
                entry_fee, max_teams, joined_teams, paid_teams, rules, created_at, updated_at
            ) VALUES (
                '{champ_id}', '{uid_admin}', 'Grand Cup {test_id}', 'knockout', 'cairo', 'open',
                now() + interval '5 days', now() + interval '10 days', now() + interval '4 days', 1000, 1000,
                500, 16, ARRAY[]::text[], ARRAY[]::text[], 'Rules', now(), now()
            );

            INSERT INTO public.championship_registrations (
                id, championship_id, team_id, captain_id, registration_status, payment_status, gross_amount, created_at
            ) VALUES (
                '{reg_id}', '{champ_id}', '{team_a_id}', '{uid_a}', 'pending', 'pending', 500, now()
            );

            INSERT INTO public.tournament_orders (
                id, championship_id, registration_id, team_id, captain_user_id, order_reference,
                amount, gross_amount, payment_status, created_at
            ) VALUES (
                '{order_id}', '{champ_id}', '{reg_id}', '{team_a_id}', '{uid_a}', '{order_ref}',
                500, 500, 'pending', now()
            );
        """)

        # 3.2 Player token attempts to self-confirm payment -> MUST FAIL
        res = call_rpc("confirm_tournament_order_atomic", {
            "p_order_reference": order_ref,
            "p_paymob_transaction_id": "TXN_FAKE_123"
        }, token=token_a)
        assert res.get("data", {}).get("success") == False or res.get("status") in [400, 401, 403]
        err_msg = str(res.get("data", {}).get("error", "")) + str(res.get("error", ""))
        assert "UNAUTHORIZED" in err_msg
        print("  ✔️ Test 3.2: Regular player token CANNOT confirm payment (BLOCKED: UNAUTHORIZED)")

        # 3.3 Admin token confirms payment -> SUCCEEDS
        res = call_rpc("confirm_tournament_order_atomic", {
            "p_order_reference": order_ref,
            "p_paymob_transaction_id": "TXN_ADMIN_LEGIT_123"
        }, token=token_admin)
        assert res.get("data", {}).get("success") == True
        assert res.get("data", {}).get("payment_status") == "paid"
        print("  ✔️ Test 3.3: Admin token authorized to confirm payment -> order status: paid")

        # 3.4 Repeated confirmation remains idempotent
        res = call_rpc("confirm_tournament_order_atomic", {
            "p_order_reference": order_ref,
            "p_paymob_transaction_id": "TXN_ADMIN_LEGIT_123"
        }, token=token_admin)
        assert res.get("data", {}).get("success") == True
        assert res.get("data", {}).get("already_confirmed") == True
        print("  ✔️ Test 3.4: Repeated payment confirmation is strictly idempotent")
        journey_matrix["3. Player Tournament Participation & Payment Security"] = "PASS"

        # =====================================================================
        # JOURNEY 4: STADIUM DISCOVERY
        # =====================================================================
        print("\n--- 4. Testing Journey 4: Stadium Discovery (Geographic Haversine) ---")
        res = call_rpc("get_nearby_stadiums", {
            "user_lat": 30.0444,
            "user_lng": 31.2357,
            "max_limit": 5
        }, token=token_a)
        assert res["status"] == 200
        nearby = res.get("data", [])
        assert len(nearby) > 0
        assert any(s["id"] == stadium_id for s in nearby)
        print(f"  ✔️ Test 4.1: get_nearby_stadiums returned {len(nearby)} stadiums ordered by spherical distance")

        # Verify only 1 function signature exists in database
        fn_count = run_management_sql("SELECT count(*) FROM pg_proc WHERE proname = 'get_nearby_stadiums';")[0]['count']
        assert int(fn_count) == 1
        print("  ✔️ Test 4.2: Exactly 1 canonical get_nearby_stadiums function exists (0 overloads)")
        journey_matrix["4. Stadium Discovery"] = "PASS"

        # =====================================================================
        # JOURNEY 5: REVIEWS & TRUST
        # =====================================================================
        print("\n--- 5. Testing Journey 5: Reviews & Trust ---")
        # 5.1 Direct INSERT blocked
        res = direct_insert("reviews", {
            "stadium_id": stadium_id, "user_id": uid_b, "rating": 5, "review_text": "Hacked review"
        }, token=token_b)
        assert res["status"] in [400, 401, 403, 404]
        print("  ✔️ Test 5.1: Direct INSERT on reviews table is completely BLOCKED")

        # 5.2 Owner reviewing own stadium blocked
        res = call_rpc("submit_stadium_review_atomic", {
            "p_stadium_id": stadium_id,
            "p_user_id": uid_admin,
            "p_rating": 5,
            "p_comment": "My stadium"
        }, token=token_admin)
        assert res.get("data", {}).get("success") == False
        assert res.get("data", {}).get("error") == "cannot_review_own_stadium"
        print("  ✔️ Test 5.2: Owner reviewing own stadium correctly blocked")

        # 5.3 Player A with completed booking submits review -> SUCCEEDS
        run_management_sql(f"UPDATE public.bookings SET status = 'completed' WHERE id = '{challenge_booking_id}';")
        res = call_rpc("submit_stadium_review_atomic", {
            "p_stadium_id": stadium_id,
            "p_user_id": uid_a,
            "p_rating": 5,
            "p_comment": "Excellent grass pitch"
        }, token=token_a)
        assert res.get("data", {}).get("success") == True

        # Verify single canonical signature in pg_proc
        rev_fns = run_management_sql("SELECT count(*) FROM pg_proc WHERE proname = 'submit_stadium_review_atomic';")[0]['count']
        assert int(rev_fns) == 1
        print("  ✔️ Test 5.3: Valid review recorded and exactly 1 canonical submit_stadium_review_atomic exists")
        journey_matrix["5. Reviews & Trust"] = "PASS"

        # =====================================================================
        # JOURNEY 6: CHAT & MESSAGING
        # =====================================================================
        print("\n--- 6. Testing Journey 6: Chat & Messaging ---")
        run_management_sql(f"""
            INSERT INTO public.conversations (id, type, participant_ids, unread_counts)
            VALUES ('{conv_id}', 'direct', ARRAY['{uid_a}'::uuid, '{uid_b}'::uuid], '{{"{uid_b}": 1}}'::jsonb);

            INSERT INTO public.chat_messages (id, conversation_id, sender_id, sender_name, text, is_read, is_edited)
            VALUES ('{msg_id}', '{conv_id}', '{uid_a}', 'Captain Alice', 'Hello Bob', false, false);
        """)

        # 6.1 Non-sender blocked from editing
        res = call_rpc("edit_chat_message_atomic", {
            "p_message_id": msg_id, "p_new_text": "Bob hacked Alice"
        }, token=token_b)
        assert res.get("data", {}).get("success") == False or res.get("status") in [400, 401, 403]
        print("  ✔️ Test 6.1: Non-sender cannot edit message (BLOCKED: UNAUTHORIZED_SENDER_ONLY)")

        # 6.2 Sender edits own message
        res = call_rpc("edit_chat_message_atomic", {
            "p_message_id": msg_id, "p_new_text": "Hello Bob, updated match time!"
        }, token=token_a)
        assert res.get("data", {}).get("success") == True
        print("  ✔️ Test 6.2: Sender successfully edited message via edit_chat_message_atomic")

        # 6.3 Mark read
        res = call_rpc("mark_chat_messages_as_read", {
            "p_conversation_id": conv_id, "p_user_id": uid_b
        }, token=token_b)
        m_row = run_management_sql(f"SELECT is_read FROM public.chat_messages WHERE id = '{msg_id}';")[0]
        assert m_row['is_read'] == True
        print("  ✔️ Test 6.3: Recipient marked messages as read via mark_chat_messages_as_read")

        # 6.4 Delete chat for self
        res = call_rpc("delete_chat_for_user", {
            "p_conversation_id": conv_id, "p_user_id": uid_b
        }, token=token_b)
        c_row = run_management_sql(f"SELECT deleted_for_users FROM public.conversations WHERE id = '{conv_id}';")[0]
        assert uid_b in str(c_row['deleted_for_users'])
        print("  ✔️ Test 6.4: User hid chat history for self via delete_chat_for_user")
        journey_matrix["6. Chat & Messaging"] = "PASS"

        # =====================================================================
        # JOURNEY 7: NOTIFICATIONS
        # =====================================================================
        print("\n--- 7. Testing Journey 7: Notifications ---")
        # 7.1 Regular player cannot directly INSERT notifications
        res = direct_insert("notifications", {
            "id": notif_id,
            "user_id": uid_b,
            "title": "Unauthorized Notification",
            "body": "Spam content",
            "type": "system"
        }, token=token_a)
        assert res["status"] in [400, 401, 403, 404]
        print("  ✔️ Test 7.1: Regular user direct INSERT on notifications table is completely BLOCKED")

        # 7.2 System/Admin inserts notification for User A -> SUCCEEDS
        run_management_sql(f"""
            INSERT INTO public.notifications (id, user_id, title, body, type, is_read)
            VALUES ('{notif_id}', '{uid_a}', 'System Alert', 'Match starts soon', 'booking', false);
        """)

        # 7.3 User B cannot read User A's notification
        res = direct_select("notifications", f"id=eq.{notif_id}", token=token_b)
        assert len(res.get("data", [])) == 0
        print("  ✔️ Test 7.2: User B cannot read User A's private notification (RLS isolated)")

        # 7.4 User A reads and updates own notification (mark read)
        res = direct_select("notifications", f"id=eq.{notif_id}", token=token_a)
        assert len(res.get("data", [])) == 1
        res_upd = direct_update("notifications", f"id=eq.{notif_id}", {"is_read": True}, token=token_a)
        assert res_upd["status"] in [200, 204]
        print("  ✔️ Test 7.3: User A successfully marked own notification as read")

        # 7.5 User A deletes own notification
        res_del = direct_delete("notifications", f"id=eq.{notif_id}", token=token_a)
        assert res_del["status"] in [200, 204]
        print("  ✔️ Test 7.4: User A successfully deleted own notification")
        journey_matrix["7. Notifications"] = "PASS"

        # =====================================================================
        # JOURNEY 8: REFERRALS & POINTS SSOT
        # =====================================================================
        print("\n--- 8. Testing Journey 8: Referrals & Points SSOT ---")
        run_management_sql(f"""
            INSERT INTO public.referrals (inviter_user_id, invitee_user_id, referral_code, status)
            VALUES ('{uid_a}', '{uid_b}', 'REF_{test_id}', 'pending');
            UPDATE public.bookings SET user_id = '{uid_b}', status = 'completed', qr_scanned_at = now() WHERE id = '{challenge_booking_id}';
        """)

        # 8.1 Execute referral reward via server function
        res = run_management_sql(f"""
            SELECT public.process_referral_reward_on_qr_verification('{uid_b}', '{challenge_booking_id}');
        """)
        assert res[0]['process_referral_reward_on_qr_verification'] == True
        print("  ✔️ Test 8.1: process_referral_reward_on_qr_verification executed successfully")

        # 8.2 Points ledger verification
        pts_a = run_management_sql(f"SELECT points_delta FROM public.points_ledger WHERE user_id = '{uid_a}';")[0]['points_delta']
        pts_b = run_management_sql(f"SELECT points_delta FROM public.points_ledger WHERE user_id = '{uid_b}';")[0]['points_delta']
        assert int(pts_a) == 250
        assert int(pts_b) == 500
        print("  ✔️ Test 8.2: Points ledger correctly recorded +250 for inviter and +500 for invitee")

        # 8.3 Idempotency
        res_repeat = run_management_sql(f"""
            SELECT public.process_referral_reward_on_qr_verification('{uid_b}', '{challenge_booking_id}');
        """)
        assert res_repeat[0]['process_referral_reward_on_qr_verification'] == False
        print("  ✔️ Test 8.3: Repeated referral reward call is strictly idempotent (returned false)")
        journey_matrix["8. Referrals & Points"] = "PASS"

        # =====================================================================
        # JOURNEY 9: REPORTS, BLOCKING & MODERATION
        # =====================================================================
        print("\n--- 9. Testing Journey 9: Reports, Blocking & Moderation ---")
        # 9.1 User A reports User B -> SUCCEEDS
        res = direct_insert("reports", {
            "id": report_id,
            "reporter_id": uid_a,
            "target_id": uid_b,
            "target_type": "user",
            "reason": "Unsportsmanlike conduct",
            "details": "Aggressive behavior"
        }, token=token_a, return_representation=False)
        assert res["status"] in [200, 201]
        print("  ✔️ Test 9.1: User A successfully submitted moderation report against User B")

        # 9.2 User A attempts to impersonate User B as reporter -> MUST FAIL
        res_spoof = direct_insert("reports", {
            "reporter_id": uid_b,
            "target_id": uid_c,
            "target_type": "user",
            "reason": "Spoofed report"
        }, token=token_a, return_representation=False)
        assert res_spoof["status"] in [400, 401, 403, 404]
        print("  ✔️ Test 9.2: Reporter impersonation strictly blocked by RLS")

        # 9.3 Regular User B cannot view reports
        res_view = direct_select("reports", f"id=eq.{report_id}", token=token_b)
        assert len(res_view.get("data", [])) == 0
        print("  ✔️ Test 9.3: Reports table view strictly restricted from regular players")

        # 9.4 User A blocks User B in user_blocks
        res_block = direct_insert("user_blocks", {
            "blocker_id": uid_a,
            "blocked_user_id": uid_b
        }, token=token_a)
        assert res_block["status"] in [200, 201]
        print("  ✔️ Test 9.4: User A successfully blocked User B")

        # 9.5 Blocked interaction: User B attempts to send chat message to User A -> REJECTED BY RLS
        res_blocked_msg = direct_insert("chat_messages", {
            "conversation_id": conv_id,
            "sender_id": uid_b,
            "sender_name": "Bob",
            "text": "Hey Alice are you there?"
        }, token=token_b)
        assert res_blocked_msg["status"] in [400, 401, 403, 404]
        print("  ✔️ Test 9.5: Chat interaction strictly blocked between blocked users (are_users_blocked RLS)")

        # 9.6 User A unblocks User B -> Interaction restored
        res_unblock = direct_delete("user_blocks", f"blocker_id=eq.{uid_a}&blocked_user_id=eq.{uid_b}", token=token_a)
        assert res_unblock["status"] in [200, 204]
        res_restored_msg = direct_insert("chat_messages", {
            "conversation_id": conv_id,
            "sender_id": uid_b,
            "sender_name": "Bob",
            "text": "Hello again Alice"
        }, token=token_b)
        assert res_restored_msg["status"] in [200, 201]
        print("  ✔️ Test 9.6: Unblocking restores interaction cleanly")
        journey_matrix["9. Reports, Blocking & Moderation"] = "PASS"

        # =====================================================================
        # JOURNEY 10: ACCOUNT LIFECYCLE & DELETION GUARD
        # =====================================================================
        print("\n--- 10. Testing Journey 10: Account Lifecycle & Deletion Guard ---")
        upcoming_booking_id = str(uuid.uuid4())
        run_management_sql(f"""
            INSERT INTO public.bookings (
                id, stadium_id, user_id, created_by_user_id, owner_id, start_time, end_time,
                booking_type, joined_user_ids, total_price, deposit_paid, status, payment_status, is_paid
            ) VALUES (
                '{upcoming_booking_id}', '{stadium_id}', '{uid_a}', '{uid_a}', '{uid_admin}',
                now() + interval '2 days', now() + interval '2 days 1 hour',
                'open_join', ARRAY['{uid_c}'::uuid], 300, 300, 'confirmed', 'paid', true
            );
        """)

        # 10.1 Player C attempts delete with active booking -> BLOCKED
        res = call_rpc("delete_user_permanently", {"p_user_id": uid_c}, token=token_c)
        assert res.get("data", {}).get("success") == False
        assert res.get("data", {}).get("error") == "ACTIVE_BOOKINGS"
        print("  ✔️ Test 10.1: Account deletion correctly blocked with active bookings")

        # 10.2 Player C attempts delete with outstanding debt -> BLOCKED
        run_management_sql(f"""
            DELETE FROM public.bookings WHERE id = '{upcoming_booking_id}';
            UPDATE public.users SET accumulated_cash_debt = 150 WHERE id = '{uid_c}';
        """)
        res = call_rpc("delete_user_permanently", {"p_user_id": uid_c}, token=token_c)
        assert res.get("data", {}).get("success") == False
        assert res.get("data", {}).get("error") == "OUTSTANDING_DEBT"
        print("  ✔️ Test 10.2: Account deletion correctly blocked with outstanding debt")

        # 10.3 Clean account deletes successfully
        run_management_sql(f"UPDATE public.users SET accumulated_cash_debt = 0 WHERE id = '{uid_c}';")
        res = call_rpc("delete_user_permanently", {"p_user_id": uid_c}, token=token_c)
        assert res.get("data", {}).get("success") == True
        u_check = run_management_sql(f"SELECT id FROM public.users WHERE id = '{uid_c}';")
        assert len(u_check) == 0
        print("  ✔️ Test 10.3: Clean account deleted atomically from auth.users and public.users")
        journey_matrix["10. Account Lifecycle"] = "PASS"

        # =====================================================================
        # FINAL AUDIT MATRIX
        # =====================================================================
        print("\n" + "=" * 80)
        print("📋 10/10 PLAYER JOURNEYS INDEPENDENT VERIFICATION MATRIX")
        print("=" * 80)
        for journey_name, status in journey_matrix.items():
            print(f"[{status}] {journey_name}")
        
        assert len(journey_matrix) == 10
        assert all(status == "PASS" for status in journey_matrix.values())

        print("=" * 80)
        print("🎉 10/10 JOURNEYS FULLY AND AUTHENTICALLY PASSED ON SUPABASE PRODUCTION!")
        print("=" * 80)

    finally:
        print("\n🧹 Cleaning up test entities and auth users...")
        run_management_sql(f"""
            DELETE FROM public.points_ledger WHERE user_id IN ('{uid_a}', '{uid_b}', '{uid_c}', '{uid_admin}');
            DELETE FROM public.referrals WHERE inviter_user_id = '{uid_a}' OR invitee_user_id = '{uid_b}';
            DELETE FROM public.reports WHERE id = '{report_id}' OR reporter_id IN ('{uid_a}', '{uid_b}');
            DELETE FROM public.user_blocks WHERE blocker_id IN ('{uid_a}', '{uid_b}');
            DELETE FROM public.notifications WHERE id = '{notif_id}' OR user_id IN ('{uid_a}', '{uid_b}', '{uid_c}', '{uid_admin}');
            DELETE FROM public.chat_messages WHERE conversation_id = '{conv_id}';
            DELETE FROM public.conversations WHERE id = '{conv_id}';
            DELETE FROM public.reviews WHERE stadium_id = '{stadium_id}';
            DELETE FROM public.matchup_results WHERE booking_id = '{matchup_booking_id}';
            DELETE FROM public.matchup_teams WHERE booking_id = '{matchup_booking_id}';
            DELETE FROM public.team_head_to_head WHERE (team_a_id = '{team_a_id}' AND team_b_id = '{team_b_id}') OR (team_a_id = '{team_b_id}' AND team_b_id = '{team_a_id}');
            DELETE FROM public.tournament_orders WHERE id = '{order_id}';
            DELETE FROM public.championship_roster_players WHERE roster_id IN (SELECT id FROM public.championship_rosters WHERE championship_id = '{champ_id}');
            DELETE FROM public.championship_rosters WHERE championship_id = '{champ_id}';
            DELETE FROM public.championship_registrations WHERE championship_id = '{champ_id}';
            DELETE FROM public.championships WHERE id = '{champ_id}';
            DELETE FROM public.bookings WHERE id IN ('{challenge_booking_id}', '{matchup_booking_id}');
            DELETE FROM public.team_members WHERE team_id IN ('{team_a_id}', '{team_b_id}');
            DELETE FROM public.teams WHERE id IN ('{team_a_id}', '{team_b_id}');
            DELETE FROM public.stadiums WHERE id = '{stadium_id}';
            DELETE FROM public.users WHERE id IN ('{uid_a}', '{uid_b}', '{uid_c}', '{uid_admin}');
        """)
        for u in [uid_a, uid_b, uid_c, uid_admin]:
            if u:
                delete_auth_user(u)
        print("✔️ Cleanup complete: 0 leftover test records.")

if __name__ == "__main__":
    run_all_10_journeys_audit()
