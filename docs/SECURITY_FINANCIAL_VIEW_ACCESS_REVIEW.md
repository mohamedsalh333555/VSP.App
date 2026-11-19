# Financial reporting view access review

Staging finding: the views `admin_pending_refunds`, `admin_stadium_settlements`, and `v_financial_reconciliation` are security-definer views with SELECT granted to anonymous and authenticated database roles. These views expose financial information, and one includes phone and payment-reference columns. An actual unauthorized read has not been demonstrated.

Remediation plan: first identify all application and backend consumers. Restrict financial admin reporting to authorized backend/admin paths; use security-invoker views and ownership-scoped policies where owner access is required. Verify with separate anonymous, player, owner, and administrator sessions. Do not change public stadium discovery, tournament statistics, or subscription-plan visibility as part of this fix. No production changes.

Reference: https://supabase.com/docs/guides/database/database-linter?lint=0010_security_definer_view
