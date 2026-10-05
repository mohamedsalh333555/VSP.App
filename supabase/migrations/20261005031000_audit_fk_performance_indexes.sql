CREATE INDEX IF NOT EXISTS idx_championship_registrations_team_id
  ON public.championship_registrations(team_id);

CREATE INDEX IF NOT EXISTS idx_team_league_match_submissions_team_id
  ON public.team_league_match_submissions(team_id);

CREATE INDEX IF NOT EXISTS idx_team_league_payments_team_id
  ON public.team_league_payments(team_id);