"""Local target guard for the private team-roster SQL contract."""
import importlib.util
from pathlib import Path
import unittest

path = Path(__file__).resolve().parents[2] / "scripts/test_team_roster_order_isolated.py"
spec = importlib.util.spec_from_file_location("team_roster_order", path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class RosterTargetGuardTest(unittest.TestCase):
    def test_requires_local_ephemeral_database(self):
        good = {"VSP_CONTRACT_ISOLATED": "1", "PGHOST": "127.0.0.1",
                "PGPORT": "5432", "PGDATABASE": "vsp_security_contracts"}
        module.reject_nonlocal_targets(good)
        for key, value in (("PGHOST", "db.example.com"), ("PGPORT", "5433"),
                           ("PGDATABASE", "postgres"), ("VSP_CONTRACT_ISOLATED", "0")):
            with self.subTest(key=key), self.assertRaises(RuntimeError):
                module.reject_nonlocal_targets({**good, key: value})


if __name__ == "__main__":
    unittest.main()
