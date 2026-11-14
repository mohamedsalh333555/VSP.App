# VSP — Batch implementation and final verification policy

Effective 2026-11-07. Applies to branch `uxlp-44-implementation`; no merge to `main` without owner approval.

## Two independent queues
1. **Core scope**: 620 defined subtasks in `VSP_80_DETAILED_SUBTASK_BREAKDOWN.md`. Scope count remains fixed unless requirements change. Track each as `not_started`, `implemented_pending_verification`, or `verified_passed`. Implementation is counted as implementation progress, not test success.
2. **Defect remediation**: independent issue register `VSP_FINAL_VERIFICATION_DEFECTS.md`. Defects found during final verification get IDs `BUG-001`, severity, reproduction, owner, root cause, fix commit, and retest status. Do not add defects to the 620 core scope or quietly declare them fixed.

## Owner execution directive — 2026-11-10

- Implement **all 620 subtasks without exception** on `uxlp-44-implementation` and PR #35.
- Deferring tests means deferring the consolidated verification run only; it does not pause or remove any implementation task.
- Continue autonomously in large batches. Keep `implemented_pending_verification`, `verified_passed`, and remaining counts separate.
- Do not build an APK or merge `main` before the final review gate.

## Execution approach
- Implement related tasks in coherent batches; minimize waiting for per-commit CI and Android smoke results.
- Keep automated CI available, but do not block the next unrelated implementation batch merely to poll it.
- At the end of each batch record implementation status, modified files, commit references, known limitations and dependencies.
- Final verification phase runs Flutter analyze/tests, Android E2E, two-account staging journeys, permissions, payments, and security checks; classify pass/fail and create defects for every failure.
- **Safety exceptions**: before risky schema changes, destructive migrations, auth/RLS changes, money movement, or production operations, require targeted checks and explicit safe rollout. Do not postpone those safety gates.
- Never mark a feature verified based on source review alone; never treat cancelled or pending CI as passed.
- Existing checked boxes in the 620-task list represent prior evidence; going forward keep separate implementation and verification counters in the progress ledger.
