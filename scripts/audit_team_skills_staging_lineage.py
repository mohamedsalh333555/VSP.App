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
    # Brand-new checked-in migrations may be intentionally unapplied.
    # Never manufacture a staging version or present them as deployed.
    unapplied = manifest.get("unapplied_source_files", [])
    if not isinstance(unapplied, list) or any(
        not isinstance(path, str) for path in unapplied
    ):
        raise ValueError("Unapplied source list is malformed")
    if len(unapplied) != len(set(unapplied)) or unapplied != sorted(unapplied):
        raise ValueError("Unapplied migrations repeat or are unordered")
    if set(recorded) & set(unapplied):
        raise ValueError("A migration cannot be staged and unapplied simultaneously")
    missing = sorted(set(paths) - set(recorded) - set(unapplied))
    stale = sorted((set(recorded) | set(unapplied)) - set(paths))
    if missing or stale:
        raise ValueError(f"Lineage snapshot mismatch: unmapped={missing}, missing_source={stale}")
    if len(recorded) != len(set(recorded)) or recorded != sorted(recorded):
        raise ValueError("Source files repeated or in wrong chronological order")

    versions = []
    source_versions = []
    staging_names = []
    for entry in entries:
        filename = Path(entry["local_file"]).name
        match = FILENAME.fullmatch(filename)
        if match is None:
            raise ValueError(f"Unexpected source filename: {filename}")
        version = entry["staging_version"]
        name = entry["staging_migration_name"]
        if not isinstance(version, str) or VERSION.fullmatch(version) is None:
            raise ValueError(f"Unexpected staging migration version: {version}")
        # Server migration names end in the source's own YYYYMMDD date;
        # older sources are 20261116 and this batch adds a 20261117 entry.
        # Real staging history contains both the legacy day-suffixed names
        # and later exact-slug names. Require one of those TWO concrete
        # variants: a fabricated or unrelated migration name must still fail.
        valid_names = {match.group(2), match.group(2) + "_" + match.group(1)[:8]}
        if name not in valid_names:
            raise ValueError(f"Staging migration slug does not match file: {filename}")
        versions.append(version)
        source_versions.append(match.group(1))
        staging_names.append(name)
    if len(source_versions) != len(set(source_versions)):
        raise ValueError("Duplicate source migration timestamps would break a CLI rollout")
    if len(versions) != len(set(versions)) or len(staging_names) != len(set(staging_names)):
        raise ValueError("Staging versions or migration names are duplicated")
    # Supabase MCP generated an independent staging timestamp for each apply.
    # Their application order can differ from the sorted GitHub filenames;
    # do not reject correct provenance merely because those orders differ.
    print(f"PASS: {len(entries)} recorded staging migrations and {len(unapplied)} explicitly unapplied source migrations")
    print("UNAPPLIED (not deployed): " + (", ".join(unapplied) if unapplied else "none"))
    print("WARNING: SQL parity, production deployment and history reconciliation remain unverified")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(audit())
    except (ValueError, KeyError, OSError, TypeError, json.JSONDecodeError) as exc:
        print("TEAM_SKILLS_LINEAGE_AUDIT_ERROR: " + str(exc), file=sys.stderr)
        raise SystemExit(1)
