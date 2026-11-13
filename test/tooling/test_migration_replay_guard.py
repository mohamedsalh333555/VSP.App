import importlib.util
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


if __name__ == "__main__":
    unittest.main()
