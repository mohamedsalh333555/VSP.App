#!/usr/bin/env python3
"""Read-only inventory of possible neon aliases, green literals and glow opt-ins.
Each match needs context review; a candidate is not automatically a violation.
"""
import argparse
import json
import re
from pathlib import Path

PATTERNS = {
    "neon_alias": re.compile(r"\b(?:VSPColors\.(?:accent|primary|proAccent)|VSPDSSemanticColors\.accent|VSPDSColors\.(?:voltGreen|homeAmbientGlow))\b"),
    "theme_alias": re.compile(r"\b(?:colorScheme\.(?:primary|secondary)|primaryColor)\b"),
    "material_green": re.compile(r"\bColors\.(?:green|greenAccent|lightGreen|lightGreenAccent|lime|limeAccent)\b"),
    "ambient_opt_in": re.compile(r"\b(?:showTopGlow|showBottomGlow|glowColor)\s*:"),
    "literal": re.compile(r"\bColor\s*\(\s*0x([0-9a-fA-F]{8})\s*\)"),
}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    files = sorted((args.root / "lib").rglob("*.dart"))
    if not files:
        parser.error("no Flutter source files found")
    rows = []
    for file in files:
        for line_no, line in enumerate(file.read_text(encoding="utf-8").splitlines(), 1):
            if line.lstrip().startswith(("//", "*")):
                continue
            for kind, pattern in PATTERNS.items():
                for match in pattern.finditer(line):
                    if kind == "literal":
                        value = int(match.group(1), 16)
                        red, green, blue = (value >> 16) & 255, (value >> 8) & 255, value & 255
                        if not (green > red and green > blue):
                            continue
                    rows.append({"path": file.relative_to(args.root).as_posix(), "line": line_no, "kind": kind, "match": match.group(0)})
    counts = {kind: sum(row["kind"] == kind for row in rows) for kind in PATTERNS}
    print(json.dumps({"scanned_files": len(files), "counts": counts, "candidates": rows}, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
