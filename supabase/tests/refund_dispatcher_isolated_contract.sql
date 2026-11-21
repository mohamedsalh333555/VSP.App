-- RUN ONLY inside a rolled-back transaction on disposable local Postgres.
-- The real pg_net HTTP endpoint is NEVER called; local net.http_post is a
-- pure SQL capture stub. Never run this fixture against staging/production.
create schema net;
create table public.cancellation_refund_queue(
  status text, locked_until timestamptz, updated_at timestamptz not null default now());
create table public.vsp_1v1_cancellation_refund_queue(
  status text, locked_until timestamptz, updated_at timestamptz not null default now());
create table public.team_league_cancellation_refund_queue(
  status text, locked_until timestamptz, updated_at timestamptz not null default now());
create table public.internal_function_secrets(name text primary key, secret text);
create table public.refund_dispatch_mock_calls(url text, action text);

-- Does not use the real network extension or retain authorization headers.
create function net.http_post(url text, headers jsonb, body jsonb)
returns bigint language plpgsql as $capture$
begin
  if headers->>'Authorization' is distinct from 'Bearer synthetic-fixture-token' then
    raise exception 'FAIL: refund worker authorization header missing';
  end if;
  insert into public.refund_dispatch_mock_calls(url,action)
    values(url,body->>'action');
  return 1;
end;
$capture$;

-- VALIDATOR_IMPLEMENTATION_HERE

do $contract$
declare
  v_ref constant text := 'vtwgqyxglevcsxwdmhop'; -- Synthetic local test ref.
  v_expected constant text :=
    'https://vtwgqyxglevcsxwdmhop.supabase.co/functions/v1/process_tournament_refund';
  v_cnt integer;
begin
  perform set_config('vsp.refund_worker_project_ref','',true);
  perform public.reconcile_cancellation_refund_queue();
  if (select count(*) from public.refund_dispatch_mock_calls) <> 0 then
    raise exception 'FAIL: empty queues must not dispatch';
  end if;

  insert into public.team_league_cancellation_refund_queue(status) values('pending');
  perform public.reconcile_cancellation_refund_queue();
  if (select count(*) from public.refund_dispatch_mock_calls) <> 0 then
    raise exception 'FAIL: missing project identity must fail closed';
  end if;

  perform set_config('vsp.refund_worker_project_ref','https://unsafe.example',true);
  perform public.reconcile_cancellation_refund_queue();
  if (select count(*) from public.refund_dispatch_mock_calls) <> 0 then
    raise exception 'FAIL: arbitrary endpoint must not dispatch';
  end if;

  perform set_config('vsp.refund_worker_project_ref',v_ref,true);
  perform public.reconcile_cancellation_refund_queue();
  if (select count(*) from public.refund_dispatch_mock_calls) <> 0 then
    raise exception 'FAIL: missing credential must not dispatch';
  end if;

  insert into public.internal_function_secrets(name,secret)
    values('refund_worker','synthetic-fixture-token');
  perform public.reconcile_cancellation_refund_queue();
  if (select count(*) from public.refund_dispatch_mock_calls
      where url=v_expected and action='process_queue') <> 1 then
    raise exception 'FAIL: league-only queue did not dispatch locally';
  end if;

  delete from public.team_league_cancellation_refund_queue;
  delete from public.refund_dispatch_mock_calls;
  insert into public.cancellation_refund_queue(status) values('pending');
  perform public.reconcile_cancellation_refund_queue();
  if (select count(*) from public.refund_dispatch_mock_calls) <> 1 then
    raise exception 'FAIL: standard refund queue not dispatched';
  end if;

  delete from public.cancellation_refund_queue;
  delete from public.refund_dispatch_mock_calls;
  insert into public.vsp_1v1_cancellation_refund_queue(status) values('pending');
  perform public.reconcile_cancellation_refund_queue();
  if (select count(*) from public.refund_dispatch_mock_calls) <> 1 then
    raise exception 'FAIL: 1v1 refund queue not dispatched';
  end if;

  delete from public.vsp_1v1_cancellation_refund_queue;
  delete from public.refund_dispatch_mock_calls;
  insert into public.team_league_cancellation_refund_queue(
    status,locked_until,updated_at
  ) values('processing',now()+interval '5 minutes',now());
  perform public.reconcile_cancellation_refund_queue();
  if (select count(*) from public.refund_dispatch_mock_calls) <> 0 then
    raise exception 'FAIL: active lease must not be reclaimed';
  end if;

  update public.team_league_cancellation_refund_queue
     set locked_until=now()-interval '1 minute';
  perform public.reconcile_cancellation_refund_queue();
  if (select count(*) from public.refund_dispatch_mock_calls) <> 1 then
    raise exception 'FAIL: expired lease must be eligible';
  end if;

  delete from public.team_league_cancellation_refund_queue;
  delete from public.refund_dispatch_mock_calls;
  insert into public.team_league_cancellation_refund_queue(
    status,locked_until,updated_at
  ) values('processing',null,now()-interval '20 minutes');
  perform public.reconcile_cancellation_refund_queue();
  if (select count(*) from public.refund_dispatch_mock_calls) <> 1 then
    raise exception 'FAIL: stalled legacy lease must be eligible';
  end if;

  delete from public.team_league_cancellation_refund_queue;
  delete from public.refund_dispatch_mock_calls;
  insert into public.team_league_cancellation_refund_queue(status) values('completed');
  perform public.reconcile_cancellation_refund_queue();
  if (select count(*) from public.refund_dispatch_mock_calls) <> 0 then
    raise exception 'FAIL: completed queue row must not dispatch';
  end if;

  -- With pending rows across queues we send ONE trigger; the worker claims
  -- all three via its existing distinct atomic RPCs.
  truncate public.team_league_cancellation_refund_queue;
  truncate public.cancellation_refund_queue;
  truncate public.vsp_1v1_cancellation_refund_queue;
  insert into public.cancellation_refund_queue(status) values('pending');
  insert into public.team_league_cancellation_refund_queue(status) values('pending');
  insert into public.vsp_1v1_cancellation_refund_queue(status) values('pending');
  perform public.reconcile_cancellation_refund_queue();
  if (select count(*) from public.refund_dispatch_mock_calls) <> 1 then
    raise exception 'FAIL: mixed queues must dispatch exactly once';
  end if;
end;
$contract$;
