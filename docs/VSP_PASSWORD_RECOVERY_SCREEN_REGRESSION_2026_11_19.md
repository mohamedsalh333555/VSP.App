# Password reset screen: bounded Flutter regression suite (19 November 2026)

UI tests execute the real SetNewPasswordScreen with a fake AuthProvider and Supabase User models. Six new widget tests cover malformed and mismatched passwords without network calls, success with delayed logout of the correct account, in-flight account switch, switch after success before delayed logout, and generic Arabic exception copy.

These tests complement the five pure session-guard tests and existing password-reset email privacy tests. They do not send real emails or prove hosted Supabase delivery, JWT expiry or cross-account backend authorization. Acceptance 11.03 remains awaiting CI plus evidence review; no automatic increment to the task counter.

No changes to main, production, payments or provider configuration.
