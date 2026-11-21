# VSP — published cup consistency and repeat-booking authorization UI
19 November 2026. Branch: `uxlp-44-implementation`, Draft PR #35.

## Changes
- Team Skills Cup discovery continues to fail closed on contradictory same-ID public records. In addition to status, price, schedule, stadium and capacity, it now compares published image URLs and nested prize lists. Equivalent nested JSON with reordered object keys is accepted. Conflicting prices or awards never arbitrarily take the first paginated row.
- The existing "Book again" client action is disabled in the initial UI for a non-owner session and a missing venue ID, rather than looking clickable and silently returning. Server refresh and checks before and after await remain unchanged, and no old date/price/payment is re-used.
- Added one nested public prize consistency regression test and three booking UI tests (Arabic/English switched accounts, missing venue ID).

## Verification & accounting
Scoped Flutter CI and full Flutter CI must pass on the final head before calling the changes verified. This is partial work under 86.05 and 86.06; neither task is accepted until current backend authorization, Admin/Website publication parity, real-slot/price/deposit confirmation and staging two-account acceptance. Current ledger remains **640 total / 343 accepted / 297 open**. No main merge, new charge, payment-system write, Supabase migration, production deploy, APK or Home redesign.
