import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    'vsp_join_contract_runner',
    ROOT / 'scripts' / 'test_accept_join_request_isolated.py',
)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError('Missing isolated join runner')
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class JoinRunnerSafetyTest(unittest.TestCase):
    def setUp(self):
        self.base = {
            "VSP_CONTRACT_ISOLATED": "1",
            "PGHOST": "127.0.0.1",
            "PGPORT": "5432",
            "PGDATABASE": "vsp_security_contracts",
        }

    def test_prohibits_nonlocal_and_nonisolated_targets(self):
        for name, invalid in [
            ("VSP_CONTRACT_ISOLATED", ""),
            ("PGHOST", "prod.example.com"),
            ("PGPORT", "6543"),
            ("PGDATABASE", "postgres"),
        ]:
            with self.subTest(name=name):
                with self.assertRaises(RuntimeError):
                    runner.reject_nonlocal_targets({**self.base, name: invalid})

    def test_loads_only_explicit_function_body(self):
        self.assertIn('JOIN_REQUEST_REQUIRED', runner.extract_function(runner.CANDIDATE))
        self.assertIn('joined_user_ids', runner.extract_function(runner.BASELINE))
        self.assertNotIn('revoke all', runner.extract_function(runner.CANDIDATE).lower())

    def test_valid_fixture_target(self):
        runner.reject_nonlocal_targets(self.base)

    def test_psql_forces_loopback_and_discards_environment_redirects(self):
        import os
        import subprocess
        from unittest.mock import patch

        unsafe = {**self.base,
                  "PGHOSTADDR": "203.0.113.15", "PGSERVICE": "production",
                  "PGSERVICEFILE": "/tmp/unsafe-service",
                  "PGOPTIONS": "-c role=service_role"}
        with patch.dict(os.environ, unsafe, clear=True):
            with patch.object(runner.subprocess, "run",
                              return_value=subprocess.CompletedProcess(["psql"], 0)) as mocked:
                runner.run_psql("postgres", command="SELECT 1")
        argv = mocked.call_args.args[0]
        forwarded = mocked.call_args.kwargs["env"]
        for expected in ("--host=127.0.0.1", "--port=5432", "--username=postgres"):
            self.assertIn(expected, argv)
        for blocked in ("PGHOSTADDR", "PGSERVICE", "PGSERVICEFILE", "PGOPTIONS",
                        "PGHOST", "PGUSER", "PGDATABASE", "PGPORT"):
            self.assertNotIn(blocked, forwarded)


if __name__ == "__main__":
    unittest.main()
