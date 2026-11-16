"""Regression: Team Skills SQL runner can never point at hosted Supabase."""
import importlib.util
from pathlib import Path
import unittest

script = Path(__file__).resolve().parents[2] / "scripts/test_team_skills_rls_isolated.py"
spec = importlib.util.spec_from_file_location("team_skills_rls_isolated", script)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class TeamSkillsRlsTargetGuardTest(unittest.TestCase):
    def test_requires_explicit_disposable_local_database(self):
        good = {"VSP_CONTRACT_ISOLATED": "1", "PGHOST": "127.0.0.1",
                "PGPORT": "5432", "PGDATABASE": "vsp_security_contracts"}
        module.reject_nonlocal_targets(good)
        for k, value in [("VSP_CONTRACT_ISOLATED", "0"),
                         ("PGHOST", "db.vtwgqyxglevcsxwdmhop.supabase.co"),
                         ("PGPORT", "5433"), ("PGDATABASE", "postgres")]:
            with self.subTest(variable=k), self.assertRaises(RuntimeError):
                module.reject_nonlocal_targets({**good,k:value})


if __name__ == "__main__":
    unittest.main()
