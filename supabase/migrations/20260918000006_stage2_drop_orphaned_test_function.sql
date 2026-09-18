-- ==============================================================================
-- Migration: 20260918000006_stage2_drop_orphaned_test_function.sql
-- Stage: 2 (Low Risk / Isolated Cleanup)
-- Description:
--   Drop orphaned, unhardened test function test_trigger_behavior() from production.
-- ==============================================================================

BEGIN;

DROP FUNCTION IF EXISTS public.test_trigger_behavior();

COMMIT;
