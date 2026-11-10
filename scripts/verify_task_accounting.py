#!/usr/bin/env python3
"""Read-only consistency check for VSP's fixed 620-subtask execution scope.

This checks inventory/accounting only. It never promotes code or tests to VERIFIED.
"""
import json
import re
from pathlib import Path


def main():
    root = Path(__file__).resolve().parents[1]
    source = (root / "docs/VSP_80_DETAILED_SUBTASK_BREAKDOWN.md").read_text()
    plan = (root / "docs/VSP_UNIFIED_EXECUTION_PLAN_V2.md").read_text()
    ledger = (root / "docs/VSP_LIVE_DELIVERY_LEDGER.md").read_text()
    rows = re.findall(r"^- \[([ x])\] (\d{2}\.\d{2}) —", source, re.M)
    ids = [task_id for _, task_id in rows]
    plan_ids = re.findall(r"^- (\d{2}\.\d{2}) —", plan, re.M)
    errors = []
    if len(ids) != 620 or len(set(ids)) != 620:
        errors.append("The fixed scope must contain exactly 620 unique subtask IDs.")
    if len(plan_ids) != len(ids) or set(plan_ids) != set(ids):
        errors.append("The execution plan loses, duplicates, or adds core subtask IDs.")
    if len({task_id.split('.')[0] for task_id in ids}) != 82:
        errors.append("Expected 82 original parent items.")
    accepted = sum(mark == "x" for mark, _ in rows)
    match = re.search(r"Current inventory: \*\*(\d+) verified; (\d+) not yet accepted", ledger)
    if not match or tuple(map(int, match.groups())) != (accepted, len(ids) - accepted):
        errors.append("Ledger current inventory does not match the detailed checklist.")
    result = {
        "scope": "core_subtasks_only",
        "total": len(ids),
        "unique_ids": len(set(ids)),
        "parent_items": len({task_id.split('.')[0] for task_id in ids}),
        "accepted_checklist_entries": accepted,
        "not_accepted": len(ids) - accepted,
        "errors": errors,
        "limits": "Counts preserve historical acceptance, including documentation. They do not prove runtime readiness or audit evidence validity.",
    }
    print(json.dumps(result, indent=2))
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
