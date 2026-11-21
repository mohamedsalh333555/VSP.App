"""Connection boundary checks for the two-session pickup slot race."""
import importlib.util
from pathlib import Path
import unittest
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
SPEC = importlib.util.spec_from_file_location(
    "vsp_join_race_runner", ROOT / "scripts/test_accept_join_request_concurrency.py"
)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Missing isolated concurrency runner")
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class JoinRaceRunnerSafetyTest(unittest.TestCase):
    def test_psql_is_explicitly_pinned_to_local_fixture(self):
        for db in ("postgres", runner.TEST_DB):
            args = runner.psql_args(db)
            self.assertIn("--host=127.0.0.1", args)
            self.assertIn("--port=5432", args)
            self.assertIn("--username=postgres", args)
        with self.assertRaises(RuntimeError):
            runner.psql_args("production")

    def test_remote_libpq_redirects_are_stripped(self):
        env = {
            "PGHOST": "production.example", "PGHOSTADDR": "203.0.113.10",
            "PGDATABASE": "prod", "PGUSER": "service_role",
            "PGOPTIONS": "-c role=service_role", "PGSERVICE": "prod",
            "PGSERVICEFILE": "/tmp/service", "PGPORT": "6432",
        }
        cleaned = runner.isolated_psql_environment(env)
        self.assertFalse(set(env) & set(cleaned))


if __name__ == "__main__":
    unittest.main()
