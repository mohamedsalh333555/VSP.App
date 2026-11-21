import importlib.util
import os
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('security_runner', ROOT / 'scripts/run_account_security_contracts.py')
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class AccountSecurityTargetGuardTests(unittest.TestCase):
    def setUp(self):
        self.env = {'VSP_CONTRACT_ISOLATED': '1', 'PGHOST': '127.0.0.1',
                    'PGPORT': '5432', 'PGDATABASE': 'vsp_security_contracts',
                    'PGUSER': 'postgres'}

    def test_explicit_isolated_target_uses_numeric_loopback(self):
        self.env['PGHOST'] = 'localhost'
        args = runner.connection_args(self.env)
        self.assertIn('--host=127.0.0.1', args)
        self.assertIn('--dbname=vsp_security_contracts', args)

    def test_missing_isolation_flag_rejected(self):
        self.env.pop('VSP_CONTRACT_ISOLATED')
        with self.assertRaises(ValueError):
            runner.connection_args(self.env)

    def test_hosted_or_empty_target_rejected(self):
        for host in ('db.example.supabase.co', '192.168.1.2', '', '/var/run/postgresql'):
            with self.subTest(host=host), self.assertRaises(ValueError):
                runner.connection_args({**self.env, 'PGHOST': host})

    def test_other_database_rejected(self):
        for database in ('postgres', 'production', ''):
            with self.subTest(database=database), self.assertRaises(ValueError):
                runner.connection_args({**self.env, 'PGDATABASE': database})

    def test_unexpected_owner_rejected(self):
        with self.assertRaises(ValueError):
            runner.connection_args({**self.env, 'PGUSER': 'service_role'})

    def test_invalid_port_rejected(self):
        for port in ('', '0', '65536', '-1', '54;32', '٥٤٣٢'):
            with self.subTest(port=port), self.assertRaises(ValueError):
                runner.connection_args({**self.env, 'PGPORT': port})

    def test_libpq_redirect_and_startup_options_removed(self):
        result = runner.safe_environment({**self.env, 'PGHOSTADDR': '203.0.113.1',
            'PGSERVICE': 'production', 'PGSERVICEFILE': '/tmp/service',
            'PGOPTIONS': '-c role=postgres', 'PGPASSWORD': 'ephemeral-test'})
        self.assertFalse({'PGHOSTADDR', 'PGSERVICE', 'PGSERVICEFILE', 'PGOPTIONS'} & result.keys())
        self.assertEqual(result['PGPASSWORD'], 'ephemeral-test')

    def test_fixture_path_cannot_escape_repository(self):
        with self.assertRaises(ValueError):
            runner.read_file('../outside-contract.sql')

    def test_command_fails_before_psql_without_isolation_flag(self):
        env = {**os.environ, **self.env}
        env.pop('VSP_CONTRACT_ISOLATED')
        result = subprocess.run([sys.executable, str(ROOT / 'scripts/run_account_security_contracts.py')],
                                env=env, text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('VSP_CONTRACT_ISOLATED=1 is required', result.stderr)


if __name__ == '__main__':
    unittest.main()
