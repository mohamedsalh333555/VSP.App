import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STAGING_REF = "vtwgqyxglevcsxwdmhop"
PRODUCTION_REF = "mktqkddbcddrxjxabdua"


class StagingLiveContractSourceGuard(unittest.TestCase):
    def test_live_contract_requires_one_exact_staging_url(self):
        src = (ROOT / "test/db_live_verification_test.dart").read_text()
        self.assertIn(
            "_expectedStagingUrl = 'https://" + STAGING_REF + ".supabase.co'",
            src,
        )
        self.assertIn("_supabaseUrl == _expectedStagingUrl", src)
        self.assertIn(
            "Refusing to run VSP live tests against production or an unknown project.",
            src,
        )
        self.assertNotIn(PRODUCTION_REF, src)

    def test_staging_workflow_cannot_change_config_to_production(self):
        workflow = (ROOT / ".github/workflows/staging-live-contract.yml").read_text()
        self.assertIn("--dart-define=SUPABASE_URL=https://" + STAGING_REF + ".supabase.co", workflow)
        self.assertNotIn(PRODUCTION_REF, workflow)
        self.assertIn("test_staging_live_project_guard.py", workflow)

    def test_anonymous_live_tests_contain_no_direct_table_mutations(self):
        src = (ROOT / "test/db_live_verification_test.dart").read_text()
        for forbidden in (".insert(", ".update(", ".upsert(", ".delete(", ".remove("):
            with self.subTest(method=forbidden):
                self.assertNotIn(forbidden, src)
        self.assertIn("skip: !_canRunLiveTests", src)
        self.assertIn("_runLiveTests", src)

    def test_isolated_postgres_runner_is_loopback_only(self):
        runner = (ROOT / "scripts/run_account_security_contracts.py").read_text()
        self.assertIn("VSP_CONTRACT_ISOLATED", runner)
        self.assertIn("'--host=127.0.0.1'", runner)
        self.assertIn("vsp_security_contracts", runner)


if __name__ == '__main__':
    unittest.main()
