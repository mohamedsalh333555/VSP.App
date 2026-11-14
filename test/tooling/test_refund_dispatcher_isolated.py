import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "vsp_refund_dispatcher_contract_runner",
    ROOT / "scripts" / "test_refund_dispatcher_isolated.py",
)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Could not load isolated refund runner")
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class RefundDispatcherFixtureTest(unittest.TestCase):
    def setUp(self):
        self.base = {
            "VSP_CONTRACT_ISOLATED": "1",
            "PGHOST": "127.0.0.1",
            "PGDATABASE": "vsp_security_contracts",
            "PGPORT": "5432",
        }

    def test_rejects_all_nonlocal_targets(self):
        for key, value in [
            ("VSP_CONTRACT_ISOLATED", "0"),
            ("PGHOST", "production.example.com"),
            ("PGDATABASE", "postgres"),
            ("PGPORT", "6543"),
        ]:
            with self.subTest(key=key):
                with self.assertRaises(RuntimeError):
                    runner.verify_local_fixture_target({**self.base, key: value})

    def test_extracts_function_without_deploying_grants_or_other_sql(self):
        sql = runner.get_dispatcher_definition()
        self.assertIn("returns void", sql.lower())
        self.assertIn("vsp.refund_worker_project_ref", sql)
        self.assertIn("team_league_cancellation_refund_queue", sql)
        self.assertNotIn("revoke all", sql.lower())

    def test_staging_guard_requires_explicit_local_project_ref(self):
        runner.verify_local_fixture_target(self.base)

    def test_all_refund_sql_subprocesses_are_loopback_only(self):
        import os
        import subprocess
        from unittest.mock import patch

        unsafe = {**self.base, "PGHOSTADDR": "203.0.113.15",
                  "PGSERVICE": "production", "PGOPTIONS": "-c role=service_role"}
        with patch.dict(os.environ, unsafe, clear=True):
            with patch.object(runner.subprocess, "run",
                              return_value=subprocess.CompletedProcess(["psql"], 0)) as mocked:
                self.assertEqual(runner.main(), 0)
        self.assertEqual(mocked.call_count, 3)
        for call in mocked.call_args_list:
            argv = call.args[0]
            forwarded = call.kwargs["env"]
            for expected in ("--host=127.0.0.1", "--port=5432", "--username=postgres"):
                self.assertIn(expected, argv)
            for blocked in ("PGHOSTADDR", "PGSERVICE", "PGSERVICEFILE",
                            "PGOPTIONS", "PGHOST", "PGDATABASE", "PGUSER"):
                self.assertNotIn(blocked, forwarded)


if __name__ == "__main__":
    unittest.main()
