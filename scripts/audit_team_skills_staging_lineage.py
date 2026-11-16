#!/usr/bin/env python3
"""Read-only local Team Skills migration lineage inventory check.

The manifest records staging migration versions which differ from the repo's
filename versions because the migration tool assigned timestamps. This check
NEVER connects to Supabase, repairs history or decides SQL body parity.
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
FILE = ROOT / "docs/team_skills_staging_migration_lineage.json"
MIGRATIONS = ROOT / "supabase/migrations"
FILENAME = re.compile(r"^(\d{14})_(team_skills_[a-z0-9_]+)\.sql$")
VERSION = re.compile(r"^\d{14}$")


def audit() -> int:
    manifest = json.loads(FILE.read_text(encoding="utf-8"))
    if manifest.get("kind") != "read_only_staging_migration_lineage_snapshot":
        raise ValueError("Unknown migration audit manifest kind")
    entries = manifest.get("migrations")
    if not isinstance(entries, list) or not entries:
        raise ValueError("Missing Team Skills migration provenance entries")

    paths = sorted(
        p.relative_to(ROOT).as_posix()
        for p in MIGRATIONS.glob("*_team_skills_*.sql")
        if FILENAME.fullmatch(p.name)
    )
    recorded = [x["local_file"] for x in entries]
    missing = sorted(set(paths) - set(recorded))
    stale = sorted(set(recorded) - set(paths))
    if missing or stale:
        raise ValueError(f"Lineage snapshot mismatch: unmapped={missing}, missing_source={stale}")
    if len(recorded) != len(set(recorded)) or recorded != sorted(recorded):
        raise ValueError("Source files repeated or in wrong chronological order")

    versions = []
    for entry in entries:
        filename = Path(entry["local_file"]).name
        match = FILENAME.fullmatch(filename)
        if match is None:
            raise ValueError(f"Unexpected source filename: {filename}")
        version = entry["staging_version"]
        name = entry["staging_migration_name"]
        if not isinstance(version, str) or VERSION.fullmatch(version) is None:
            raise ValueError(f"Unexpected staging migration version: {version}")
        # Original tools used a _YYYYMMDD suffix on the server migration name.
        if name != match.group(2) + "_20261116":
            raise ValueError(f"Staging migration slug does not match file: {filename}")
        versions.append(version)
    if versions != sorted(set(versions)):
        raise ValueError("Staging versions are duplicated or out of applied order")
    print(f"PASS: {len(entries)} repo migrations have unique staging provenance records")
    print("WARNING: SQL parity, production deployment and history reconciliation remain unverified")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(audit())
    except (ValueError, KeyError, OSError, TypeError, json.JSONDecodeError) as exc:
        print("TEAM_SKILLS_LINEAGE_AUDIT_ERROR: " + str(exc), file=sys.stderr)
        raise SystemExit(1)
