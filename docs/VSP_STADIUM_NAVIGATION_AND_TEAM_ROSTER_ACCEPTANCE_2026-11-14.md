# Stadium details route and team roster privacy — 14.06, 15.04

## 14.06: list to details

`AllStadiumsScreen` now accepts an optional details builder for a network-free widget test. The production default still builds `StadiumDetailsScreen`. The test completes a synthetic Cairo page with one stadium, taps its card and verifies the detail route receives that stadium ID. The existing empty/error/partial-data tests run alongside it in [Flutter CI 43642905483](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43642905483). It proves the list transition and selected argument, not a live venue refresh, booking or device navigation.

## 15.04: member-only private roster

Read-only inspection of staging's `get_team_member_profiles(uuid)` found it ordered rows by `team_members.id`, which does not exist in the three-column staging membership table (`team_id`, `user_id`, `joined_at`). Before the repair, a role-scoped outsider call returned zero rows, while a member call failed. The new forward migration preserves the caller/member/captain/admin guard and `anon` revocation, ordering by `joined_at NULLS LAST, user_id`.

The migration was tested first in a disposable local PostgreSQL database. Its contract checks member/admin read, outsider/unauthenticated denial, anonymous EXECUTE revocation and deterministic order. [Account SQL CI 43642533456](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43642533456) ran the contract. Supabase applied it to **staging only**, recording version `20261114212217` and name `fix_team_roster_order`; the checked-in filename now matches this version. Subsequent `BEGIN READ ONLY`/`ROLLBACK` tests with SQL role and claim simulation returned **10** roster rows to a team member, **0** to a different player and `anon EXECUTE=false`. No names, phones or identifiers were returned in the test output.

This is the roster RPC boundary in staging. Real JWT/device journeys, public profile/storage checks, the rest of team discovery and production deployment remain open.
