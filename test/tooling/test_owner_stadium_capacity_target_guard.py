import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "quota_contract", ROOT / "scripts/test_owner_stadium_capacity_concurrency.py"
)
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class QuotaTestIsolationGuard(unittest.TestCase):
    def setUp(self):
        self.env = {
            "VSP_CONTRACT_ISOLATED": "1", "PGHOST": "127.0.0.1",
            "PGPORT": "5432", "PGDATABASE": "vsp_security_contracts",
            "PGUSER": "postgres",
        }

    def test_local_guard_accepts_explicit_ephemeral_postgres(self):
        runner.reject_nonlocal_targets(self.env)

    def test_remote_targets_and_foreign_roles_denied(self):
        for field, values in {
            "VSP_CONTRACT_ISOLATED": ("0", ""),
            "PGHOST": ("remote.supabase.co", "10.0.0.1", ""),
            "PGPORT": ("5433", "not_a_port"),
            "PGDATABASE": ("production", "postgres", ""),
            "PGUSER": ("service_role", ""),
        }.items():
            for value in values:
                with self.subTest(field=field, value=value):
                    with self.assertRaises(RuntimeError):
                        runner.reject_nonlocal_targets({**self.env, field: value})

    def test_libpq_environment_cannot_redirect_to_production(self):
        env = runner.safe_env({
            **self.env,
            "PGHOSTADDR": "203.0.113.4",
            "PGSERVICE": "remote-prod",
            "PGOPTIONS": "-c role=service_role",
            "PGPASSWORD": "ephemeral-fixture-only",
        })
        for key in (
            "PGHOST", "PGPORT", "PGUSER", "PGDATABASE", "PGHOSTADDR",
            "PGSERVICE", "PGOPTIONS",
        ):
            self.assertNotIn(key, env)
        self.assertEqual(env["PGPASSWORD"], "ephemeral-fixture-only")

    def test_moderation_candidate_is_draft_and_checks_all_sensitive_fields(self):
        path = ROOT / "docs/security/sql/stadium_moderation_write_guard_candidate.sql"
        source = path.read_text()
        self.assertIn("NOT APPLIED TO STAGING OR PRODUCTION", source)
        self.assertIn("BEFORE INSERT OR UPDATE ON public.stadiums", source)
        for field in ("is_verified", "is_blocked", "is_featured", "rating",
                      "reviews_count", "owner_id"):
            with self.subTest(field=field):
                self.assertIn(field, source)
        self.assertIn("STADIUM_MODERATION_FIELD_FORBIDDEN", source)

    def test_sql_candidate_is_not_migration_and_covers_write_escapes(self):
        path = ROOT / "docs/security/sql/owner_stadium_capacity_guard_candidate.sql"
        source = path.read_text()
        self.assertIn("NOT APPLIED TO STAGING OR PRODUCTION", source)
        self.assertIn("BEFORE INSERT OR UPDATE OF owner_id, is_deleted_by_owner", source)
        self.assertIn("FROM public.users WHERE id = NEW.owner_id FOR UPDATE", source)
        self.assertIn("public.evaluate_owner_stadium_capacity(", source)
        self.assertIn("STADIUM_LIMIT_EXCEEDED", source)


if __name__ == "__main__":
    unittest.main()
