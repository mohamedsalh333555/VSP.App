-- Paymob is the only authority allowed to confirm team-league payments.
revoke all on function public.confirm_team_league_payment(text,text,integer,text) from public,anon,authenticated;
grant execute on function public.confirm_team_league_payment(text,text,integer,text) to service_role;