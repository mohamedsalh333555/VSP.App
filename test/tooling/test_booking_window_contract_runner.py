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


if __name__ == "__main__":
    unittest.main()
