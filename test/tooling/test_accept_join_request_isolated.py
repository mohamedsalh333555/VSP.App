import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    'vsp_join_contract_runner',
    ROOT / 'scripts' / 'test_accept_join_request_isolated.py',
)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError('Missing isolated join runner')
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class JoinRunnerSafetyTest(unittest.TestCase):
    def setUp(self):
        self.base = {
            "VSP_CONTRACT_ISOLATED": "1",
            "PGHOST": "127.0.0.1",
            "PGPORT": "5432",
            "PGDATABASE": "vsp_security_contracts",
        }

    def test_prohibits_nonlocal_and_nonisolated_targets(self):
        for name, invalid in [
            ("VSP_CONTRACT_ISOLATED", ""),
            ("PGHOST", "prod.example.com"),
            ("PGPORT", "6543"),
            ("PGDATABASE", "postgres"),
        ]:
            with self.subTest(name=name):
                with self.assertRaises(RuntimeError):
                    runner.reject_nonlocal_targets({**self.base, name: invalid})

    def test_loads_only_explicit_function_body(self):
        self.assertIn('JOIN_REQUEST_REQUIRED', runner.extract_function(runner.CANDIDATE))
        self.assertIn('joined_user_ids', runner.extract_function(runner.BASELINE))
        self.assertNotIn('revoke all', runner.extract_function(runner.CANDIDATE).lower())

    def test_valid_fixture_target(self):
        runner.reject_nonlocal_targets(self.base)


if __name__ == "__main__":
    unittest.main()
