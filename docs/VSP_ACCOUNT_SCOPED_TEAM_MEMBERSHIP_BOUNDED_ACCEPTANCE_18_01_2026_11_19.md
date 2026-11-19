# VSP — 18.01 account-scoped team memberships (bounded acceptance)

**19 November 2026. Scope: Flutter TeamRepository + isolated PostgREST HTTP fixtures.**

## Verification

- [VSP Account Scoped Team Membership Lookup CI: SUCCESS, **5 tests passed**](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44488718345), on SHA c18d04fc46bf7ff155cbeb00463554fef8fbd3e7, including Flutter Analyze.
- `TeamRepository.getUserTeamsStrict(userId)` calls `getUserTeamIdsStrict(userId)`, whose `team_members` lookup explicitly filters `user_id`, then reads matching `teams_public` records and sorts by human-readable name and ID. The saved local active-team preference is checked against actual fetched memberships, never treated as an access credential.
- Unit tests with a synthetic SupabaseClient and MockClient cover: two memberships in reverse response order + saved team restore, zero membership without an unnecessary team query, two distinct queried user identities with separate results, a 503 membership query error that propagates instead of becoming verified empty, and duplicate membership rows deduplicating to one displayed team.

## Limits / other open tasks

- These fixtures assert query shape and client behavior, **not** effective server RLS or a live cross-account privacy test. Actual Supabase login, auth identity verification, permission boundaries, privately scoped roster access, deleted membership, Android and device persistence remain open in 17.07, 59, 79, SEC-02 and related task groups.
- Only original task 18.01 changes OPEN→ACCEPTED. Task IDs and total remain unchanged. No database writes, payment operations, deployment or main merge.

**Accounting: 640 total / 346 accepted / 294 open (54.06%).**
