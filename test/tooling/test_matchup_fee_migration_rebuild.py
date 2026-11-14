"""Guard the disposable matchup migration contract from remote targets."""
import importlib.util
from pathlib import Path
import unittest

PATH = Path(__file__).resolve().parents[2] / "scripts/test_matchup_fee_migration_rebuild.py"
spec = importlib.util.spec_from_file_location("matchup_fee_rebuild", PATH)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class MatchupFeeTargetGuardTest(unittest.TestCase):
    def test_rejects_remote_or_unapproved_target(self):
        good = {"VSP_CONTRACT_ISOLATED": "1", "PGHOST": "127.0.0.1",
                "PGPORT": "5432", "PGDATABASE": "vsp_security_contracts"}
        module.reject_nonlocal_targets(good)
        for key, value in (("PGHOST", "db.example.com"), ("PGHOST", "/var/run/postgresql"),
                           ("PGPORT", "5433"), ("PGDATABASE", "postgres"),
                           ("VSP_CONTRACT_ISOLATED", "0")):
            with self.subTest(key=key, value=value), self.assertRaises(RuntimeError):
                module.reject_nonlocal_targets({**good, key: value})

    def test_contract_has_unambiguous_source_injections(self):
        sql = module.contract_sql()
        self.assertEqual(sql.count("CREATE OR REPLACE FUNCTION public.add_team_to_matchup_by_code"), 4)
        self.assertNotIn("-- CURRENT_REPLAY_HERE", sql)
        self.assertNotIn("-- LEGACY_MIGRATION_HERE", sql)


if __name__ == "__main__":
    unittest.main()
