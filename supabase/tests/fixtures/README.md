# Account security dependency fixture

This is a metadata-only snapshot from staging on 2026-11-11. It is **not** a
full Supabase schema, a production migration, or proof that all migrations replay.
It contains 25 table shapes / 518 columns, eight dependency function definitions,
and all five current `public.users` policies. No customer rows or keys are included.

The source metadata is in `account_security_metadata_2026-11-11.json`. Exported
`pg_get_functiondef` statements have terminating semicolons added for execution.
Only ID primary keys and the users-to-auth deletion cascade are reproduced;
other foreign keys, indexes and unrelated triggers are intentionally outside
this contract fixture. The two user update guard bindings are loaded from the
real migration. New account RPCs and the client-role trigger are also loaded
from their real migration files, never substitute implementations.

`../account_security_manifest.json` lists five SQL suites. They inject JWT
claims to test native PostgreSQL authorization, not GoTrue token validation or
real OAuth sessions. Coverage is:

| Contract | Positive and negative coverage |
|---|---|
| Registration cancellation | Own incomplete account, missing/cross identity, null/completed state, debt, actual deletion |
| Conversation reads | Participant/replay/counter isolation, nonmember and impersonation denial |
| Profile provisioning | Verified Auth state, allowed roles, existing profile preservation, canonical trial policy, no direct INSERT/DELETE |
| Sensitive updates | Role/subscription/debt/lifecycle denial, allowed profile edit, recent-password claim |
| Profile RLS | Anonymous denial, player/owner isolation, own edit, identity reassignment, legitimate admin moderation |
| Client-role compatibility | Old player/owner INSERT remains possible under temporary legacy grants; privileged INSERT/direct role changes fail; signup role RPC works |

Five deliberate broken-guard controls must fail for their intended security
reason. Their DDL and account rows roll back; the baseline suites then run again.
The executable runner refuses a hosted target and refuses a nonempty database.
Do not run fixture installation against an existing development/staging database.

This establishes reusable account/RPC regression tests (80.01/02/03). Booking,
team invitations, notification isolation, storage, payment-provider callbacks,
all other table policies/RPCs and actual JWT/device concurrency still require
their independent tests. Adding this workflow does not configure GitHub branch
protection or replace the complete release gate.
