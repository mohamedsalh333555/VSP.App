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
    policy_plan = json.loads(read_file('supabase/tests/fixtures/blocked_admin_policy_plan_2026-11-11.json'))
    policy_catalog_sql = """DO $catalog$ DECLARE p jsonb; c record; n integer:=0; BEGIN
      FOR p IN SELECT * FROM jsonb_array_elements($plan$""" + json.dumps(policy_plan['policies']) + """$plan$::jsonb) LOOP
        SELECT qual,with_check,roles,cmd,permissive INTO c FROM pg_policies
          WHERE schemaname=p->>'schemaname' AND tablename=p->>'tablename' AND policyname=p->>'policyname';
        IF NOT FOUND THEN RAISE EXCEPTION 'FAIL expected policy missing'; END IF;
        IF c.qual IS DISTINCT FROM p->>'after_qual' OR c.with_check IS DISTINCT FROM p->>'after_check'
          OR to_jsonb(c.roles) IS DISTINCT FROM p->'roles' OR c.cmd IS DISTINCT FROM p->>'cmd'
          OR c.permissive IS DISTINCT FROM p->>'permissive' THEN
          RAISE EXCEPTION 'FAIL policy catalog fingerprint or metadata drift: %',p->>'policyname';
        END IF;
        n:=n+1;
      END LOOP;
      IF n<>37 THEN RAISE EXCEPTION 'FAIL policy catalog count'; END IF;
    END;$catalog$;
    """
    require_success(args, env, '37 exact policy definitions and metadata', policy_catalog_sql)
    # A suite must leave no account rows behind after its rollback.
    require_success(args, env, 'no persistent test accounts', """
DO $$ BEGIN
  IF EXISTS(SELECT 1 FROM auth.users) OR EXISTS(SELECT 1 FROM public.users) THEN
    RAISE EXCEPTION 'FIXTURE_ACCOUNTS_REMAIN';
  END IF;
END; $$;
""")
    mutants = [
        ('blocked admin sensitive profile bypass', """
DO $$ DECLARE d text; BEGIN
  d:=pg_get_functiondef('public.trg_fn_protect_user_sensitive_fields()'::regprocedure);
  EXECUTE replace(d,' AND COALESCE(is_blocked, false) = false','');
END; $$;
""", 'supabase/tests/blocked_admin_policy_contract.sql', 'FAIL blocked administrator unblocked self'),
        ('blocked admin config policy bypass', """
ALTER POLICY admin_manage_app_config ON public.app_config
USING (EXISTS(SELECT 1 FROM public.users u WHERE u.id=auth.uid() AND u.role IN('admin','co_founder')))
WITH CHECK (EXISTS(SELECT 1 FROM public.users u WHERE u.id=auth.uid() AND u.role IN('admin','co_founder')));
""", 'supabase/tests/blocked_admin_policy_contract.sql', 'FAIL blocked admin changed application configuration'),
        ('blocked admin scalar-role policy bypass', """
ALTER POLICY platform_business_rules_admin_write ON public.platform_business_rules
USING (EXISTS(SELECT 1 FROM public.users u WHERE u.id=auth.uid() AND u.role IN('admin','co_founder')))
WITH CHECK (EXISTS(SELECT 1 FROM public.users u WHERE u.id=auth.uid() AND u.role IN('admin','co_founder')));
""", 'supabase/tests/blocked_admin_policy_contract.sql', 'FAIL blocked admin changed business rules'),
        ('blocked admin private storage bypass', """
ALTER POLICY owner_documents_owner_manage ON storage.objects
USING (bucket_id='owner_documents') WITH CHECK (bucket_id='owner_documents');
""", 'supabase/tests/blocked_admin_policy_contract.sql', 'FAIL blocked admin storage read isolation'),
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
    policy_migration = read_file('supabase/migrations/20261111055255_restrict_blocked_admin_table_and_storage_privileges.sql')
    require_success(args, env, 'admin policy migration idempotent replay', policy_migration)
    drift_policy = invoke(args, env, "BEGIN; ALTER POLICY admin_manage_app_config ON public.app_config USING(false);\n" + policy_migration)
    if drift_policy.returncode == 0 or 'ADMIN_POLICY_SOURCE_DRIFT' not in drift_policy.stderr:
        raise RuntimeError('Unknown policy source was not refused: ' + drift_policy.stderr[-3000:])
    print('PASS unknown policy source refused without clobbering', flush=True)
    require_success(args, env, 'admin policies source-checked inverse',
                    read_file('docs/security/sql/rollback_blocked_admin_policies_2026-11-11.sql'))
    require_success(args, env, 'admin policy guards restored after inverse', policy_migration)
    require_success(args, env, 'blocked admin baseline after inverse round trip',
                    read_file('supabase/tests/blocked_admin_policy_contract.sql'))
    require_success(args, env, '37 policy definitions restored after negative probes', policy_catalog_sql)
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
    require_success(args, env, 'admin source-checked inverse',
                    read_file('docs/security/sql/rollback_admin_actor_guard_2026-11-11.sql'))
    require_success(args, env, 'admin guard restored after inverse', admin_migration)
    require_success(args, env, 'admin baseline after inverse round trip',
                    read_file('supabase/tests/admin_actor_contract.sql'))
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
