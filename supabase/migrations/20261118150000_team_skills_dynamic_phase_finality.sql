-- Team Skills Cup: replace the fixed 12-stage finality check with the
-- authoritative phase count for this specific cup. No tables, RLS policies,
-- scoring rules, payments, players, or already-announced results are changed.
--
-- Existing score constraints guarantee UNIQUE(registration_id, stage_no) and
-- FOREIGN KEY(cup_id, stage_no) REFERENCES team_skills_phases(cup_id, stage_no).
-- Thus matching the approved-score count to the nonzero number of configured
-- phases means every required stage is approved, without inventing stage 12.
--
-- Keep the original view column names, order and types for all consumers.
-- Preserve invoker security and the pre-existing authenticated-only read grant.
CREATE OR REPLACE VIEW public.team_skills_leaderboard
WITH (security_invoker = true) AS
SELECT
    r.cup_id,
    r.team_id,
    r.id AS registration_id,
    COALESCE(SUM(s.computed_points) FILTER (
      WHERE s.status = 'approved'
    ), 0)::numeric(7,2) AS points,
    COUNT(s.id) FILTER (
      WHERE s.status = 'approved'
    )::integer AS completed_stages,
    (
      (SELECT COUNT(*)
       FROM public.team_skills_phases AS expected
       WHERE expected.cup_id = r.cup_id) > 0
      AND
      COUNT(s.id) FILTER (WHERE s.status = 'approved') =
      (SELECT COUNT(*)
       FROM public.team_skills_phases AS expected
       WHERE expected.cup_id = r.cup_id)
    ) AS all_stages_approved
FROM public.team_skills_registrations AS r
LEFT JOIN public.team_skills_scores AS s
  ON s.registration_id = r.id AND s.cup_id = r.cup_id
WHERE r.status = 'approved'
GROUP BY r.cup_id, r.team_id, r.id;

REVOKE ALL ON public.team_skills_leaderboard FROM PUBLIC, anon;
GRANT SELECT ON public.team_skills_leaderboard TO authenticated;
