#!/usr/bin/env python3
"""Narrow rewrite of reviewed pg_policies expressions, preserving ownership arms."""
import json
import re
import sys
from pathlib import Path

DIRECT = re.compile(r"(?P<alias>u|users)\.role = (?P<comparison>ANY \(ARRAY\[[^\]]+\]\)|'admin'::text)")
SCALAR = re.compile(r'SELECT users\.role(?=\s+FROM users)')
ADMIN_ROLES = "'admin','co_founder','cofounder','super_admin'"


def restrict_expression(expression):
    if expression is None:
        return None
    if 'is_blocked' in expression or 'is_admin_or_cofounder' in expression:
        raise ValueError('Already guarded policy requires separate review')
    changes = 0

    def direct(match):
        nonlocal changes
        if "'admin'::text" not in match.group(0):
            return match.group(0)
        changes += 1
        alias = match['alias']
        active = f'COALESCE({alias}.is_blocked, false) = false'
        if "'owner'::text" in match.group(0):
            active = f'({alias}.role NOT IN ({ADMIN_ROLES}) OR {active})'
        return f'({match.group(0)} AND {active})'

    updated = DIRECT.sub(direct, expression)
    # These reviewed scalar subqueries only feed admin-role membership tests.
    updated, count = SCALAR.subn('SELECT CASE WHEN COALESCE(users.is_blocked, false) THEN NULL::text ELSE users.role END', updated)
    changes += count
    if not changes or 'auth.uid()' not in expression:
        raise ValueError('Unrecognized policy expression; manual review required')
    return updated


def build_plan(inputs):
    result = []
    for origin, policies in inputs.items():
        for p in policies:
            combined = (p['qual'] or '') + (p['with_check'] or '')
            if 'admin' not in combined or 'is_blocked' in combined or 'is_admin_or_cofounder' in combined:
                continue
            item = {**p, 'after_qual': restrict_expression(p['qual']),
                    'after_check': restrict_expression(p['with_check']), 'origin': origin}
            result.append(item)
    return result


if __name__ == '__main__':
    plan = build_plan(json.loads(Path(sys.argv[1]).read_text()))
    Path(sys.argv[2]).write_text(json.dumps(plan, indent=2) + '\n')
    print(json.dumps({'source_variants': len(plan), 'policies': len({(p['schemaname'],p['tablename'],p['policyname']) for p in plan})}))
