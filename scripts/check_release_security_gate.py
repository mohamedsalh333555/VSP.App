#!/usr/bin/env python3
"""Fail-closed source-controlled security acceptance gate for VSP release builds.

This gate checks a reviewed *declaration*, not the live Supabase advisor.
Independent advisor and sandbox tests must supply evidence before approval.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


def blockers(state: object, code_sha: str) -> list[str]:
    if not re.fullmatch(r"[a-f0-9]{40}", code_sha):
        return ["invalid_release_sha"]
    if not isinstance(state, dict) or state.get("schema_version") != 1:
        return ["unrecognized_release_gate_state"]
    errors: list[str] = []
    if state.get("status") != "approved":
        errors.append("security_release_not_approved")
    if state.get("reviewed_code_sha") != code_sha:
        errors.append("security_review_does_not_match_code")
    critical = state.get("open_critical_findings")
    if not isinstance(critical, list) or critical:
        errors.append("critical_findings_not_cleared")
    evidence = state.get("evidence_urls")
    if not isinstance(evidence, list) or not evidence or any(
        not isinstance(link, str) or not link.startswith("https://")
        for link in evidence
    ):
        errors.append("required_review_evidence_missing")
    if not isinstance(state.get("reviewer"), str) or not state["reviewer"].strip():
        errors.append("reviewer_not_identified")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--state", type=Path, required=True)
    parser.add_argument("--sha", required=True)
    args = parser.parse_args()
    try:
        obj = json.loads(args.state.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        print("RELEASE BLOCKED: security_release_state_missing_or_invalid")
        return 1
    reasons = blockers(obj, args.sha)
    if reasons:
        print("RELEASE BLOCKED: " + ", ".join(reasons))
        return 1
    print("Release security declaration matches checked-out SHA; other CI gates still apply.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
