-- Branch-only proposed remediation; DO NOT apply before environment-owner review.
-- P1 #39: project-isolated refund worker dispatch for ALL three cancellation
-- refund queues. No payment, queue, account or booking rows are updated here.
--
-- A trusted deployment operator MUST set the per-database custom setting
--   vsp.refund_worker_project_ref = <THIS DATABASE'S 20-char Supabase project ref>
-- e.g. using ALTER DATABASE (not a SQL value baked into this migration).
-- The dispatcher fails CLOSED if it is unset/invalid, or if the existing
-- refund_worker authentication secret is missing.
--
-- This GUC cannot independently prove the host identity. Production rollout
-- requires a separate environment identity verification and a review of how
-- the configuration is provisioned. NEVER copy a production ref to staging.
create or replace function public.reconcile_cancellation_refund_queue()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_project_ref text;
  v_url text;
  v_secret text;
  v_has_pending boolean;
begin
  -- No worker invocation if all queues are empty. Reclaim only abandoned
  -- processing leases (same semantics as claim_next_*_atomic routines).
  select
    exists (
      select 1 from public.cancellation_refund_queue
      where status = 'pending'
         or (status = 'processing' and locked_until is not null
             and locked_until < now())
         or (status = 'processing' and locked_until is null
             and updated_at < now() - interval '15 minutes')
    )
    or exists (
      select 1 from public.vsp_1v1_cancellation_refund_queue
      where status = 'pending'
         or (status = 'processing' and locked_until is not null
             and locked_until < now())
         or (status = 'processing' and locked_until is null
             and updated_at < now() - interval '15 minutes')
    )
    or exists (
      select 1 from public.team_league_cancellation_refund_queue
      where status = 'pending'
         or (status = 'processing' and locked_until is not null
             and locked_until < now())
         or (status = 'processing' and locked_until is null
             and updated_at < now() - interval '15 minutes')
    )
  into v_has_pending;

  if not coalesce(v_has_pending,false) then
    return;
  end if;

  v_project_ref := nullif(btrim(current_setting(
    'vsp.refund_worker_project_ref', true)), '');
  -- Only Supabase-hosted HTTPS project URLs; never accept caller-provided
  -- arbitrary HTTP URLs, paths, ports, query strings or IPv4 targets.
  if v_project_ref is null
     or v_project_ref !~ '^[a-z0-9]{20}$' then
    raise warning 'Refund dispatch skipped: local project ref unconfigured/invalid';
    return;
  end if;

  select secret into v_secret
  from public.internal_function_secrets
  where name = 'refund_worker'
  limit 1;

  if coalesce(nullif(btrim(v_secret),''),'') = '' then
    raise warning 'Refund dispatch skipped: dedicated worker credential missing';
    return;
  end if;

  v_url := 'https://' || v_project_ref ||
           '.supabase.co/functions/v1/process_tournament_refund';

  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type','application/json',
      'Authorization','Bearer ' || v_secret
    ),
    body := jsonb_build_object('action','process_queue')
  );
exception when others then
  -- Do not leak header values, secrets, URLs or queue details in cron logs.
  raise warning 'Refund dispatch failed safely (SQLSTATE %)', SQLSTATE;
end;
$function$;

-- Retain the service-only surface used by the existing cron.
revoke all on function public.reconcile_cancellation_refund_queue()
  from public, anon, authenticated;
grant execute on function public.reconcile_cancellation_refund_queue()
  to service_role;
