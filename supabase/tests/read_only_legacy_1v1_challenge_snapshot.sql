-- Read-only 1v1 and challenge-result integrity snapshot.
-- Run on staging ONLY; returns aggregate counts and never individual identities.
-- No mutations, account details, money amounts or password/secret values.
select
 (select count(*) from public.vsp_1v1_registrations) legacy_1v1_registrations,
 (select count(*) from public.vsp_1v1_tournament_players) current_tournament_players,
 (select count(*) from public.vsp_1v1_tournaments) tournaments,
 (select count(*) from (
   select tournament_id,user_id from public.vsp_1v1_tournament_players
   where user_id is not null group by tournament_id,user_id having count(*)>1
 ) d) duplicated_current_tournament_user_keys,
 (select count(*) from (
   select user_id from public.vsp_1v1_registrations
   where user_id is not null group by user_id having count(*)>1
 ) d) duplicated_legacy_user_keys,
 (select count(*) from public.challenge_results) old_challenge_results,
 (select count(*) from (
   select challenge_id from public.challenge_results
   where nullif(btrim(challenge_id),'') is not null
   group by challenge_id having count(*)>1
 ) d) duplicated_old_challenge_ids,
 (select count(*) from public.challenge_results
   where nullif(btrim(challenge_id),'') is null) blank_old_challenge_ids,
 (select count(*) from public.bookings
   where match_result_status='confirmed') current_confirmed_challenge_bookings;

-- Catalog-only: do not expose participant keys.
select tablename,indexname,indexdef from pg_indexes
where schemaname='public'
  and tablename in ('vsp_1v1_registrations','vsp_1v1_tournament_players','challenge_results')
order by tablename,indexname;
