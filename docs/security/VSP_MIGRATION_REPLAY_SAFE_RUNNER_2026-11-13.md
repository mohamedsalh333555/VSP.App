# VSP — legacy migration script accidental production/replay protection

2026-11-13, source-only development branch. No database connection or migration invocation was performed in preparing the patch.

The old \`scripts/apply_migration_runner.py\` directly used a fixed production project ref and read \`env.json\`. It accepted arbitrary paths and applied SQL over Management API without checking the selected file version against the migration directory. The repository contains multiple distinct forward migrations with colliding numeric version prefixes; blindly applying one can corrupt migration ordering and alter payment/auth logic.

The replacement refuses production, accepts only the exact staging project with **two independent explicit opt-ins** (\`VSP_ALLOW_STAGING_MIGRATION=1\` and \`VSP_APPROVED_MIGRATION_REVIEW=1\`), requires the exact staged project ref as both target and confirmation, and rejects any migration outside the canonical directory, rollback/unversioned file or version with another forward file sharing the same numeric prefix. It does not log a credential, SQL error body, or sensitive data. No action occurs on Python import.

\`test/tooling/test_migration_replay_guard.py\` provides isolated, filesystem-only positive/negative test fixtures for collisions, rollback scripts, wrong directory, production targets and missing approval. Account SQL CI runs it before further checks. The guard prevents **this one legacy script** from accidental production/replay use; it does not prove every other script or CI pipeline is safe and does not authorize running staging migrations. Task 71.06 stays pending CI review.
