-- ==============================================================================
-- 🏆 ROLLBACK FOR MIGRATION 202608110001: RLS SECURITY AUDIT
-- ==============================================================================

DROP POLICY IF EXISTS "bookings_select_policy" ON public.bookings;
DROP POLICY IF EXISTS "bookings_insert_policy" ON public.bookings;
DROP POLICY IF EXISTS "bookings_update_policy" ON public.bookings;

DROP POLICY IF EXISTS "users_select_policy" ON public.users;
DROP POLICY IF EXISTS "users_update_policy" ON public.users;

DROP POLICY IF EXISTS "stadiums_select_policy" ON public.stadiums;
DROP POLICY IF EXISTS "stadiums_manage_policy" ON public.stadiums;

DROP POLICY IF EXISTS "teams_select_policy" ON public.teams;
DROP POLICY IF EXISTS "teams_manage_policy" ON public.teams;

DROP POLICY IF EXISTS "team_members_select_policy" ON public.team_members;
DROP POLICY IF EXISTS "team_members_manage_policy" ON public.team_members;

DROP POLICY IF EXISTS "championships_select_policy" ON public.championships;
DROP POLICY IF EXISTS "championships_manage_policy" ON public.championships;
DROP POLICY IF EXISTS "championship_rosters_select" ON public.championship_rosters;
DROP POLICY IF EXISTS "championship_rosters_manage" ON public.championship_rosters;

DROP POLICY IF EXISTS "tournament_matches_select" ON public.tournament_matches;
DROP POLICY IF EXISTS "tournament_matches_update" ON public.tournament_matches;

DROP POLICY IF EXISTS "reviews_select_policy" ON public.reviews;
DROP POLICY IF EXISTS "reviews_insert_policy" ON public.reviews;

DROP POLICY IF EXISTS "notifications_select" ON public.notifications;
DROP POLICY IF EXISTS "notifications_insert" ON public.notifications;
DROP POLICY IF EXISTS "notifications_update" ON public.notifications;

DROP POLICY IF EXISTS "chat_select" ON public.chat_messages;
DROP POLICY IF EXISTS "chat_insert" ON public.chat_messages;

DROP POLICY IF EXISTS "reports_select" ON public.reports;
DROP POLICY IF EXISTS "reports_insert" ON public.reports;

DROP POLICY IF EXISTS "app_settings_read" ON public.app_settings;
DROP POLICY IF EXISTS "app_config_read" ON public.app_config;

DROP POLICY IF EXISTS "promotions_read" ON public.promotions;
DROP POLICY IF EXISTS "vsp_1vs1_read" ON public.vsp_1vs1_players;
DROP POLICY IF EXISTS "vsp_1v1_reg_select" ON public.vsp_1v1_registrations;
DROP POLICY IF EXISTS "vsp_1v1_reg_insert" ON public.vsp_1v1_registrations;
