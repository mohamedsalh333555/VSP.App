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


if __name__ == "__main__":
    unittest.main()
