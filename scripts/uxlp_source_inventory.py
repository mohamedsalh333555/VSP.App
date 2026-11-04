"""Reproduce full-file UXLP source triage without treating matches as defects/passes.

Run from the repository root:
  python scripts/uxlp_source_inventory.py > docs/UXLP_44_SOURCE_SCAN.json
This reads only registered source files; it never connects to application services.
"""

import hashlib
import json
from pathlib import Path
import re


def inventory(root):
    register = (root / 'docs/UXLP_44_SCREEN_REGISTER.md').read_text()
    rows = re.findall(
        r'^\| `(lib/[^`]+\.dart)` \| ([^|]+) \| ([^|]+) \|',
        register, re.MULTILINE,
    )
    patterns = {
        'palette_literal': r'\bColors\.(?:black|white|transparent|amber|redAccent|blue)\b',
        'physical_alignment': r'\bAlignment\.(?:centerLeft|centerRight|topLeft|topRight|bottomLeft|bottomRight)\b',
        'inline_motion_duration': r'duration:\s*(?:const\s+)?Duration\(milliseconds:\s*\d+\)',
    }
    files = []
    totals = dict.fromkeys(patterns, 0)
    for name in sorted({row[0] for row in rows}):
        path = root / name
        if not path.is_file():
            files.append({'path': name, 'missing': True})
            continue
        raw = path.read_bytes()
        source = raw.decode('utf-8')
        findings = []
        for category, pattern in patterns.items():
            for match in re.finditer(pattern, source):
                totals[category] += 1
                findings.append({
                    'category': category,
                    'line': source.count('\n', 0, match.start()) + 1,
                    'match': match.group(),
                })
        files.append({
            'path': name,
            'sha256': hashlib.sha256(raw).hexdigest(),
            'lines': len(source.splitlines()),
            'triage_matches': sorted(findings, key=lambda item: item['line']),
        })
    return {
        'scope': 'Full contents of unique Dart paths in the register table',
        'limitations': [
            'Static pattern matches require contextual review; they are not proven UX defects.',
            'Physical alignment may be intentional (e.g. gradients or locale-aware branches).',
            'No runtime, screen-state coverage, contrast or rule pass is established.',
            'Unregistered surfaces and other kinds of design literals are not covered.',
        ],
        'register_rows': len(rows),
        'unique_paths': len(files),
        'missing_paths': sum(item.get('missing', False) for item in files),
        'match_counts': totals,
        'files': files,
    }


if __name__ == '__main__':
    print(json.dumps(inventory(Path(__file__).resolve().parents[1]), ensure_ascii=False, indent=2))
