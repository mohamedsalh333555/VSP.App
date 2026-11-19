# Staging caller guard hardening: player bookings, chat, owner match extension

2026-11-07 | Staging `vtwgqyxglevcsxwdmhop` | Tracker #77 | Issue #38

Applied Supabase migration `secure_player_bookings_chat_and_owner_extension_caller_guards` to three SECURITY DEFINER RPCs:

- `get_player_my_bookings_atomic(uuid)` — replaced 2 `current_user` bypasses with JWT `auth.role()` service-role checks.
- `increment_chat_unread_count(text,text,text)` — replaced 3 caller bypasses (login, sender impersonation, booking participant) with JWT service-role checks.
- `owner_extend_match_atomic(uuid,integer)` — replaced 2 bypasses (login and owner check) with JWT service-role checks.

Negative tests: `BEGIN; SET LOCAL ROLE authenticated;` with no JWT, followed by a rolled-back call. Player bookings and chat raised SQLSTATE 42501 `Authentication required`; owner extension returned `success:false,error:unauthorized`. No persistent test changes.

Total targeted caller guard fixes now **20 functions**. Real JWT positive/negative cross-account tests, further RPC inventory and business E2E remain outstanding. Production and `main` unchanged. Do not close #77 yet.
