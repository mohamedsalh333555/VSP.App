#!/usr/bin/env python3
"""Read-only consistency check for VSP's 632 active + 8 retired subtasks.

Historic inventory is 640 unique IDs: 633 legacy + 7 Phase 10.
This checks inventory/accounting only. Retired is never accepted.
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
    expected_retired = [f"43.{i:02d}" for i in range(1, 9)]
    archived_source = re.findall(r"^- ~~(43\.\d{2}) —", source, re.M)
    archived_plan = re.findall(r"^- ~~(43\.\d{2}) —", plan, re.M)
    if sorted(archived_source) != expected_retired or sorted(archived_plan) != expected_retired:
        errors.append("Retired historical IDs 43.01-43.08 must appear once in both inventories.")
    if set(archived_source) & set(ids):
        errors.append("Retired IDs must not be counted as active.")
    if len(ids) != 632 or len(set(ids)) != 632:
        errors.append("The active scope must contain exactly 632 unique subtask IDs.")
    original = [task_id for task_id in ids if not task_id.startswith("86.")]
    if len(original) != 625 or len(set(original)) != 625:
        errors.append("Original active IDs must be 633 - 8 retired = 625.")
    if sorted(task_id for task_id in ids if task_id.startswith("86.")) != [f"86.{i:02d}" for i in range(1, 8)]:
        errors.append("The seven new Phase 10 task IDs must be exactly 86.01-86.07.")
    if len(plan_ids) != len(ids) or set(plan_ids) != set(ids):
        errors.append("The execution plan loses, duplicates, or adds core subtask IDs.")
    if len({task_id.split('.')[0] for task_id in ids}) != 84:
        errors.append("Expected 84 active parent items.")
    if any(task_id.startswith("56.") for task_id in ids + plan_ids):
        errors.append("Cancelled group 56 must not reappear in the active scope.")
    if not all(f"83.{index:02d}" in ids for index in range(1, 8)):
        errors.append("The seven screenshot-triage tasks in group 83 are missing.")
    if not all(f"84.{index:02d}" in ids for index in range(1, 13)):
        errors.append("The twelve deduplicated RESULT tasks in group 84 are missing.")
    if not all(f"85.{index:02d}" in ids for index in range(1, 4)):
        errors.append("The three independent Storage advisory audits in group 85 are missing.")
    accepted = sum(mark == "x" for mark, _ in rows)
    match = re.search(r"^## .*?\((\d+)/(\d+)\)\s*$", ledger, re.M)
    if not match or tuple(map(int, match.groups())) != (accepted, len(ids) - accepted):
        errors.append("Ledger current inventory does not match the detailed checklist.")
    result = {
        "scope": "core_subtasks_only",
        "total": len(ids),
        "historic_total": len(ids) + len(archived_source),
        "retired": len(archived_source),
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
