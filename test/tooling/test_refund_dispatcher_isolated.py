import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
import test_refund_dispatcher_isolated as runner


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


if __name__ == "__main__":
    unittest.main()
