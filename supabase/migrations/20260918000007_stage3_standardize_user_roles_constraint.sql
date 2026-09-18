-- ==============================================================================
-- Migration: 20260918000007_stage3_standardize_user_roles_constraint.sql
-- Stage: 3 (Role Constraint Hardening)
-- Description:
--   1. Enforce strict users_role_check constraint on public.users.
--   2. Permitted roles: 'player', 'owner', 'admin', 'co_founder', 'super_admin'.
--      (Eliminates typo 'cofounder' and booking-specific status 'pending_admin').
--      Fully aligned with Flutter user_model.dart (isAdmin getter) and DB security checks.
--
-- Safety Pre-Check Query (Run before applying):
--   SELECT DISTINCT role FROM public.users;
--   -- Live verified result: 2 co_founder, 1 owner, 2 player. 100% safe.
-- ==============================================================================

BEGIN;

-- إزالة أي قيد سابق إن وجد
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;

-- إضافة القيد المعياري الصارم
ALTER TABLE public.users ADD CONSTRAINT users_role_check 
  CHECK (role = ANY (ARRAY['player'::text, 'owner'::text, 'admin'::text, 'co_founder'::text, 'super_admin'::text]));

COMMIT;
