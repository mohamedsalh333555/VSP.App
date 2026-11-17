import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/check_release_security_gate.py"
spec = importlib.util.spec_from_file_location("release_gate", SCRIPT)
assert spec and spec.loader
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
SHA = "a" * 40


def approved():
    return {"schema_version": 1, "status": "approved", "reviewed_code_sha": SHA,
            "reviewer": "ci-fixture-reviewer", "open_critical_findings": [],
            "evidence_urls": ["https://example.test/security-test-evidence"]}


class ReleaseSecurityGateTest(unittest.TestCase):
    def test_valid_scoped_fixture(self):
        self.assertEqual([], module.blockers(approved(), SHA))

    def test_open_critical_blocks(self):
        fixture = approved()
        fixture["open_critical_findings"] = ["P0-synthetic"]
        self.assertIn("critical_findings_not_cleared", module.blockers(fixture, SHA))

    def test_missing_or_unreviewed_gate_blocks(self):
        for item in [None, {}, {"schema_version": 1, "status": "hold"}]:
            self.assertNotEqual([], module.blockers(item, SHA))

    def test_commit_drift_blocks(self):
        self.assertIn("security_review_does_not_match_code",
                      module.blockers(approved(), "b" * 40))

    def test_missing_evidence_or_reviewer_blocks(self):
        obj = approved()
        obj["evidence_urls"] = []
        obj["reviewer"] = None
        errs = module.blockers(obj, SHA)
        self.assertIn("required_review_evidence_missing", errs)
        self.assertIn("reviewer_not_identified", errs)

    def test_invalid_sha_fails_closed(self):
        self.assertEqual(["invalid_release_sha"], module.blockers(approved(), "not-a-sha"))

    def test_cli_fail_closed_with_bad_json(self):
        with tempfile.TemporaryDirectory() as d:
            state = Path(d) / "state.json"
            state.write_text("{not-json", encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "--state", str(state), "--sha", SHA],
                capture_output=True, text=True, check=False)
            self.assertNotEqual(0, result.returncode)
            self.assertIn("RELEASE BLOCKED", result.stdout)

    def test_actual_state_defaults_to_hold(self):
        state = json.loads((ROOT / "docs/security/VSP_RELEASE_GATE_STATE.json").read_text())
        self.assertIn("security_release_not_approved", module.blockers(state, SHA))

    def test_financial_schema_deployment_preconditions_keep_release_blocked(self):
        state = json.loads((ROOT / "docs/security/VSP_RELEASE_GATE_STATE.json").read_text())
        findings = "\\n".join(state["open_critical_findings"])
        self.assertIn("20261117173000", findings)
        self.assertIn("20261117174500", findings)
        self.assertEqual("hold", state["status"])
        self.assertIn("critical_findings_not_cleared", module.blockers(state, SHA))

    def test_build_workflow_blocks_before_build_and_signing(self):
        source = (ROOT / ".github/workflows/build-release-apk.yml").read_text()
        gate = source.find("python3 scripts/check_release_security_gate.py")
        signing = source.find("Configure original Android release signing")
        build = source.find("Build signed Release APK")
        self.assertTrue(0 <= gate < signing < build)


if __name__ == "__main__":
    unittest.main()
