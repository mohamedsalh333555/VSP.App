revoke all on function public.calculate_elo_on_match_completion() from public,anon,authenticated;
revoke all on function public.is_admin_or_cofounder(uuid) from public,anon,authenticated;
revoke all on function public.is_admin_or_founder(uuid) from public,anon,authenticated;
revoke all on function public.check_team_has_1v1_champion(uuid) from public,anon,authenticated;