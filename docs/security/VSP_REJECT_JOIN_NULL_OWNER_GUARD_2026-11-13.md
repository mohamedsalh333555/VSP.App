# VSP legacy join rejection: NULL-safe owner authorization

2026-11-13 read-only Staging function inspection found `reject_join_request(text,text)` has the same NULL-unsafe `auth.uid() != creator AND auth.uid() != owner` check as its companion acceptance RPC. When a booking has no owner ID, an otherwise unauthorized actor can pass a conditional that evaluates to NULL. A SECURITY DEFINER function then removes a pending user ID without proving ownership. No actual staging booking/request was inspected or mutated.

A branch-only **unapplied** migration replaces the comparison with NULL-safe `IS DISTINCT FROM`, validates UUID identifiers, locks the booking row, and treats repeated authorized rejection as an idempotent no-op. A dedicated local SQL contract compares the original deployed definition (must fail on unauthorized NULL-owner negative control) with the candidate (must pass unauthorized, legitimate, repeat, bad ID and missing-JWT checks). The ephemeral DB is created and dropped on the isolated CI Postgres host and never calls Supabase or Paymob.

The matching acceptance fix is tracked in [Issue #40](https://github.com/mohamedsalh333555/VSP.App/issues/40). Do not deploy either change until Staging producer/consumer and owner/participant role tests pass. No production or `main` changes.
