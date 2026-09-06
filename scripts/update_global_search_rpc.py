import sys
sys.path.append('.')
from scripts.db_client import run_sql

sql = """
CREATE OR REPLACE FUNCTION public.global_search(search_term text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $func$
DECLARE
  v_stadiums jsonb;
  v_teams jsonb;
  v_championships jsonb;
  v_clean_query text := trim(search_term);
BEGIN
  IF v_clean_query = '' OR length(v_clean_query) < 2 THEN
    RETURN jsonb_build_object('stadiums', '[]'::jsonb, 'teams', '[]'::jsonb, 'championships', '[]'::jsonb);
  END IF;

  -- 1. الملاعب الموثقة فقط وغير المحظورة
  SELECT COALESCE(jsonb_agg(to_jsonb(s)), '[]'::jsonb)
  INTO v_stadiums
  FROM (
    SELECT id, name, location, governorate, price_per_hour, rating, image_url
    FROM public.stadiums
    WHERE (name ILIKE '%' || v_clean_query || '%' OR location ILIKE '%' || v_clean_query || '%' OR governorate ILIKE '%' || v_clean_query || '%')
      AND is_verified = true 
      AND COALESCE(is_blocked, false) = false
      AND COALESCE(is_deleted_by_owner, false) = false
    LIMIT 10
  ) s;

  -- 2. الفرق
  SELECT COALESCE(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
  INTO v_teams
  FROM (
    SELECT id, name, logo_url, points, governorate, sport_type
    FROM public.teams
    WHERE name ILIKE '%' || v_clean_query || '%'
    LIMIT 10
  ) t;

  -- 3. البطولات (المعتمدة فقط)
  SELECT COALESCE(jsonb_agg(to_jsonb(c)), '[]'::jsonb)
  INTO v_championships
  FROM (
    SELECT id, name, type, start_date, entry_fee, grand_prize, status, logo_url
    FROM public.championships
    WHERE name ILIKE '%' || v_clean_query || '%'
      AND status IN ('open', 'ongoing')
      AND is_approved = true
    LIMIT 10
  ) c;

  RETURN jsonb_build_object(
    'stadiums', v_stadiums,
    'teams', v_teams,
    'championships', v_championships
  );
END;
$func$;
"""

if __name__ == "__main__":
    run_sql(sql)
    print("global_search updated successfully with is_approved = true filter!")
