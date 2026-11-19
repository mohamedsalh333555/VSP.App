"""Offline source-level tests for the read-only Supabase advisor release guard."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/check_supabase_security_advisor.py"
spec = importlib.util.spec_from_file_location("vsp_advisor_gate", SCRIPT)
assert spec and spec.loader
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class FakeResponse:
    def __init__(self, payload):
        self.payload = payload
    def __enter__(self):
        return self
    def __exit__(self, *_):
        return False
    def read(self, maximum):
        return self.payload[:maximum]


class AdvisorGateTest(unittest.TestCase):
    def test_empty_valid_report_passes(self):
        self.assertEqual("PASS", module.summarize({"lints": []})["status"])

    def test_warns_are_not_critical_by_default(self):
        data = {"lints": [{"name": "authenticated_security_definer_function_executable",
                            "level": "WARN", "count": 197}]}
        report = module.summarize(data)
        self.assertEqual("PASS_WITH_WARNINGS", report["status"])
        self.assertEqual(197, report["counts"]["WARN"])

    def test_strict_warnings_block_release(self):
        data = {"lints": [{"name": "auth_leaked_password_protection", "level": "WARN"}]}
        self.assertEqual("BLOCKED", module.summarize(data, strict_warnings=True)["status"])

    def test_errors_block_release(self):
        self.assertEqual("BLOCKED", module.summarize(
            {"lints": [{"name": "rls_disabled_in_public", "level": "ERROR"}]}
        )["status"])

    def test_unavailable_advisor_fails_closed_even_if_warning(self):
        self.assertEqual("BLOCKED", module.summarize(
            {"lints": [{"name": "advisor_check_unavailable", "level": "WARN"}]}
        )["status"])

    def test_rejects_invalid_or_truncated_report(self):
        for payload in [None, [], {}, {"lints": None}, {"lints": [{}]},
                        {"lints": [{"name": "unknown", "level": "OTHER"}]},
                        {"lints": [{"name": "x", "level": "WARN", "count": 0}]},
                        {"lints": [{"name": "x", "level": "WARN", "count": True}]}]:
            with self.subTest(payload=payload), self.assertRaises(ValueError):
                module.summarize(payload)

    def test_groups_counts_without_raw_finding_details(self):
        data = {"lints": [{"name": "x", "level": "WARN", "count": 3,
                            "detail": "PRIVATE PLAYER RECORD"}]}
        printed = json.dumps(module.summarize(data))
        self.assertNotIn("PRIVATE PLAYER RECORD", printed)
        self.assertEqual(3, module.summarize(data)["counts"]["WARN"])

    def test_network_request_is_read_only_and_token_not_reported(self):
        requests = []
        def fake_open(request, timeout):
            requests.append((request, timeout))
            return FakeResponse(b'{"lints": []}')
        body = module.fetch_advisors("a" * 20, "secret-for-test-only", opener=fake_open)
        self.assertEqual({"lints": []}, body)
        self.assertEqual("GET", requests[0][0].get_method())
        self.assertEqual(20, requests[0][1])
        self.assertEqual("https://api.supabase.com/v1/projects/" + "a" * 20 +
                         "/advisors/security", requests[0][0].full_url)
        self.assertNotIn("secret-for-test-only", requests[0][0].full_url)

    def test_rejects_missing_token_and_bad_project_reference_before_network(self):
        with self.assertRaisesRegex(ValueError, "invalid_project_ref"):
            module.fetch_advisors("../../bad", "secret")
        with self.assertRaisesRegex(ValueError, "missing_read_only_advisors_token"):
            module.fetch_advisors("a" * 20, "")

    def test_cli_missing_credentials_fails_closed(self):
        import os
        env = dict(os.environ)
        env.pop("SUPABASE_ADVISORS_READ_TOKEN", None)
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--project-ref", "a" * 20],
            capture_output=True, text=True, env=env, check=False
        )
        self.assertNotEqual(0, result.returncode)
        self.assertIn("SECURITY ADVISOR BLOCKED", result.stdout)

    def test_ci_runs_offline_tests_and_manual_live_check_only(self):
        source = (ROOT / ".github/workflows/vsp-supabase-security-advisor.yml").read_text()
        self.assertIn("workflow_dispatch:", source)
        self.assertIn("test/tooling/test_supabase_security_advisor.py", source)
        self.assertIn("SUPABASE_ADVISORS_READ_TOKEN", source)
        self.assertIn("github.event_name == 'workflow_dispatch'", source)

    def test_release_build_checks_live_advisor_before_signing(self):
        workflow = (ROOT / ".github/workflows/build-release-apk.yml").read_text()
        gate = workflow.find("scripts/check_release_security_gate.py")
        advisor = workflow.find("scripts/check_supabase_security_advisor.py")
        signing = workflow.find("Configure original Android release signing")
        self.assertTrue(0 <= gate < advisor < signing)
        self.assertIn("--strict-warnings", workflow)


if __name__ == "__main__":
    unittest.main()
