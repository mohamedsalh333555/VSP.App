# Team Skills phase finality — read-only staging provenance (18 Nov 2026)

Issue: [#45](https://github.com/mohamedsalh333555/VSP.App/issues/45). Target: **vsp-staging**, project ref `vtwgqyxglevcsxwdmhop`, not production.

## Evidence
- Supabase migration inventory currently records `team_skills_dynamic_phase_finality` with version **20261118153330** and `team_skills_server_finality_gates` with version **20261118154934**.
- Checked source files `20261118150000_team_skills_dynamic_phase_finality.sql` and `20261118151000_team_skills_server_finality_gates.sql` against the corresponding migration slug and the observed DB object behavior. Staging view `public.team_skills_leaderboard` is `security_invoker=true`, computes approval against the **number of configured cup phases**, and does not hardcode twelve.
- Staging definitions for `team_skills_set_status(uuid,text)`, `team_skills_generate_knockout(uuid)` and `team_skills_regenerate_knockout(uuid)` retain `SECURITY DEFINER`, an empty `search_path`, their `vsp_skills_private.is_admin()` check and dynamic `all_stages_approved` gate; bracket methods still serialize seeding via transaction-scoped advisory locks.
- No customer rows were queried or updated. No SQL or production deployment performed in this audit.

## Change
- Lineage manifest now uses these two **observed real versions**, never guessed local timestamps.
- Audit permits **only** the observed exact-slug form or the prior source-slug-plus-date form for migration names. Each name remains checked against its matching local file.

## Remaining release gates
Metadata presence **is not byte-for-byte SQL parity**. Keep release HOLD until staging multi-account authorization and result-finality tests, rollback rehearsal, production permission checks, and subsequent CI acceptance. Never infer production deployment from staging provenance.
