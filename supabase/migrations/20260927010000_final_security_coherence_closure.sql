-- Final security/coherence closure
UPDATE storage.buckets
SET public = false
WHERE id = 'owner_documents';

REVOKE ALL ON FUNCTION public.get_nearby_stadiums(double precision,double precision,integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_nearby_stadiums(double precision,double precision,integer) FROM anon;
REVOKE ALL ON FUNCTION public.get_nearby_stadiums(double precision,double precision,integer) FROM authenticated;
DROP FUNCTION IF EXISTS public.get_nearby_stadiums(double precision,double precision,integer);

CREATE OR REPLACE FUNCTION public.get_nearby_stadiums(
  user_lat numeric,
  user_lng numeric,
  max_limit integer DEFAULT 10
)
RETURNS SETOF public.stadiums
LANGUAGE sql
STABLE
SET search_path = public
AS $function$
  SELECT s.*
  FROM public.stadiums s
  WHERE coalesce(s.is_verified,false)=true
    AND coalesce(s.is_blocked,false)=false
    AND coalesce(s.is_deleted_by_owner,false)=false
    AND s.lat IS NOT NULL
    AND s.lng IS NOT NULL
  ORDER BY ((s.lat-user_lat)*(s.lat-user_lat) + (s.lng-user_lng)*(s.lng-user_lng)) ASC
  LIMIT greatest(1, least(coalesce(max_limit,10),100));
$function$;

REVOKE ALL ON FUNCTION public.get_nearby_stadiums(numeric,numeric,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_nearby_stadiums(numeric,numeric,integer) TO authenticated;
