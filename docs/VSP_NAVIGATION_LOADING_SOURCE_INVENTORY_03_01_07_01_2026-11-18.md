# VSP — Loading state and navigation route inventory

**18 November 2026 · Read-only source inventory · `uxlp-44-implementation`**

**Exact source SHA:** [a1f024df](https://github.com/mohamedsalh333555/VSP.App/commit/a1f024df504b13f0c7e55ed14d73f8df9cc4cc3b).
**Test evidence:** [VSP Navigation and Loading Source Inventory — SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44197447172); Node test fixtures verify literal GoRouter paths, push/pop calls, auth guards, loading/error/empty/retry occurrences, deterministic coverage and exclusion of generated files. Full Markdown/JSON inventory is attached to that GitHub Actions run for 14 days.

## 03.01 — Inventory loading states across the Flutter source

The source scan covers **556 non-generated Dart files** under `lib/`:

| Relevant code signature | Matches | Source files |
| --- | ---: | ---: |
| `VSPUiState.loading` and progress indicators | 132 | 95 |
| `FutureBuilder` / `StreamBuilder` constructors | 12 | 12 |
| `VSPUiState.error` / `VSPErrorState` | 43 | 30 |
| `VSPUiState.empty` / `VSPEmptyState` | 31 | 17 |
| `onRetry:` / `forceRefresh:` actions | 66 | 35 |

The generated report records source file/line examples for each family. This completes a **reproducible source inventory** of loading patterns and adjacent failure/empty/retry entry points. It does **not** prove correct loading in every screen, nor offline recovery, long-running requests, retry authorization or actual server outcomes. Tasks 03.02–03.07 stay open.

## 07.01 — Inventory of navigation paths and entry points

There are **27 literal GoRouter route declarations** in `lib/core/navigation/app_router.dart`:

- **Authentication and role selection (12):** `/splash`, `/welcome`, `/login`, `/create-account-player`, `/create-account-owner`, `/signup-player`, `/signup-owner`, `/onboarding-player`, `/onboarding-owner`, `/verify-email`, `/set-new-password`, `/select-role`.
- **Owner and administration-related (5):** `/owner`, `/facility-onboarding`, `/documentation`, `/copilot`, `/copilot-playground`.
- **Player-facing (7):** `/player`, `/collective/:inviteToken`, `/match/:bookingId`, `/team/:teamId`, `/championship/:championshipId`, `/edit-profile`, `/notifications`.
- **App/system (3):** `/`, `/offline`, `/suspended`.

The inventory also found **108 forward navigation call sites across 56 files**, **292 return/back references across 113 files**, and **192 role/auth/redirect guard references across 43 files**. These are source occurrences, **not 108 unique user journeys or 192 verified security checks**. Navigation implemented through imperative `Navigator` calls may not be a named GoRouter route, and computed paths cannot be completely enumerated statically.

This accepts **07.01 as path inventory only**, not 07.02–07.07 back-button, deep-link routing, role enforcement, logout navigation or notification deep-link tests.

## Accounting and safety

Two pre-existing inventory tasks accepted, no new task IDs. **633 unique / 298 accepted / 335 open (47.08%)**. No RLS, payment, database, production, app store or `main` changes.
