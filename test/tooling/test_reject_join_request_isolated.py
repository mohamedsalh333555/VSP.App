import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "vsp_reject_join_guard_runner",
    ROOT / "scripts" / "test_reject_join_request_isolated.py",
)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Cannot load isolated reject guard")
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class RejectRunnerSafetyTest(unittest.TestCase):
    def setUp(self):
        self.safe = {
            "VSP_CONTRACT_ISOLATED": "1",
            "PGHOST": "127.0.0.1",
            "PGPORT": "5432",
            "PGDATABASE": "vsp_security_contracts",
        }

    def test_rejects_remote_or_nonfixture_db(self):
        for key, value in [
            ("VSP_CONTRACT_ISOLATED", "0"),
            ("PGHOST", "example.supabase.co"),
            ("PGPORT", "6543"),
            ("PGDATABASE", "postgres"),
        ]:
            with self.subTest(key=key):
                with self.assertRaises(RuntimeError):
                    runner.only_disposable_local_pg({**self.safe, key: value})

    def test_verified_function_extraction(self):
        function = runner.extract_function(runner.CANDIDATE)
        self.assertIn("is distinct from", function.lower())
        self.assertNotIn("revoke all", function.lower())
        self.assertIn("array_remove", function)

    def test_safe_local_target(self):
        runner.only_disposable_local_pg(self.safe)

    def test_psql_forces_loopback_and_discards_environment_redirects(self):
        import os
        import subprocess
        from unittest.mock import patch

        unsafe = {**self.safe,
                  "PGHOSTADDR": "203.0.113.15", "PGSERVICE": "production",
                  "PGSERVICEFILE": "/tmp/unsafe-service",
                  "PGOPTIONS": "-c role=service_role"}
        with patch.dict(os.environ, unsafe, clear=True):
            with patch.object(runner.subprocess, "run",
                              return_value=subprocess.CompletedProcess(["psql"], 0)) as mocked:
                runner.psql("postgres", command="SELECT 1")
        argv = mocked.call_args.args[0]
        forwarded = mocked.call_args.kwargs["env"]
        for expected in ("--host=127.0.0.1", "--port=5432", "--username=postgres"):
            self.assertIn(expected, argv)
        for blocked in ("PGHOSTADDR", "PGSERVICE", "PGSERVICEFILE", "PGOPTIONS",
                        "PGHOST", "PGUSER", "PGDATABASE", "PGPORT"):
            self.assertNotIn(blocked, forwarded)


if __name__ == "__main__":
    unittest.main()
