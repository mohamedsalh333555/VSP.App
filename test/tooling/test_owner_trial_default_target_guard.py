import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "trial_default_test", ROOT / "scripts/test_owner_trial_default_isolated.py"
)
module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(module)


class TrialDefaultIsolationTests(unittest.TestCase):
    def setUp(self):
        self.env = {
            "VSP_CONTRACT_ISOLATED": "1",
            "PGHOST": "127.0.0.1",
            "PGPORT": "5432",
            "PGDATABASE": "vsp_security_contracts",
            "PGUSER": "postgres",
        }

    def test_local_ephemeral_contract_allowed(self):
        module.reject_unsafe_target(self.env)

    def test_remote_production_and_non_ephemeral_credentials_refused(self):
        invalid = {
            "VSP_CONTRACT_ISOLATED": ["0", ""],
            "PGHOST": ["db.production.supabase.co", "localhost", ""],
            "PGDATABASE": ["postgres", "production", ""],
            "PGUSER": ["admin", "service_role"],
            "PGPORT": ["5433", ""],
        }
        for name, values in invalid.items():
            for value in values:
                with self.subTest(name=name, value=value):
                    with self.assertRaises(RuntimeError):
                        module.reject_unsafe_target({**self.env, name: value})

    def test_candidate_never_mutates_historical_owner_rows(self):
        source = (
            ROOT / "docs/security/sql/owner_trial_365_day_default_candidate.sql"
        ).read_text()
        self.assertIn("ALTER TABLE public.users ALTER COLUMN trial_ends_at DROP DEFAULT", source)
        self.assertNotIn("UPDATE public.users", source)
        self.assertIn("OWNER_TRIAL_DEFAULT_SOURCE_DRIFT", source)
        self.assertIn("NOT applied to staging or production", source)


if __name__ == "__main__":
    unittest.main()
