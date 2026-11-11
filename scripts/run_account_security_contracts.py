#!/usr/bin/env python3
"""Execute account SQL contracts only on a fresh, explicitly isolated local DB.

Uses native PostgreSQL via psql; never accepts a hosted Supabase URL or token.
"""
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def connection_args(env):
    if env.get('VSP_CONTRACT_ISOLATED') != '1':
        raise ValueError('VSP_CONTRACT_ISOLATED=1 is required')
    if env.get('PGHOST') not in ('127.0.0.1', 'localhost'):
        raise ValueError('Only loopback PostgreSQL is allowed')
    if env.get('PGDATABASE') != 'vsp_security_contracts':
        raise ValueError('Only vsp_security_contracts is allowed')
    if env.get('PGUSER') != 'postgres':
        raise ValueError('Use the ephemeral postgres fixture owner')
    port = env.get('PGPORT', '')
    if not port.isascii() or not port.isdigit() or not 1 <= int(port) <= 65535:
        raise ValueError('Explicit valid local PGPORT is required')
    return ['psql', '-X', '--set=ON_ERROR_STOP=1', '--host=127.0.0.1',
            '--port=' + port, '--username=postgres', '--dbname=vsp_security_contracts']


def safe_environment(env):
    # Prevent libpq service, address or startup options redirecting the target.
    return {k: v for k, v in env.items()
            if k not in ('PGHOSTADDR', 'PGSERVICE', 'PGSERVICEFILE', 'PGOPTIONS')}


def read_file(path):
    resolved = (ROOT / path).resolve()
    resolved.relative_to(ROOT)
    return resolved.read_text()


def invoke(args, env, sql):
    return subprocess.run(args, input=sql, text=True, capture_output=True, env=env)


def require_success(args, env, label, sql):
    result = invoke(args, env, sql)
    if result.returncode:
        raise RuntimeError(label + ': ' + result.stderr[-5000:])
    print('PASS ' + label, flush=True)


def main():
    args = connection_args(os.environ)
    env = safe_environment(os.environ)
    manifest = json.loads(read_file('supabase/tests/account_security_manifest.json'))
    require_success(args, env, 'fresh isolated database', """
DO $$ BEGIN
  IF current_database() <> 'vsp_security_contracts'
     OR to_regnamespace('auth') IS NOT NULL
     OR EXISTS (SELECT 1 FROM pg_tables WHERE schemaname='public') THEN
    RAISE EXCEPTION 'CONTRACT_DATABASE_NOT_FRESH';
  END IF;
END; $$;
""")
    for path in [manifest['fixture'], *manifest.get('dependencies', []), *manifest['migrations'], *manifest['tests']]:
        require_success(args, env, path, read_file(path))
    # A suite must leave no account rows behind after its rollback.
    require_success(args, env, 'no persistent test accounts', """
DO $$ BEGIN
  IF EXISTS(SELECT 1 FROM auth.users) OR EXISTS(SELECT 1 FROM public.users) THEN
    RAISE EXCEPTION 'FIXTURE_ACCOUNTS_REMAIN';
  END IF;
END; $$;
""")
    mutants = [
        ('active admin helper disabled', """
CREATE OR REPLACE FUNCTION public.require_active_admin_actor()
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,public,pg_temp
AS $$ BEGIN RETURN; END; $$;
""", 'supabase/tests/admin_actor_contract.sql', 'FAIL anonymous admin guard accepted'),
        ('admin RPC precondition removed', """
DO $$ DECLARE d text; BEGIN
  d:=pg_get_functiondef('public.admin_set_owner_subscription_atomic(uuid,text,integer)'::regprocedure);
  EXECUTE replace(d,'PERFORM public.require_active_admin_actor();','NULL;');
END; $$;
""", 'supabase/tests/admin_actor_contract.sql', 'FAIL admin RPC precondition'),
        ('client role guard removed', 'DROP TRIGGER aaa_guard_client_profile_role ON public.users;',
         'supabase/tests/client_profile_role_guard_contract.sql', 'FAIL privileged legacy insert'),
        ('profile RLS disabled', 'ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;',
         'supabase/tests/account_profile_rls_contract.sql', 'FAIL player profile read isolation'),
        ('anonymous provisioning execute', 'GRANT EXECUTE ON FUNCTION public.provision_registration_profile(text) TO anon;',
         'supabase/tests/registration_profile_provisioning_staging.sql', 'FAIL anon provisioning'),
        ('cancellation without completion check', """
CREATE OR REPLACE FUNCTION public.cancel_incomplete_registration_atomic(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN RETURN public.delete_user_permanently(p_user_id); END; $$;
""", 'supabase/tests/registration_cleanup_and_chat_read_staging.sql', 'FAIL unknown completion'),
        ('conversation membership removed', """
CREATE OR REPLACE FUNCTION public.mark_chat_messages_as_read(p_conversation_id uuid,p_user_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN UPDATE public.chat_messages SET is_read=true WHERE conversation_id=p_conversation_id; END; $$;
""", 'supabase/tests/registration_cleanup_and_chat_read_staging.sql', 'FAIL nonmember read allowed'),
    ]
    for name, mutation, path, marker in mutants:
        # psql exits on the expected exception; connection close rolls back the
        # outer transaction, including the deliberately broken guard.
        result = invoke(args, env, 'BEGIN;\n' + mutation + '\n' + read_file(path))
        if result.returncode == 0 or marker not in result.stderr:
            raise RuntimeError('Mutation was not detected for the intended reason: ' + name
                               + '\n' + result.stderr[-3000:])
        print('PASS mutation rejected: ' + name, flush=True)
    for path in manifest['tests']:
        require_success(args, env, 'restored baseline: ' + path, read_file(path))
    admin_migration = read_file('supabase/migrations/20261111045628_require_active_admin_actor_for_sensitive_rpcs.sql')
    require_success(args, env, 'admin migration idempotent replay', admin_migration)
    drift = invoke(args, env, """BEGIN;
DO $$ DECLARE d text; b text; BEGIN
  SELECT pg_get_functiondef(oid),prosrc INTO d,b FROM pg_proc
  WHERE oid='public.admin_set_owner_subscription_atomic(uuid,text,integer)'::regprocedure;
  EXECUTE replace(d,b,E'-- unexpected concurrent change\n'||b);
END; $$;
""" + admin_migration)
    if drift.returncode == 0 or 'ADMIN_RPC_SOURCE_DRIFT' not in drift.stderr:
        raise RuntimeError('Unknown admin source body was not refused: ' + drift.stderr[-3000:])
    print('PASS unknown admin source fingerprint refused without clobbering', flush=True)
    require_success(args, env, 'final fixture cleanup', """
DO $$ BEGIN
  IF EXISTS(SELECT 1 FROM auth.users) OR EXISTS(SELECT 1 FROM public.users) THEN
    RAISE EXCEPTION 'FIXTURE_ACCOUNTS_REMAIN';
  END IF;
END; $$;
""")
    print(json.dumps({'status': 'PASS', 'sql_suites': len(manifest['tests']),
                      'security_mutants_rejected': len(mutants),
                      'scope': manifest['scope']}))
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, RuntimeError, OSError) as error:
        print('BLOCKED/FAIL: ' + str(error), file=sys.stderr)
        sys.exit(1)
