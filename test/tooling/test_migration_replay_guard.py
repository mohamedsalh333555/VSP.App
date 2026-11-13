import importlib.util
import json
from unittest.mock import patch
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "vsp_safe_migration_runner",
    ROOT / "scripts" / "apply_migration_runner.py",
)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Could not load safe migration runner")
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class MigrationReplayGuardTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.migrations = self.root / "supabase" / "migrations"
        self.migrations.mkdir(parents=True)

    def create(self, name, content="SELECT 1;"):
        path = self.migrations / name
        path.write_text(content, encoding="utf-8")
        return path

    def test_refuses_same_version_on_distinct_files(self):
        first = self.create("20261113120000_alpha.sql")
        self.create("20261113120000_beta.sql")
        with self.assertRaisesRegex(ValueError, "ambiguous"):
            runner.verified_migration_path(str(first), self.root)

    def test_allows_a_unique_forward_file_and_ignores_rollback_companion(self):
        file = self.create("20261113120000_alpha.sql")
        self.create("20261113120000_alpha.rollback.sql")
        self.assertEqual(runner.verified_migration_path(str(file), self.root), file)

    def test_refuses_rollback_file_and_non_migration_path(self):
        rollback = self.create("20261113120000_alpha.rollback.sql")
        with self.assertRaises(ValueError):
            runner.verified_migration_path(str(rollback), self.root)
        out = self.root / "other.sql"
        out.write_text("SELECT 1;")
        with self.assertRaises(ValueError):
            runner.verified_migration_path(str(out), self.root)

    def test_refuses_production_unconfirmed_and_unapproved_staging(self):
        staging = runner.STAGING_PROJECT_REF
        for project, confirmed, settings in [
            ("mktqkddbcddrxjxabdua", "mktqkddbcddrxjxabdua",
             {"VSP_ALLOW_STAGING_MIGRATION": "1", "VSP_APPROVED_MIGRATION_REVIEW": "1"}),
            (staging, "mktqkddbcddrxjxabdua",
             {"VSP_ALLOW_STAGING_MIGRATION": "1", "VSP_APPROVED_MIGRATION_REVIEW": "1"}),
            (staging, staging, {}),
            (staging, staging, {"VSP_ALLOW_STAGING_MIGRATION": "1"}),
        ]:
            with self.subTest(project=project, confirmed=confirmed, settings=settings):
                with self.assertRaises(ValueError):
                    runner.verify_staging_opt_in(project, confirmed, settings)

    def test_staging_requires_both_explicit_flags(self):
        staging = runner.STAGING_PROJECT_REF
        runner.verify_staging_opt_in(
            staging, staging,
            {"VSP_ALLOW_STAGING_MIGRATION": "1",
             "VSP_APPROVED_MIGRATION_REVIEW": "1"},
        )

    def test_staging_history_preflight_allows_only_unapplied_version(self):
        version = "20261113120000"
        observed = []

        class Response:
            status = 200

            def __enter__(self):
                return self

            def __exit__(self, exc_type, exc, traceback):
                return False

            def read(self, limit):
                return b"[]"

        def fake_open(request, timeout):
            observed.append((request.full_url, json.loads(request.data), timeout))
            return Response()

        with patch.object(runner.urllib.request, "urlopen", fake_open):
            runner.reject_applied_version(version, "synthetic_ci_token")
        self.assertEqual(len(observed), 1)
        self.assertIn(runner.STAGING_PROJECT_REF, observed[0][0])
        self.assertEqual(observed[0][1]["query"],
                         "SELECT version FROM supabase_migrations.schema_migrations "
                         f"WHERE version = '{version}' LIMIT 1")
        self.assertEqual(observed[0][2], 30)

    def test_staging_history_preflight_rejects_applied_version(self):
        version = "20261113120000"

        class Response:
            status = 200

            def __enter__(self):
                return self

            def __exit__(self, exc_type, exc, traceback):
                return False

            def read(self, limit):
                return json.dumps([{"version": version}]).encode()

        with patch.object(runner.urllib.request, "urlopen", return_value=Response()):
            with self.assertRaisesRegex(ValueError, "already applied"):
                runner.reject_applied_version(version, "synthetic_ci_token")

    def test_staging_history_preflight_fails_closed_on_unknown_results(self):
        version = "20261113120000"

        class Response:
            status = 200

            def __init__(self, body):
                self.body = body

            def __enter__(self):
                return self

            def __exit__(self, exc_type, exc, traceback):
                return False

            def read(self, limit):
                return self.body[:limit]

        for body in (
            b'{"error":"forbidden"}', b'[{"version":"other"}]',
            b'[{"version":null}]', b"not json",
            b'[{"version":"20261113120000"},{"version":"20261113120000"}]',
        ):
            with self.subTest(body=body):
                with patch.object(runner.urllib.request, "urlopen",
                                  return_value=Response(body)):
                    with self.assertRaises((ValueError, json.JSONDecodeError)):
                        runner.reject_applied_version(version, "synthetic_ci_token")

    def test_staging_history_preflight_rejects_malformed_version_without_http(self):
        with patch.object(runner.urllib.request, "urlopen") as network:
            with self.assertRaisesRegex(ValueError, "Invalid migration version"):
                runner.reject_applied_version("1';drop table users;--", "synthetic_ci_token")
            network.assert_not_called()



if __name__ == "__main__":
    unittest.main()
