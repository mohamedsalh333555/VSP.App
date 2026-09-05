import urllib.request
import urllib.error
import json

with open('env.json', 'r', encoding='utf-8') as f:
    env = json.load(f)

MANAGEMENT_TOKEN = env.get('SUPABASE_MANAGEMENT_KEY') or 'sbp_de5a1fcaf401fdf49b8c0003f784ee42cb7bef2b'
PROJECT_REF = 'mktqkddbcddrxjxabdua'
URL = f"https://api.supabase.com/v1/projects/{PROJECT_REF}/database/query"

sql = """
CREATE OR REPLACE FUNCTION public.publish_1v1_tournament_atomic(p_tournament_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_caller_role TEXT;
BEGIN
    IF (COALESCE(auth.role(), '') != 'service_role' AND current_user != 'postgres') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Admin access required');
        END IF;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.vsp_1v1_tournaments WHERE id = p_tournament_id) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Tournament not found');
    END IF;

    -- Archive whatever was previously published
    UPDATE public.vsp_1v1_tournaments
    SET status = 'archived'
    WHERE status = 'published' AND id != p_tournament_id;

    -- Publish the target tournament
    UPDATE public.vsp_1v1_tournaments
    SET status = 'published', published_at = timezone('utc'::text, now())
    WHERE id = p_tournament_id;

    RETURN jsonb_build_object('success', true, 'tournament_id', p_tournament_id);
END;
$$;
"""

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

try:
    with urllib.request.urlopen(req) as resp:
        print("Success:", resp.read().decode("utf-8"))
except urllib.error.HTTPError as e:
    print("HTTP Error:", e.code, e.read().decode("utf-8"))
