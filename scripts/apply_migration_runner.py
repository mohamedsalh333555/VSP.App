#!/usr/bin/env python3
"""Legacy VSP migration runner: staging-only, explicitly opted in.

This script must NOT be used for production deployment, ambiguous migration
versions, rollback files, or unconstrained SQL scripts. Prefer the reviewed
Supabase migration pipeline instead. No database operation occurs on import.
"""

import argparse
import json
import os
from pathlib import Path
import re
import sys
import urllib.error
import urllib.request

STAGING_PROJECT_REF = "vtwgqyxglevcsxwdmhop"


def verified_migration_path(path: str, repository_root: Path) -> Path:
    """Reject paths outside migrations, rollback scripts and version collisions."""
    root = repository_root.resolve()
    directory = (root / "supabase" / "migrations").resolve()
    candidate = Path(path).expanduser().resolve()
    if candidate.parent != directory or not candidate.is_file():
        raise ValueError("Migration must be an existing, direct migrations/ SQL file")
    if candidate.name.endswith(".rollback.sql"):
        raise ValueError("Rollback scripts require a reviewed manual rollback plan")
    match = re.fullmatch(r"(\d{8,14})_[A-Za-z0-9_.-]+\.sql", candidate.name)
    if match is None:
        raise ValueError("Missing/invalid migration version in filename")
    version = match.group(1)
    conflicts = [
        p.name for p in directory.glob(f"{version}_*.sql")
        if not p.name.endswith(".rollback.sql")
    ]
    if conflicts != [candidate.name]:
        # Never auto-select among distinct files sharing a version ID.
        raise ValueError("Migration version is ambiguous; use reviewed tooling")
    return candidate


def verify_staging_opt_in(
    project_ref: str,
    confirmed_ref: str,
    environment: dict[str, str],
) -> None:
    if project_ref != STAGING_PROJECT_REF or confirmed_ref != STAGING_PROJECT_REF:
        raise ValueError("Refusing non-staging target or mismatched confirmation")
    if environment.get("VSP_ALLOW_STAGING_MIGRATION") != "1":
        raise ValueError("VSP_ALLOW_STAGING_MIGRATION=1 required")
    if environment.get("VSP_APPROVED_MIGRATION_REVIEW") != "1":
        raise ValueError("Approved staging migration review required")


def _management_key(repository_root: Path) -> str:
    key = os.environ.get("SUPABASE_MANAGEMENT_KEY", "").strip()
    if key:
        return key
    # Existing legacy support only: never log or return env.json contents.
    path = repository_root / "env.json"
    if path.exists():
        env = json.loads(path.read_text(encoding="utf-8"))
        key = str(env.get("SUPABASE_MANAGEMENT_KEY", "")).strip()
    if not key:
        raise ValueError("Staging management credential is not configured")
    return key


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("migration_file")
    parser.add_argument("--project-ref", required=True)
    parser.add_argument("--confirm-project-ref", required=True)
    args = parser.parse_args(argv)
    try:
        verify_staging_opt_in(
            args.project_ref, args.confirm_project_ref, dict(os.environ)
        )
        root = Path(__file__).resolve().parents[1]
        path = verified_migration_path(args.migration_file, root)
        # Read the selected file only after target and collision checks.
        sql = path.read_text(encoding="utf-8")
        if not sql.strip():
            raise ValueError("Empty migration is not deployable")
        token = _management_key(root)
        req = urllib.request.Request(
            f"https://api.supabase.com/v1/projects/{STAGING_PROJECT_REF}/database/query",
            data=json.dumps({"query": sql}).encode("utf-8"),
            headers={
                "Content-Type": "application/json",
                "Authorization": "Bearer " + token,
            },
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=30) as response:
            if response.status not in (200, 201):
                raise RuntimeError("Staging migration request rejected")
        print("Staging-only migration submitted successfully.")
        return 0
    except (ValueError, OSError, urllib.error.URLError, RuntimeError):
        # Avoid leaking remote SQL error bodies, service keys or project secrets.
        print("Migration refused or failed. Review staged safety checks.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
