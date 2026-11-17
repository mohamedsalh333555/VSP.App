#!/usr/bin/env python3
"""Run actual staging Paymob ledger RPC in disposable localhost PostgreSQL."""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import sys
from test_team_skills_rls_isolated import psql,reject_nonlocal_targets
ROOT=Path(__file__).resolve().parents[1]
SNAPSHOT=ROOT/"docs/security/sql/record_booking_payment_atomic_staging_source_2026-11-17.sql"
FIXTURE=ROOT/"supabase/tests/paymob_transaction_booking_binding_isolated_contract.sql"
DB="vsp_paymob_transaction_binding_isolated"

def main()->int:
    reject_nonlocal_targets(dict(os.environ))
    source=SNAPSHOT.read_text(encoding="utf-8")
    if "transaction_already_bound_to_other_booking" not in source or "record_booking_payment_atomic(" not in source:
        raise RuntimeError("Staging source signature drift")
    fixture=FIXTURE.read_text(encoding="utf-8")
    marker="-- ACTUAL_STAGING_PAYMENT_LEDGER_RPC"
    if fixture.count(marker)!=1:raise RuntimeError("Missing source marker")
    fixture=fixture.replace(marker,source)
    created=psql("postgres",command="CREATE DATABASE "+DB)
    if created.returncode:raise RuntimeError("Fresh localhost test database required")
    try:
        result=psql(DB,sql=fixture)
        if result.returncode:
            print("PAYMOB_TXN_BINDING_FAIL: "+result.stderr[-3500:],file=sys.stderr)
            return 1
        print("PASS: initial payment, same-booking replay, cross-booking txn ID denial, user and gross mismatch")
        return 0
    finally:
        removed=psql("postgres",command="DROP DATABASE IF EXISTS "+DB+" WITH (FORCE)")
        if removed.returncode:raise RuntimeError("Test database cleanup failed")

if __name__=="__main__":
    try:raise SystemExit(main())
    except (RuntimeError,OSError,subprocess.TimeoutExpired) as exc:
        print("PAYMOB_TXN_BINDING_ERROR: "+str(exc),file=sys.stderr)
        raise SystemExit(1)
