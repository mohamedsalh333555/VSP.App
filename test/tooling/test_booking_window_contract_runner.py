import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
import test_booking_window_function_isolated as runner


class IsolatedBookingWindowContractRunnerTest(unittest.TestCase):
    def setUp(self):
        self.env = {
            "VSP_CONTRACT_ISOLATED": "1",
            "PGHOST": "127.0.0.1",
            "PGDATABASE": "vsp_security_contracts",
            "PGPORT": "5432",
        }

    def test_refuses_unscoped_database(self):
        for field, invalid in [
            ("VSP_CONTRACT_ISOLATED", "0"),
            ("PGHOST", "db.production.supabase.co"),
            ("PGDATABASE", "postgres"),
            ("PGPORT", "6432"),
        ]:
            with self.subTest(field=field):
                modified = dict(self.env, **{field: invalid})
                with self.assertRaises(RuntimeError):
                    runner.assert_isolated_environment(modified)

    def test_allows_only_local_ephemeral_contract_target(self):
        runner.assert_isolated_environment(self.env)

    def test_both_validator_definitions_extract_without_following_ddl(self):
        baseline = runner.extract_validator_definition(runner.BASELINE)
        candidate = runner.extract_validator_definition(runner.CANDIDATE)
        self.assertIn("returns boolean", baseline.lower())
        self.assertIn("returns boolean", candidate.lower())
        self.assertIn("p_maintenance_until > now()", candidate)
        self.assertIn("v_break_start_ts := v_open_ts::date", candidate)
        self.assertNotIn("do $$", baseline.lower())

    def test_psql_forces_loopback_and_discards_environment_redirects(self):
        import os
        import subprocess
        from unittest.mock import patch

        unsafe = {**self.env,
                  "PGHOSTADDR": "203.0.113.15", "PGSERVICE": "production",
                  "PGSERVICEFILE": "/tmp/unsafe-service",
                  "PGOPTIONS": "-c role=service_role"}
        with patch.dict(os.environ, unsafe, clear=True):
            with patch.object(runner.subprocess, "run",
                              return_value=subprocess.CompletedProcess(["psql"], 0)) as mocked:
                runner.run_psql("SELECT 1")
        argv = mocked.call_args.args[0]
        forwarded = mocked.call_args.kwargs["env"]
        for expected in ("--host=127.0.0.1", "--port=5432", "--username=postgres"):
            self.assertIn(expected, argv)
        for blocked in ("PGHOSTADDR", "PGSERVICE", "PGSERVICEFILE", "PGOPTIONS",
                        "PGHOST", "PGUSER", "PGDATABASE", "PGPORT"):
            self.assertNotIn(blocked, forwarded)


if __name__ == "__main__":
    unittest.main()
