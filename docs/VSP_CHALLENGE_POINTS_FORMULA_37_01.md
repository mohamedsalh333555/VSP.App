# 37.01 — Challenge points formula and processing conditions

**Verified in checked-in SQL source:** `supabase/migrations/20261003193000_challenge_mutual_result_agreement_and_points.sql`, function `public.calculate_elo_on_match_completion()`.

## Scoring matrix

| Confirmed final outcome | Home team | Away team |
|---|---:|---:|
| `homeWin` | 3 points, 1 win | 0 points, 1 loss |
| `awayWin` | 0 points, 1 loss | 3 points, 1 win |
| `draw` | 1 point, 1 draw | 1 point, 1 draw |

**Equation:** team points = `3 × wins + 1 × draws + 0 × losses`. Each finalized challenge increments `matches_played` for both teams once. The source trigger only processes records where `booking_type='challenge'`, `match_result_status='confirmed'`, `final_outcome IS NOT NULL` and `elo_processed=false`. After updating both teams, it sets `elo_processed=true` to prevent ordinary repeated processing.

## Important limitations

- Despite its function name, this source implements **competition points**, not an ELO rating calculation.
- This rule is explicitly for confirmed **challenge** matches. Do not assume private tournaments, 1v1 competitions or team leagues share its scoring/tie-break rules.
- A later result correction or reversal must explicitly reconcile previous points and statistics; the one-time `elo_processed` flag alone does not prove corrections are safe.
- Source inspection does not verify the function is currently deployed or that all triggers, permission checks and result-approval paths are correctly configured.
- Tie-break ordering is **not** defined by this function. Task 37.04 remains open.

**37.01 closed:** documented the exact source formula, eligibility, one-time processing guard and scope. Tasks 37.02–37.07 remain open pending live results, recalculation and correction tests.
