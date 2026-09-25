REVOKE ALL ON TABLE public.challenge_results FROM anon, authenticated;
ALTER TABLE public.challenge_results ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS challenge_results_insert ON public.challenge_results;
DROP POLICY IF EXISTS challenge_results_update ON public.challenge_results;
DROP POLICY IF EXISTS challenge_results_select ON public.challenge_results;
