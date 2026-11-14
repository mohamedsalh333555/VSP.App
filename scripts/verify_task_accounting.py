#!/usr/bin/env python3
"""Read-only consistency check for VSP's active 618-subtask execution scope.

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
    if len(ids) != 618 or len(set(ids)) != 618:
        errors.append("The active scope must contain exactly 618 unique subtask IDs.")
    if len(plan_ids) != len(ids) or set(plan_ids) != set(ids):
        errors.append("The execution plan loses, duplicates, or adds core subtask IDs.")
    if len({task_id.split('.')[0] for task_id in ids}) != 82:
        errors.append("Expected 82 active parent items.")
    if any(task_id.startswith("56.") for task_id in ids + plan_ids):
        errors.append("Cancelled group 56 must not reappear in the active scope.")
    if not all(f"83.{index:02d}" in ids for index in range(1, 8)):
        errors.append("The seven screenshot-triage tasks in group 83 are missing.")
    accepted = sum(mark == "x" for mark, _ in rows)
    match = re.search(r"^## .*?\((\d+)/(\d+)\)\s*$", ledger, re.M)
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
