#!/usr/bin/env python3
"""Read-only Supabase Security Advisor release guard.

The Management API endpoint is experimental. Fail closed if access, response shape,
severity or the advisor itself is unavailable. Do not log finding metadata, tokens,
raw HTTP responses, user records, or database contents.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import urllib.error
import urllib.request

MAX_RESPONSE_BYTES = 4 * 1024 * 1024
PROJECT_REF_RE = re.compile(r"[a-z]{20}\Z")
LEVELS = {"ERROR", "WARN", "INFO"}
ADVISOR_UNAVAILABLE = {"advisor_check_unavailable", "db_not_reachable", "db_connection_failing"}


def summarize(payload: object, *, strict_warnings: bool = False) -> dict:
    if not isinstance(payload, dict) or not isinstance(payload.get("lints"), list):
        raise ValueError("invalid_security_advisor_response")
    counts = {"ERROR": 0, "WARN": 0, "INFO": 0}
    rule_counts: dict[tuple[str, str], int] = {}
    unavailable = False
    for lint in payload["lints"]:
        if not isinstance(lint, dict):
            raise ValueError("invalid_security_advisor_finding")
        name, level = lint.get("name"), lint.get("level")
        if not isinstance(name, str) or not name.strip() or level not in LEVELS:
            raise ValueError("invalid_security_advisor_finding")
        count = lint.get("count", 1)
        if isinstance(count, bool) or not isinstance(count, int) or count < 1:
            raise ValueError("invalid_security_advisor_count")
        counts[level] += count
        rule_counts[(name, level)] = rule_counts.get((name, level), 0) + count
        unavailable |= name in ADVISOR_UNAVAILABLE
    blocked = bool(counts["ERROR"] or unavailable or (strict_warnings and counts["WARN"]))
    return {
        "status": "BLOCKED" if blocked else "PASS_WITH_WARNINGS" if counts["WARN"] else "PASS",
        "counts": counts,
        "advisors_unavailable": unavailable,
        "strict_warnings": strict_warnings,
        "rules": [
            {"name": name, "level": level, "count": count}
            for (name, level), count in sorted(rule_counts.items())
        ],
    }


def fetch_advisors(project_ref: str, token: str, *, opener=urllib.request.urlopen) -> dict:
    if not PROJECT_REF_RE.fullmatch(project_ref):
        raise ValueError("invalid_project_ref")
    if not isinstance(token, str) or not token.strip():
        raise ValueError("missing_read_only_advisors_token")
    url = f"https://api.supabase.com/v1/projects/{project_ref}/advisors/security"
    request = urllib.request.Request(
        url, headers={"Authorization": f"Bearer {token}", "Accept": "application/json"}
    )
    with opener(request, timeout=20) as response:
        body = response.read(MAX_RESPONSE_BYTES + 1)
    if len(body) > MAX_RESPONSE_BYTES:
        raise ValueError("security_advisor_response_too_large")
    try:
        parsed = json.loads(body)
    except (ValueError, UnicodeDecodeError) as exc:
        raise ValueError("invalid_security_advisor_json") from exc
    if not isinstance(parsed, dict):
        raise ValueError("invalid_security_advisor_response")
    return parsed


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--project-ref", default=os.environ.get("VSP_SUPABASE_ADVISOR_PROJECT_REF", "")
    )
    parser.add_argument("--strict-warnings", action="store_true")
    args = parser.parse_args(argv)
    token = os.environ.get("SUPABASE_ADVISORS_READ_TOKEN", "")
    try:
        result = summarize(
            fetch_advisors(args.project_ref, token),
            strict_warnings=args.strict_warnings,
        )
    except urllib.error.HTTPError as exc:
        print(f"SECURITY ADVISOR BLOCKED: management_api_http_{exc.code}")
        return 1
    except (urllib.error.URLError, TimeoutError, OSError):
        print("SECURITY ADVISOR BLOCKED: management_api_unavailable")
        return 1
    except ValueError as exc:
        print(f"SECURITY ADVISOR BLOCKED: {exc}")
        return 1
    # Only rule names and counts: never print a finding's description or metadata.
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 1 if result["status"] == "BLOCKED" else 0


if __name__ == "__main__":
    raise SystemExit(main())
