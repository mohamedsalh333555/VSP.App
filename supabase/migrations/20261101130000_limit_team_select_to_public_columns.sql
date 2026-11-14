-- Remove table-level SELECT inherited by authenticated, then grant only
-- non-secret team profile/statistics columns. This lets the security-invoker
-- directory view honor RLS without exposing invite codes or captain phone numbers.
REVOKE SELECT ON public.teams FROM authenticated;

GRANT SELECT (
  id, name, captain_id, logo_url, points, wins, draws, losses,
  matches_played, current_winning_streak, championships_won,
  created_at, updated_at, last_reset_year, primary_color, secondary_color,
  captain_image_url, beaten_opponents, played_opponents, unlocked_badges,
  governorate, sport_type, price_per_person, date, stadium, captain_name,
  is_official, attendance_score, verified_badge, has_1v1_champion, bio
) ON public.teams TO authenticated;

COMMENT ON VIEW public.teams_public IS
'Authenticated team directory using SECURITY INVOKER and base-table RLS. Exposes public team profile/statistics columns only; captain_phone, active_invite_code, and invite_code_expires_at are excluded and not selectable by authenticated clients.';
