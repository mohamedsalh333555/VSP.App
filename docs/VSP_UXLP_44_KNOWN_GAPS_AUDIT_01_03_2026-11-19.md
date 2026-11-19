# UXLP-44 — Known gap and conflict classification (01.03)

Scope: **source-level gap identification**, not full runtime UX acceptance.
References: [44-rule audit](UXLP_44_RULE_AUDIT.md), [screen register](UXLP_44_SCREEN_REGISTER.md), [execution gate](UXLP_44_EXECUTION_GATE.md).

The audit matrix contains **44 distinct ordered UX rules**, all with evidence. **39** are source reviewed but runtime pending; **5** need a product/server decision (25, 31, 38, 39, 41); **0** have a complete runtime pass. The screen register counts 338 unique paths; source inventory is not evidence of screen × state × language/device passes.

| Rule | Known gap / conflict | Next action |
|---|---|---|
| 25 Error prevention | Historically reported missing server match kickoff guard and active-league caller authorization | Revalidate on staging under separate users; specify server fix |
| 31 State-driven actions | Client-only result/kickoff restrictions need corresponding server enforcement | Add/test authoritative guard without trusting the UI |
| 38 Single source | Multi-team active-team selection has no finalized explicit policy | Approve selection/default behavior and verify account transitions |
| 39 Role relevance | Historical get_team_active_league SECURITY DEFINER review flagged caller authorization and returned captain phone | Reinspect current role grants/function; test cross-account before remediation |
| 41 Persistent communication | Refund notification retry after ledger persistence and retention/archive policy remain open | Agree policy, implement durable retry and test |

Other known pending gaps: Arabic/English UI and RTL, large text, safe area/keyboard, loading/error/empty states, motion preferences, private data, navigation, device runtime. None is represented as a PASS.

Acceptance boundary: **01.03** identifies and documents known source gaps and decisions with a reproducible matrix check. It does not complete **01.01, 01.02, 01.04, 01.05 or 01.06**, does not prove an exhaustive per-screen review, and does not establish that older security findings are still present today.

Reproduction: `node --test scripts/test_uxlp_gap_matrix.cjs`, with GitHub Actions workflow `VSP UXLP 44 Gap Inventory`. No Supabase, payment or production changes.
