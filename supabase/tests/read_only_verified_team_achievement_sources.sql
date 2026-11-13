-- VSP read-only staging: aggregate source inventory, no IDs or personal data.
WITH owner_titles AS (
 SELECT c.id FROM public.championships c
 JOIN public.stadiums s ON s.id=c.stadium_id
 WHERE c.owner_id=s.owner_id AND c.is_approved IS TRUE
   AND c.status='completed' AND c.champion_team_id IS NOT NULL
), members AS (
 SELECT team_id,user_id FROM public.team_members WHERE user_id IS NOT NULL
 UNION
 SELECT id,captain_id FROM public.teams WHERE captain_id IS NOT NULL
), completed_champions AS (
 SELECT DISTINCT champion_user_id FROM public.vsp_1v1_tournaments
 WHERE status='completed' AND champion_user_id IS NOT NULL
)
SELECT
 (SELECT count(*) FROM owner_titles) owner_approved_team_titles,
 (SELECT count(*) FROM public.championships
  WHERE is_approved AND status='completed' AND champion_team_id IS NOT NULL) approved_team_titles,
 (SELECT count(*) FROM completed_champions) distinct_completed_1v1_champions,
 (SELECT count(DISTINCT (m.team_id,m.user_id)) FROM members m
   JOIN completed_champions c ON c.champion_user_id=m.user_id)
   current_member_to_1v1_champion_matches,
 (SELECT count(*) FROM public.teams) teams_total;
