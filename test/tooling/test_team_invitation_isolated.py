import importlib.util
import os
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "vsp_team_invitation_runner",
    ROOT / "scripts/test_team_invitation_isolated.py",
)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Missing isolated team invitation runner")
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class TeamInvitationRunnerSafetyTest(unittest.TestCase):
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

    def test_extracts_only_the_expected_function_bodies(self):
        invite = runner.extract_function(runner.INVITE_MIGRATION, "invite_team_member(")
        respond = runner.extract_function(
            runner.RESPONSE_MIGRATION, "respond_team_membership_invitation("
        )
        self.assertIn("Only the captain can invite players", invite)
        self.assertIn("Invitation belongs to another player", respond)
        self.assertIn("pg_advisory_xact_lock", respond)
        self.assertNotIn("grant execute", respond.lower())

    def test_valid_fixture_target(self):
        runner.reject_nonlocal_targets(self.base)

    def test_psql_forces_loopback_and_discards_environment_redirects(self):
        unsafe = {
            **self.base,
            "PGHOSTADDR": "203.0.113.15",
            "PGSERVICE": "production",
            "PGSERVICEFILE": "/tmp/unsafe-service",
            "PGOPTIONS": "-c role=service_role",
        }
        with patch.dict(os.environ, unsafe, clear=True):
            with patch.object(
                runner.subprocess,
                "run",
                return_value=subprocess.CompletedProcess(["psql"], 0),
            ) as mocked:
                runner.run_psql("postgres", command="SELECT 1")
        argv = mocked.call_args.args[0]
        forwarded = mocked.call_args.kwargs["env"]
        for expected in ("--host=127.0.0.1", "--port=5432", "--username=postgres"):
            self.assertIn(expected, argv)
        for blocked in (
            "PGHOSTADDR", "PGSERVICE", "PGSERVICEFILE", "PGOPTIONS",
            "PGHOST", "PGUSER", "PGDATABASE", "PGPORT",
        ):
            self.assertNotIn(blocked, forwarded)


if __name__ == "__main__":
    unittest.main()
