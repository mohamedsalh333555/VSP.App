#!/usr/bin/env python3
"""Read-only byte/line comparisons of every colliding migration version.

Does not infer deployment order, execute SQL, rename versions or compare SQL
semantics. --version VERSION --full-diff includes complete textual diffs.
"""
import argparse
import difflib
import hashlib
import itertools
import json
import re
from collections import defaultdict
from pathlib import Path


def compare(root, version=None, full_diff=False):
    groups = defaultdict(list)
    rollback = []
    unversioned = []
    forward = 0
    for path in sorted((root / 'supabase/migrations').glob('*.sql')):
        if path.name.endswith('.rollback.sql'):
            rollback.append(path.name)
            continue
        match = re.match(r'^(\d+)_', path.name)
        if not match:
            unversioned.append(path.name)
            continue
        forward += 1
        groups[match[1]].append(path)
    collisions = []
    for prefix, paths in sorted(groups.items()):
        if len(paths) < 2 or (version and prefix != version):
            continue
        files = []
        contents = {}
        for path in paths:
            raw = path.read_bytes()
            # keepends preserves newline-only differences in the comparison.
            lines = raw.decode('utf-8').splitlines(keepends=True)
            contents[path.name] = lines
            files.append({'file': path.name, 'bytes': len(raw),
                          'sha256': hashlib.sha256(raw).hexdigest(),
                          'lines': len(lines)})
        pairs = []
        for left, right in itertools.combinations(files, 2):
            before, after = contents[left['file']], contents[right['file']]
            operations = difflib.SequenceMatcher(None, before, after,
                                                 autojunk=False).get_opcodes()
            added = sum(j2 - j1 for op, i1, i2, j1, j2 in operations
                        if op in ('insert', 'replace'))
            removed = sum(i2 - i1 for op, i1, i2, j1, j2 in operations
                          if op in ('delete', 'replace'))
            pair = {'left': left['file'], 'right': right['file'],
                    'byte_identical': left['sha256'] == right['sha256'],
                    'added_lines': added, 'removed_lines': removed}
            if full_diff:
                pair['unified_diff'] = ''.join(difflib.unified_diff(
                    before, after, fromfile=left['file'], tofile=right['file']))
            pairs.append(pair)
        collisions.append({'version': prefix, 'files': files, 'pairs': pairs})
    return {'scope': 'forward SQL files; exact bytes and all pairwise line comparisons',
            'forward_files': forward, 'distinct_versions': len(groups),
            'excluded_rollback_files': rollback, 'unversioned_files': unversioned,
            'collision_groups': collisions,
            'limits': 'Textual differences are not SQL semantic equivalence, an execution plan, or evidence of applied migration history.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--version')
    parser.add_argument('--full-diff', action='store_true')
    args = parser.parse_args()
    result = compare(Path(__file__).resolve().parents[1], args.version, args.full_diff)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
