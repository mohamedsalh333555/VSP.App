-- ====================================================================
-- VSP PLATFORM: STADIUM VERIFICATION & STRICT GOVERNORATE ISOLATION SQL
-- Run this script in your Supabase SQL Editor to enforce 100% DB-level gating.
-- ====================================================================

-- 1. Update get_nearby_stadiums RPC to return ONLY verified & unblocked stadiums
CREATE OR REPLACE FUNCTION public.get_nearby_stadiums(
    user_lat double precision,
    user_lng double precision,
    max_limit integer DEFAULT 10
)
RETURNS SETOF public.stadiums AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM public.stadiums
    WHERE 
        COALESCE(is_verified, false) = true 
        AND COALESCE(is_blocked, false) = false
    LIMIT max_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Enforce Row Level Security (RLS) Policy on stadiums table
ALTER TABLE public.stadiums ENABLE ROW LEVEL SECURITY;

-- Remove older public policies safely if exist
DROP POLICY IF EXISTS "Public verified stadiums read policy" ON public.stadiums;
DROP POLICY IF EXISTS "Public can only read verified and unblocked stadiums" ON public.stadiums;

-- Public users can only see verified and unblocked stadiums. Owners can see their own draft/unverified stadiums.
CREATE POLICY "Public can only read verified and unblocked stadiums"
ON public.stadiums
FOR SELECT
USING (
    (COALESCE(is_verified, false) = true AND COALESCE(is_blocked, false) = false)
    OR 
    (auth.uid() IS NOT NULL AND auth.uid()::text = owner_id::text)
);
