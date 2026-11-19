# VSP — Retirement of legacy standalone 1v1 tasks 43.01–43.08

**Date:** 19 November 2026. **Type:** Product-scope cancellation, not task completion. **Branch:** `uxlp-44-implementation`. **PR:** #35 (Draft).

## Product decision

VSP replaced the **standalone 1v1 competition** with **VSP Team Skills Cup**. Therefore the old competition's eight open tasks 43.01–43.08 (create/register/check eligibility/schedule/record result/advance/rank/deduplicate the legacy standalone event) should not remain as pending work. They are marked **RETIRED**, not ACCEPTED, and are preserved in the plan and original breakdown as visibly struck-through archive rows with stable IDs. No implementation of these retired flows is claimed.

## Intentionally preserved

- Historical 1v1 records, awards, existing player/team historic trophy badges, and all financial and accounting obligations (including old refunds and audit records).
- The **within-Team Skills Cup 1v1 final stage** remains a valid drill, *not* a revival of the retired standalone tournament.
- Team Skills Cup registration, captain rosters, administration-only final scores, approvals and prizes stay covered by their independent active tasks (38–42, 44, 47, 81 and 86.04/86.05), along with separate legacy migration integrity items in groups 61 and 69.
- No SQL, database, Supabase, Paymob, historical data, production app, deploy, APK or main-branch change.

## Accounting contract

| Measure | Before | After |
|---|---:|---:|
| Historical unique IDs (633 legacy + 7 Phase 10) | 640 | 640 |
| Retired in historic inventory | 0 | **8** |
| Active | 640 | **632** |
| Accepted | 346 | **346** |
| Open | 294 | **286** |
| Accepted/active | 54.06% | **54.75%** |

The eight cancelled IDs are neither accepted nor open; old dated progress entries remain unchanged. `scripts/verify_task_accounting.py` checks both active sets and exact archived IDs and the CI workflow runs it. The latest pre-scope source and Flutter CI were green: [Flutter CI success](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44543616228).

## Outstanding acceptance

The entire remaining active scope is **not** complete. The 286 open items still include real staging JWT/RLS, two-account scenarios, actual booking race and payment sandbox verification, cross-platform Team Skills consistency and Android tests. These cannot be represented as completed without the corresponding independent evidence.
