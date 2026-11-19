#!/usr/bin/env python3
"""Read-only inventory of source-level S3 presigned PUT and signed resumable uploads.

This detects review indicators, not exploitability or hosted Storage versions.
It never reads Storage objects, credentials or customer data; it prints only
source-relative file paths, line numbers and risk categories (no code snippets).
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re

SOURCE_PREFIXES = (
    "lib/", "supabase/functions/", "functions/", "web/",
    "ios/Runner/", "android/app/src/", "scripts/",
)
ROOT_FILES = {"pubspec.yaml", "package.json", "supabase/config.toml"}
SUFFIXES = {".dart", ".ts", ".tsx", ".js", ".jsx", ".py", ".go", ".java",
            ".kt", ".swift", ".yaml", ".yml", ".toml", ".json", ".html"}
EXCLUDE_NAMES = {"audit_storage_upload_routes.py"}
RULES = {
    "s3_presigned_put": re.compile(
        r"(?:\b(?:PutObjectCommand|putObject\s*\(|generate_presigned_url|"
        r"presigned[_-]?put|createPresignedPost|x-amz-copy-source|"
        r"S3Client|s3v4|boto3\.client\(['\"]s3)|/storage/v1/s3)",
        re.IGNORECASE,
    ),
    "signed_resumable_upload": re.compile(
        r"(?:\b(?:createSignedUploadUrl|uploadToSignedUrl|tus-js-client|"
        r"tus\.Upload|Upload-Token|x-upsert)|"
        r"/upload/resumable|/storage/v1/upload/resumable)",
        re.IGNORECASE,
    ),
}


def is_application_source(relative: str) -> bool:
    path = Path(relative)
    if path.name in EXCLUDE_NAMES or path.suffix.lower() not in SUFFIXES:
        return False
    if relative not in ROOT_FILES and not relative.startswith(SOURCE_PREFIXES):
        return False
    parts = path.parts
    if "test" in parts or "tests" in parts or path.name.startswith("test_"):
        return False
    if path.name.endswith(("_test.dart", "_test.ts", ".g.dart", ".freezed.dart")):
        return False
    return True


def inspect_source(relative: str, content: str) -> list[dict[str, object]]:
    if not is_application_source(relative):
        return []
    findings: list[dict[str, object]] = []
    for line_number, line in enumerate(content.splitlines(), 1):
        for category, rule in RULES.items():
            if rule.search(line):
                findings.append({"path": relative, "line": line_number, "category": category})
    return findings


def audit(root: Path) -> dict[str, object]:
    if not root.is_dir():
        raise ValueError("audit_root_missing")
    findings: list[dict[str, object]] = []
    scanned = 0
    for folder in SOURCE_PREFIXES:
        base = root / folder
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*")):
            if not path.is_file() or path.is_symlink():
                continue
            relative = path.relative_to(root).as_posix()
            if not is_application_source(relative):
                continue
            scanned += 1
            # Only inspect source; don't show its contents in logs or report.
            findings.extend(inspect_source(relative, path.read_text(encoding="utf-8", errors="replace")))
    for item in sorted(ROOT_FILES):
        path = root / item
        if path.is_file() and is_application_source(item):
            scanned += 1
            findings.extend(inspect_source(item, path.read_text(encoding="utf-8", errors="replace")))
    findings.sort(key=lambda x: (str(x["path"]), int(x["line"]), str(x["category"])))
    counts = {name: sum(f["category"] == name for f in findings) for name in RULES}
    return {
        "schema_version": 1,
        "scope": "source_code_only",
        "status": "review_required" if findings else "no_matching_source_indicators",
        "files_scanned": scanned,
        "counts": counts,
        "findings": findings,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--output", type=Path)
    parser.add_argument("--strict", action="store_true", help="fail when any review indicator exists")
    args = parser.parse_args(argv)
    try:
        report = audit(args.root)
    except (OSError, ValueError) as exc:
        print("STORAGE AUDIT ERROR: " + type(exc).__name__)
        return 2
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    # No source snippets, signing material, token values or Storage object names.
    print(json.dumps({key: report[key] for key in
                      ("scope", "status", "files_scanned", "counts")}, sort_keys=True))
    return 1 if args.strict and report["findings"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
