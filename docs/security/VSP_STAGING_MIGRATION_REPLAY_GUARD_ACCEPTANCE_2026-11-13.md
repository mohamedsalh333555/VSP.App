# 71.06 — Legacy migration replay guard: scoped acceptance

**Date:** 2026-11-13. **Scope:** checked-in legacy `scripts/apply_migration_runner.py`, not Supabase staging/production deployment.

## Observed problem and repair

The repository has several distinct SQL files with the same numeric migration prefix, and Staging already records hundreds of applied versions. A raw Management API `database/query` submission does not by itself guarantee migration-history bookkeeping, so replaying arbitrary files can silently diverge from the reviewed migration chain.

The legacy runner now **fails closed before any SQL submission** when:
- The target is not the exact Staging project, the ref confirmation differs, or explicit staging review/opt-in flags are absent.
- The file is missing, outside the direct migrations folder, a rollback file, or shares its numeric version with another forward file.
- Supabase's official **read-only** `GET /v1/projects/{ref}/database/migrations` history response is inaccessible, missing/empty/malformed, or reports that version as already applied.

The history endpoint and its response contract are documented at https://supabase.com/docs/reference/api/v1-list-migration-history. The runner never queries or modifies production and never reads a secret value in tests.

## Verification

- [Account SQL security contracts run 43469070268](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43469070268): success at source commit `c4a5b07296c964d26f4325a4121106f047d21797`.
- `test/tooling/test_migration_replay_guard.py` exercises unique/colliding versions, rollback/outside paths, project opt-in, a mocked **GET** to staging history, rejected previously-applied versions, malformed/empty/unauthorized-shaped history and input validation without outbound HTTP.
- No live migration execution, no production request, no booking/payment/profile changes.

## Important limitations

This is a **guard on one legacy runner**, not a complete migration framework. A preflight GET is not an atomic lock and cannot prove a version was applied when an older raw-SQL invocation failed to record it. Only a reviewed Supabase migration pipeline with reliable history tracking and isolated rebuild tests can settle the broader replay risk. Task **71.07** (clean database rebuild and safe comprehensive replay) remains OPEN. No staging/production migration was applied.

**Task 71.06 accepted only for this scoped legacy-runner prevention and isolated tests.**
