# VSP — password reset session-switch safety (2026-11-19)

During password reset, the screen waited 1200ms after success, then called signOut without verifying the recovery account still owned the session. Signing into a second account in that delay could sign out the second account.

Now the original recovery session ID is checked after the password update and again after the success delay immediately before signOut. Account mismatch or provider disposal fails closed; any stale password fields and success state are cleared, and bilingual copy asks for a new recovery link.

Five focused guard tests check the original user, delayed account switch, logout, disposed provider, and empty ID. The Recovery Privacy workflow runs these tests and analyzes the updated screen.

Scope: client safety only, no real Supabase/JWT/reset-link E2E. Original tasks 11.03/11.05 and real multi-account checks remain open. Counter 640 total, 343 accepted, 297 open. No main merge, production writes or payment work.
