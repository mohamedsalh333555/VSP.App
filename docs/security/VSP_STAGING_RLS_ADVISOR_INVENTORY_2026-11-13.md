# VSP staging — current RLS advisor findings (read-only)

Audit: 2026-11-13 UTC. Project: `vsp-staging` only. Sources: Supabase Performance/Security Advisors. Historic counts are not current findings. All advisory items are **signals for review**, not proofs of exploitable authorization flaws.

## auth_rls_initplan: 44 findings

Official remediation: https://supabase.com/docs/guides/database/database-linter?lint=0003_auth_rls_initplan

### bookings — 5

- Table \`public.bookings\` has a row level security policy \`Admins full access\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.
- Table \`public.bookings\` has a row level security policy \`bookings_delete_secure\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.
- Table \`public.bookings\` has a row level security policy \`bookings_insert_admin_service\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.
- Table \`public.bookings\` has a row level security policy \`bookings_select_private_scope\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.
- Table \`public.bookings\` has a row level security policy \`bookings_update_secure\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.

### cancellation_refund_queue — 1

- Table \`public.cancellation_refund_queue\` has a row level security policy \`admins_view_booking_refund_queue\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.

### challenge_results — 1

- Table \`public.challenge_results\` has a row level security policy \`admins_view_challenge_results\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.

### championship_registrations — 1

- Table \`public.championship_registrations\` has a row level security policy \`championship_registrations_select\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.

### championship_roster_players — 1

- Table \`public.championship_roster_players\` has a row level security policy \`roster_players_manage_policy\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.

### championship_rosters — 1

- Table \`public.championship_rosters\` has a row level security policy \`championship_rosters_manage_secure\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.

### chat_messages — 1

- Table \`public.chat_messages\` has a row level security policy \`chat_messages_update\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.

### conversations — 2

- Table \`public.conversations\` has a row level security policy \`conversations_delete_participant\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.
- Table \`public.conversations\` has a row level security policy \`conversations_select_unified\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.

### court_operating_hours — 1

- Table \`public.court_operating_hours\` has a row level security policy \`owner_can_manage_hours\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.

### financial_audit_logs — 1

- Table \`public.financial_audit_logs\` has a row level security policy \`financial_logs_admin_all\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.

### league_settings — 1

- Table \`public.league_settings\` has a row level security policy \`Allow admins to manage league_settings\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.

### match_score_edits — 2

- Table \`public.match_score_edits\` has a row level security policy \`owner_can_insert_edits\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.
- Table \`public.match_score_edits\` has a row level security policy \`owner_can_read_own_edits\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.

### notifications — 3

- Table \`public.notifications\` has a row level security policy \`notifications_delete_owner\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.
- Table \`public.notifications\` has a row level security policy \`notifications_select_owner\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.
- Table \`public.notifications\` has a row level security policy \`notifications_update_owner\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.

### owner_subscription_orders — 1

- Table \`public.owner_subscription_orders\` has a row level security policy \`owner_subscription_orders_select_own\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.

### payout_settlements — 1

- Table \`public.payout_settlements\` has a row level security policy \`payout_settlements_select_owner_or_admin\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.

### promotions — 1

- Table \`public.promotions\` has a row level security policy \`promotions_admin_manage\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.

### reports — 2

- Table \`public.reports\` has a row level security policy \`reports_admin_delete\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.
- Table \`public.reports\` has a row level security policy \`reports_admin_select\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.

### stadium_custom_rates — 1

- Table \`public.stadium_custom_rates\` has a row level security policy \`stadium_custom_rates_manage_own\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.

### stadiums — 1

- Table \`public.stadiums\` has a row level security policy \`stadiums_admin_manage_all\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.

### support_ticket_messages — 3

- Table \`public.support_ticket_messages\` has a row level security policy \`support_ticket_messages_staff_insert\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.
- Table \`public.support_ticket_messages\` has a row level security policy \`support_ticket_messages_staff_select\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.
- Table \`public.support_ticket_messages\` has a row level security policy \`support_ticket_messages_user_select\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.

### support_tickets — 3

- Table \`public.support_tickets\` has a row level security policy \`support_tickets_staff_select\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.
- Table \`public.support_tickets\` has a row level security policy \`support_tickets_staff_update\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.
- Table \`public.support_tickets\` has a row level security policy \`support_tickets_user_select\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.

### system_audit_logs — 1

- Table \`public.system_audit_logs\` has a row level security policy \`Admins can view audit logs\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.

### team_league_cancellation_refund_queue — 1

- Table \`public.team_league_cancellation_refund_queue\` has a row level security policy \`admins_view_league_refund_queue\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.

### team_league_payments — 1

- Table \`public.team_league_payments\` has a row level security policy \`users_view_own_team_league_payments\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.

### teams — 1

- Table \`public.teams\` has a row level security policy \`teams_select\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.

### transactions — 3

- Table \`public.transactions\` has a row level security policy \`transactions_admin_select\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.
- Table \`public.transactions\` has a row level security policy \`transactions_insert_admin_service\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.
- Table \`public.transactions\` has a row level security policy \`transactions_select_owner_or_admin\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.

### users — 2

- Table \`public.users\` has a row level security policy \`users_insert_policy\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.
- Table \`public.users\` has a row level security policy \`users_select_policy\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.

### vsp_1v1_cancellation_refund_queue — 1

- Table \`public.vsp_1v1_cancellation_refund_queue\` has a row level security policy \`admins_view_1v1_refund_queue\` that re-evaluates current_setting() or auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.

## multiple_permissive_policies: 50 findings

Official remediation: https://supabase.com/docs/guides/database/database-linter?lint=0006_multiple_permissive_policies

### app_config — 1

- Table \`public.app_config\` has multiple permissive policies for role \`authenticated\` for action \`SELECT\`. Policies include \`{admin_manage_app_config,app_config_select_public}\`

### app_settings — 1

- Table \`public.app_settings\` has multiple permissive policies for role \`authenticated\` for action \`SELECT\`. Policies include \`{app_settings_admin_manage,app_settings_public_read,app_settings_select}\`

### banners — 1

- Table \`public.banners\` has multiple permissive policies for role \`authenticated\` for action \`SELECT\`. Policies include \`{"Admins have full access to banners","Public and users can view active banners"}\`

### bookings — 4

- Table \`public.bookings\` has multiple permissive policies for role \`authenticated\` for action \`DELETE\`. Policies include \`{"Admins full access",bookings_delete_secure}\`
- Table \`public.bookings\` has multiple permissive policies for role \`authenticated\` for action \`INSERT\`. Policies include \`{"Admins full access",bookings_insert_admin_service}\`
- Table \`public.bookings\` has multiple permissive policies for role \`authenticated\` for action \`SELECT\`. Policies include \`{"Admins full access",bookings_select_private_scope}\`
- Table \`public.bookings\` has multiple permissive policies for role \`authenticated\` for action \`UPDATE\`. Policies include \`{"Admins full access",bookings_update_secure}\`

### championships — 3

- Table \`public.championships\` has multiple permissive policies for role \`authenticated\` for action \`INSERT\`. Policies include \`{championships_admin_manage_all,championships_insert}\`
- Table \`public.championships\` has multiple permissive policies for role \`authenticated\` for action \`SELECT\`. Policies include \`{championships_admin_manage_all,championships_select}\`
- Table \`public.championships\` has multiple permissive policies for role \`authenticated\` for action \`UPDATE\`. Policies include \`{championships_admin_manage_all,championships_update_own}\`

### financial_audit_logs — 1

- Table \`public.financial_audit_logs\` has multiple permissive policies for role \`authenticated\` for action \`SELECT\`. Policies include \`{financial_logs_admin_all,financial_logs_owner_select,financial_logs_user_select}\`

### league_settings — 1

- Table \`public.league_settings\` has multiple permissive policies for role \`authenticated\` for action \`SELECT\`. Policies include \`{"Allow admins to manage league_settings","Allow public read on league_settings"}\`

### platform_business_rules — 1

- Table \`public.platform_business_rules\` has multiple permissive policies for role \`authenticated\` for action \`SELECT\`. Policies include \`{platform_business_rules_admin_write,platform_business_rules_select_authenticated}\`

### promotions — 1

- Table \`public.promotions\` has multiple permissive policies for role \`authenticated\` for action \`SELECT\`. Policies include \`{promotions_admin_manage,promotions_public_read}\`

### reports — 2

- Table \`public.reports\` has multiple permissive policies for role \`authenticated\` for action \`DELETE\`. Policies include \`{"Admins full access",reports_admin_delete}\`
- Table \`public.reports\` has multiple permissive policies for role \`authenticated\` for action \`SELECT\`. Policies include \`{"Admins full access",reports_admin_select}\`

### reviews — 1

- Table \`public.reviews\` has multiple permissive policies for role \`authenticated\` for action \`SELECT\`. Policies include \`{"Admins full access",reviews_select}\`

### stadium_custom_rates — 1

- Table \`public.stadium_custom_rates\` has multiple permissive policies for role \`authenticated\` for action \`SELECT\`. Policies include \`{stadium_custom_rates_manage_own,stadium_custom_rates_select}\`

### stadiums — 4

- Table \`public.stadiums\` has multiple permissive policies for role \`authenticated\` for action \`DELETE\`. Policies include \`{stadiums_admin_manage_all,stadiums_delete_own}\`
- Table \`public.stadiums\` has multiple permissive policies for role \`authenticated\` for action \`INSERT\`. Policies include \`{stadiums_admin_manage_all,stadiums_insert_own}\`
- Table \`public.stadiums\` has multiple permissive policies for role \`authenticated\` for action \`SELECT\`. Policies include \`{stadiums_admin_manage_all,stadiums_select_public}\`
- Table \`public.stadiums\` has multiple permissive policies for role \`authenticated\` for action \`UPDATE\`. Policies include \`{stadiums_admin_manage_all,stadiums_update_own}\`

### support_ticket_messages — 1

- Table \`public.support_ticket_messages\` has multiple permissive policies for role \`authenticated\` for action \`SELECT\`. Policies include \`{support_ticket_messages_staff_select,support_ticket_messages_user_select}\`

### support_tickets — 1

- Table \`public.support_tickets\` has multiple permissive policies for role \`authenticated\` for action \`SELECT\`. Policies include \`{support_tickets_staff_select,support_tickets_user_select}\`

### teams — 1

- Table \`public.teams\` has multiple permissive policies for role \`authenticated\` for action \`SELECT\`. Policies include \`{teams_public_directory_select,teams_select}\`

### tournament_matches — 2

- Table \`public.tournament_matches\` has multiple permissive policies for role \`authenticated\` for action \`INSERT\`. Policies include \`{"Admins full access",tournament_matches_insert}\`
- Table \`public.tournament_matches\` has multiple permissive policies for role \`authenticated\` for action \`SELECT\`. Policies include \`{"Admins full access",tournament_matches_select}\`

### transactions — 1

- Table \`public.transactions\` has multiple permissive policies for role \`authenticated\` for action \`SELECT\`. Policies include \`{transactions_admin_select,transactions_select_owner_or_admin}\`

### users — 4

- Table \`public.users\` has multiple permissive policies for role \`authenticated\` for action \`DELETE\`. Policies include \`{users_admin_manage_all,users_delete_policy}\`
- Table \`public.users\` has multiple permissive policies for role \`authenticated\` for action \`INSERT\`. Policies include \`{users_admin_manage_all,users_insert_policy}\`
- Table \`public.users\` has multiple permissive policies for role \`authenticated\` for action \`SELECT\`. Policies include \`{users_admin_manage_all,users_select_policy}\`
- Table \`public.users\` has multiple permissive policies for role \`authenticated\` for action \`UPDATE\`. Policies include \`{users_admin_manage_all,users_update_policy}\`

### vsp_1v1_registrations — 2

- Table \`public.vsp_1v1_registrations\` has multiple permissive policies for role \`authenticated\` for action \`INSERT\`. Policies include \`{"Admins full access",vsp_1v1_registrations_insert}\`
- Table \`public.vsp_1v1_registrations\` has multiple permissive policies for role \`authenticated\` for action \`SELECT\`. Policies include \`{"Admins full access",vsp_1v1_registrations_select}\`

### vsp_1v1_tournament_orders — 1

- Table \`public.vsp_1v1_tournament_orders\` has multiple permissive policies for role \`authenticated\` for action \`SELECT\`. Policies include \`{"Service role and atomic functions manage 1v1 orders","Users and admins can view 1v1 orders"}\`

### vsp_1v1_tournament_players — 5

- Table \`public.vsp_1v1_tournament_players\` has multiple permissive policies for role \`anon\` for action \`SELECT\`. Policies include \`{"Admins manage tournament players","Anyone can view tournament players"}\`
- Table \`public.vsp_1v1_tournament_players\` has multiple permissive policies for role \`authenticated\` for action \`DELETE\`. Policies include \`{"Admins full access","Admins manage tournament players"}\`
- Table \`public.vsp_1v1_tournament_players\` has multiple permissive policies for role \`authenticated\` for action \`INSERT\`. Policies include \`{"Admins full access","Admins manage tournament players"}\`
- Table \`public.vsp_1v1_tournament_players\` has multiple permissive policies for role \`authenticated\` for action \`SELECT\`. Policies include \`{"Admins full access","Admins manage tournament players","Anyone can view tournament players"}\`
- Table \`public.vsp_1v1_tournament_players\` has multiple permissive policies for role \`authenticated\` for action \`UPDATE\`. Policies include \`{"Admins full access","Admins manage tournament players"}\`

### vsp_1v1_tournaments — 8

- Table \`public.vsp_1v1_tournaments\` has multiple permissive policies for role \`anon\` for action \`SELECT\`. Policies include \`{"Admins manage tournaments","Anyone can view active or completed 1v1 tournaments","Anyone can view published tournaments"}\`
- Table \`public.vsp_1v1_tournaments\` has multiple permissive policies for role \`authenticated\` for action \`DELETE\`. Policies include \`{"Admins full access","Admins manage tournaments"}\`
- Table \`public.vsp_1v1_tournaments\` has multiple permissive policies for role \`authenticated\` for action \`INSERT\`. Policies include \`{"Admins full access","Admins manage tournaments"}\`
- Table \`public.vsp_1v1_tournaments\` has multiple permissive policies for role \`authenticated\` for action \`SELECT\`. Policies include \`{"Admins full access","Admins manage tournaments","Anyone can view active or completed 1v1 tournaments","Anyone can view published tournaments"}\`
- Table \`public.vsp_1v1_tournaments\` has multiple permissive policies for role \`authenticated\` for action \`UPDATE\`. Policies include \`{"Admins full access","Admins manage tournaments"}\`
- Table \`public.vsp_1v1_tournaments\` has multiple permissive policies for role \`authenticator\` for action \`SELECT\`. Policies include \`{"Admins manage tournaments","Anyone can view published tournaments"}\`
- Table \`public.vsp_1v1_tournaments\` has multiple permissive policies for role \`dashboard_user\` for action \`SELECT\`. Policies include \`{"Admins manage tournaments","Anyone can view published tournaments"}\`
- Table \`public.vsp_1v1_tournaments\` has multiple permissive policies for role \`supabase_privileged_role\` for action \`SELECT\`. Policies include \`{"Admins manage tournaments","Anyone can view published tournaments"}\`

### vsp_1vs1_players — 1

- Table \`public.vsp_1vs1_players\` has multiple permissive policies for role \`authenticated\` for action \`SELECT\`. Policies include \`{admin_manage_1v1_players,vsp_1vs1_players_select_unified}\`

### webhook_logs — 1

- Table \`public.webhook_logs\` has multiple permissive policies for role \`authenticated\` for action \`SELECT\`. Policies include \`{webhook_logs_admin_only,webhook_logs_admin_select}\`

## Security-definer view check

Security Advisor `security_definer_view` findings: **0**. Metadata query currently lists four legacy views with `security_invoker=true`; view/underlying RLS behavior still needs role-based testing. This document accepts **74.01/74.02 and 75.01/75.02** for inventory and categorization only; no RLS changes were made. 

**Unfinished:** 74.03–74.07 and 75.03–75.07 require safe policies, negative authorization tests and post-change advisor rerun. Historical 51 multiple permissive warnings now **50**. 
