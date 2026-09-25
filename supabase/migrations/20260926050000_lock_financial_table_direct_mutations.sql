REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER, REFERENCES ON TABLE public.transactions FROM anon, authenticated;
REVOKE SELECT, INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER, REFERENCES ON TABLE public.transactions FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER, REFERENCES ON TABLE public.payout_settlements FROM anon, authenticated;
REVOKE ALL ON TABLE public.team_league_payments FROM anon, authenticated;
GRANT SELECT ON TABLE public.transactions TO authenticated;
GRANT SELECT ON TABLE public.payout_settlements TO authenticated;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payout_settlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_league_payments ENABLE ROW LEVEL SECURITY;
