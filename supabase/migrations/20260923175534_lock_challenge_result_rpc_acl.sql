-- Lock the challenge-result RPC to authenticated callers only.
REVOKE ALL ON FUNCTION public.submit_challenge_result_atomic(uuid,uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_challenge_result_atomic(uuid,uuid,text) TO authenticated, service_role;
