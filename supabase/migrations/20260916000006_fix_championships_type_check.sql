-- ==============================================================================
-- MIGRATION: 20260916000006_fix_championships_type_check.sql
-- Harden championships_type_check constraint to be case-insensitive
-- and support both lowercase and capitalized representations.
-- ==============================================================================

ALTER TABLE public.championships DROP CONSTRAINT IF EXISTS "championships_type_check";

ALTER TABLE public.championships ADD CONSTRAINT "championships_type_check" 
CHECK (
  LOWER(type) = ANY (ARRAY['cup'::text, 'league'::text, 'tournament'::text, 'groups'::text, 'knockout'::text, '1v1'::text])
  OR type = ANY (ARRAY['Cup'::text, 'League'::text, 'Groups'::text, 'GroupsAndKnockout'::text])
);
