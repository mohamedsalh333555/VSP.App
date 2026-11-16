# Team Skills Cup — Staging rollout gates and migration reconciliation

**Target:** VSP.App `uxlp-44-implementation` + `vsp-admin-panel/feat/team-skills-cup`.
**Status:** development/staging only. Neither branch is merged to `main`.

## 1. Explicit build-time project identity

Both applications keep the Team Skills feature **off by default**. The project
identity is necessary in addition to the feature flag; the backend still
validates all player/admin/judge permissions using Supabase Auth + PostgreSQL RLS.

Flutter staging build requires all four compile-time defines:

```sh
--dart-define=VSP_ENABLE_TEAM_SKILLS_CUP=true
--dart-define=VSP_TEAM_SKILLS_ALLOWED_PROJECT_REF=vtwgqyxglevcsxwdmhop
--dart-define=SUPABASE_URL=https://vtwgqyxglevcsxwdmhop.supabase.co
--dart-define=SUPABASE_ANON_KEY=<STAGING_PUBLISHABLE_KEY>
```

In the separate Vite Admin staging deployment:

```env
VITE_ENABLE_TEAM_SKILLS_CUP=true
VITE_TEAM_SKILLS_ALLOWED_PROJECT_REF=vtwgqyxglevcsxwdmhop
VITE_SUPABASE_URL=https://vtwgqyxglevcsxwdmhop.supabase.co
VITE_SUPABASE_ANON_KEY=<STAGING_PUBLISHABLE_KEY>
VITE_ADMIN_OAUTH_REDIRECT_URL=https://<AUTHORIZED_STAGING_ADMIN_DOMAIN>/
```

The staging publishable key is obtained from the actual staging project
settings; never use the production fallback key, a `service_role` key or an
`sb_secret_...` browser key. The OAuth redirect must be allowlisted under the
**same staging Supabase Auth** project and configured in the deployment. Do not
test judges against the production admin deployment.

Production rollout is **not** implied by these examples: production approval
requires all security/E2E gates to pass, production migrations and a
separately reviewed deployment configuration.

## 2. Database checks needed before release

- Verify all Team Skills migrations exist on the target database, that all
  `public.team_skills_*` tables have RLS enabled, and that all definer RPCs
  have correct `EXECUTE` grants and non-exposed helper functions.
- Migration filenames in GitHub use `20261116030000...` etc., whereas
  MCP-applied staging migrations carry separate generated timestamp IDs
  (`20261116024322...` etc.). **Do not run a blind `supabase db push` and do
  not edit `supabase_migrations.schema_migrations` manually.** First create a
  reviewed, version-and-content-aware reconciliation/rollout plan.
- Database integration already exercised role-claim transactions with
  `ROLLBACK`, not independent browser/mobile OAuth JWTs. Test captain,
  non-captain team member, assigned judge, organizer, admin, outsider and
  revoked/blocked judge in actual separate staging sessions.
- Final seeding requires all 12 stages approved for every approved team;
  score updates must be frozen after a bracket exists. Tied skills totals
  and tied goalkeeper save metrics must not silently produce winners.
- Notification database rows (captain approval/rejection/waitlist and official
  awards) are implemented; real FCM push and end-user delivery are not
  automatically established by this work.
- Team Skills Cup hospitality is an audited in-person/admin confirmation,
  not a per-booking commission or an untested online payment integration.

## 3. Evidence and no-release rules

- Full staged four-team SQL workflow reached skills, goalkeeper trials,
  knockout and awards with data rolled back.
- Local SQL CI covers cross-cup RLS, race for the last team slot, 12 approved
  stages, tied goalkeepers, blocked judges and review notifications.
- Flutter displays only `approved` stage scores; pending measurements belong
  to the official and admin workflow.
- The legacy individual 1v1 history is retained, becoming read-only in the
  Admin UI when Team Skills is explicitly enabled.
- Do not merge to either main branch or deploy to production until all
  release-critical issues and real cross-device user journeys have passed.

## 4. Release checklist (manual acceptance)

- [ ] Correct isolated staging URL, publishable key and OAuth redirect verified
- [ ] Player captain selects five (including canonical captain if needed)
- [ ] Non-captain cannot create or modify a registration
- [ ] Admin approves/rejects; captain receives the correct in-app status
- [ ] Unassigned/blocked judges and organizers cannot submit measurements
- [ ] Assigned judge records; only admin approves; player sees only approved
- [ ] All 12 stages approved before final seeding; 4–8 teams and byes verified
- [ ] Awards/notifications/standings consistent between Flutter and Admin
- [ ] Weak-network, double-submit, account-switch and permission revocation tested
- [ ] Database migration lineage reconciled and staging rollback tested
- [ ] Production security review and store approval blockers resolved
