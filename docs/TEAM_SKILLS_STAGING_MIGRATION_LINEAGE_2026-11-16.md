# VSP Team Skills Cup — Staging migration lineage (16 November 2026)

**Source:** GitHub `uxlp-44-implementation` migration paths compared with the
actual `vsp-staging` Supabase migration registry. This is a **read-only
audit record**, not permission to alter either migration history or production.

**Important:** Connector-assisted staging applications receive independent
server-generated version IDs, not the source filename timestamps. The name
mapping below establishes **which named migration was recorded**; it does
*not* prove byte-for-byte SQL equality or authorize blindly marking any
migration as applied.

| Source migration file | Staging applied migration version |
|---|---|
| `supabase/migrations/20261116030000_team_skills_cup_foundation.sql` | `20261116024322` |
| `supabase/migrations/20261116040000_team_skills_cup_officials_and_awards.sql` | `20261116025208` |
| `supabase/migrations/20261116050000_team_skills_cup_role_and_configuration.sql` | `20261116025638` |
| `supabase/migrations/20261116060000_team_skills_award_history_notifications.sql` | `20261116025950` |
| `supabase/migrations/20261116070000_team_skills_hospitality_checkin.sql` | `20261116030204` |
| `supabase/migrations/20261116080000_team_skills_fix_scoped_rls_policies.sql` | `20261116042820` |
| `supabase/migrations/20261116081000_team_skills_review_capacity_guard.sql` | `20261116043118` |
| `supabase/migrations/20261116082000_team_skills_knockout_future_round_slots.sql` | `20261116044654` |
| `supabase/migrations/20261116083000_team_skills_goalkeeper_award_tie_guard.sql` | `20261116045239` |
| `supabase/migrations/20261116084000_team_skills_final_seeding_freeze.sql` | `20261116072405` |
| `supabase/migrations/20261116085000_team_skills_registration_status_notifications.sql` | `20261116073010` |
| `supabase/migrations/20261116086000_team_skills_blocked_official_guard.sql` | `20261116073613` |
| `supabase/migrations/20261116087000_team_skills_revoke_official.sql` | `20261116091115` |
| `supabase/migrations/20261116088000_team_skills_closed_event_write_guards.sql` | `20261116091810` |
| `supabase/migrations/20261116089000_team_skills_blocked_official_read_rls.sql` | `20261116132346` |
| `supabase/migrations/20261116090000_team_skills_checkin_hospitality_guard.sql` | `20261116133438` |
| `supabase/migrations/20261116091000_team_skills_checkin_closed_status_first.sql` | `20261116134235` |
| `supabase/migrations/20261116092000_team_skills_keeper_station_team_conflicts.sql` | `20261116134643` |
| `supabase/migrations/20261116093000_team_skills_automatic_waitlist_registration.sql` | `20261116140001` |
| `supabase/migrations/20261116094000_team_skills_waitlist_promotion_capacity.sql` | `20261116140149` |
| `supabase/migrations/20261116095000_team_skills_registration_receipt_notification.sql` | `20261116143324` |
| `supabase/migrations/20261116096000_team_skills_hospitality_approved_only.sql` | `20261116143929` |
| `supabase/migrations/20261116097000_team_skills_views_select_only.sql` | `20261116144238` |
| `supabase/migrations/20261116098000_team_skills_champion_finality.sql` | `20261116145347` |
| `supabase/migrations/20261116099000_team_skills_champion_finality_uuid_fix.sql` | `20261116145900` |
| `supabase/migrations/20261116100000_team_skills_registration_withdrawal.sql` | `20261116162452` |
| `supabase/migrations/20261116101000_team_skills_captain_pending_withdrawal.sql` | `20261116151313` |
| `supabase/migrations/20261116102000_team_skills_waitlist_review_capacity.sql` | `20261116162920` |
| `supabase/migrations/20261116163000_team_skills_notifications_realtime_staging.sql` | `20261116150557` |
| `supabase/migrations/20261116164000_team_skills_blocked_captain_roster_guard.sql` | `20261116151450` |

## Release gate / no-go criteria

1. **Stop any blind `supabase db push`.** The source file timestamps do not
   match the versions already registered on Staging. Without reconciliation
   the CLI could attempt to apply existing operations again.
2. Before adopting these migrations for a target environment, compare the
   source migration SQL against the *actual database schema and function
   definitions*, policies, trigger definitions, dependencies and grants.
   The staging history has names/versions but no SQL-content checksums in
   this record. Source files may have been updated after their first staging
   application.
3. Use a separate, reviewed deployment plan for production; never copy
   staging migration history entries into production and never manually
   change `supabase_migrations.schema_migrations` to silence a mismatch.
4. Re-run isolated security CI and **real role-separated staging E2E**:
   captain, team member, assigned judge, revoked judge, event organizer and
   admin. Verify approvals, cash hospitality, 12 stage scores, bracket,
   goalkeeper trials, announcement/history, notification delivery and
   unauthorized requests before production promotion.
5. Protect the owner subscription-only business model. Team Skills cash
   hospitality is not a commission on stadium bookings; no live charges
   have been authorized or tested as part of this record.

**Observed count:** 30 named Team Skills Cup migrations applied on
Staging at time of audit; `main` and Production are unchanged by this file.
