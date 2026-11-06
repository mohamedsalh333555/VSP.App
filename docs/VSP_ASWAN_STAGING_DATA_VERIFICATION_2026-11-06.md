# VSP staging demo-data verification — 2026-11-06

Repository: `mohamedsalh333555/VSP.App`  
Branch: `uxlp-44-implementation`  
Database inspected: `vsp-staging` (`vtwgqyxglevcsxwdmhop`)

## Read-only verified facts

| Item | Verified |
|---|---:|
| Demo player accounts (`users.role='player'`) | 100 |
| Demo owner accounts | 10 |
| Demo stadiums | 15 |
| Demo teams | 10 |
| Demo team memberships | 100 |
| Demo teams with nonzero `matches_played` | 10 |
| Demo stadiums with matching owner records | 15 |
| Players attached to Aswan 1v1 draft | 16 |

All 110 demo user records, all 15 demo stadium records and all 10 demo team records have governorate `Aswan`. The tournament `[DEMO/STAGING] بطولة أسوان 1 ضد 1` is in `draft` state, with target count 16 and 16 participant rows.

These counts are from read-only SQL and do not prove that demo accounts can authenticate, that standings are mathematically consistent, that 1v1 bracket fixtures exist, or that the published application displays staging data.

## Follow-up acceptance gates

1. Inspect application environment selection and deployed web/mobile configuration. Never repoint a production deployment to staging or copy demo identities into production without separate explicit approval.
2. Verify list queries and UI visibility for players, owners, stadiums, teams, league standings and draft 1v1 tournaments; document role-specific access/RLS and publication filters.
3. Validate fixture/result integrity and recompute expected team standings independently before modifying results.
4. Test player-to-team, owner-to-stadium and tournament-to-player journeys on staging with authenticated test accounts.
5. Resolve PR #35 base conflicts safely, run current-head Flutter CI and E2E, address remaining failed/blocked journeys, and prepare rollback evidence before any merge/release.

## Safety

No schema/data writes or production changes were made as part of this verification. The existing UXLP-44 release gates remain in force. This document records verified staging state, not completion of final QA.

## Application connection diagnosis — verified 2026-11-06

The Flutter entrypoint `lib/main.dart` initializes Supabase using `AppEnv.supabaseUrl` and `AppEnv.supabaseAnonKey`. The `lib/core/config/app_env.dart` compile-time defaults point to the main VSP Supabase project (`mktqkddbcddrxjxabdua`), **not** staging (`vtwgqyxglevcsxwdmhop`). Thus a build without `--dart-define` overrides cannot show the staging-only Aswan demo records. This is a code-level finding, not evidence of which build is deployed.

For a separately identified test build, pass the staging URL and the corresponding **staging publishable key** as build-time defines, e.g.:

```bash
flutter run --dart-define=SUPABASE_URL=https://vtwgqyxglevcsxwdmhop.supabase.co --dart-define=SUPABASE_ANON_KEY=<STAGING_PUBLISHABLE_KEY>
```

The placeholder must be replaced locally from the staging project's publishable keys; never use a service-role/secret key or publish a private credential. Verify build configuration and test account scope before running. Do not change production defaults, deploy the test build as production, or merge this branch on the strength of the demo-data check.

Next: confirm actual deployed build configuration, then inspect application visibility rules and RLS with staging test accounts.
