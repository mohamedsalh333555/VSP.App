# VSP — Team Profile opponent identity conflict gate (19 November 2026)

**Branch:** uxlp-44-implementation. **Draft PR:** #35.

Team Profile displays head-to-head aggregates from a scoped repository and a public-only opponent identity projection. The duplicate-row guard previously compared W/D/L totals, but chose the first opponent name and logo for duplicated rows with identical scores. It now also compares normalized opponent display identity (public name and logo URL) for the same opponent. Any disagreement hides that opponent and its aggregate, rather than silently choosing a first/last cache entry. Identical mirrored A/B results and identical public identities still display once.

Added widget regressions for contradictory identities in Arabic and English and for consistent mirrored duplicates without double-counting. No database write, match result change, ranking inference, personal info exposure, Home redesign or active 1v1 restoration. This is a scoped contribution to Team Profile integrity; 86.03 and cross-account/staging tasks remain open.

**Accounting remains 640 total / 346 accepted / 294 open until tests and complete task acceptance.**
