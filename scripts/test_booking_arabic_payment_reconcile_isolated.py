#!/usr/bin/env python3
"""Verify live-source booking payment matrix in disposable local PostgreSQL."""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import sys
from test_team_skills_rls_isolated import psql,reject_nonlocal_targets
ROOT=Path(__file__).resolve().parents[1]
FIXTURE=ROOT/"supabase/tests/booking_arabic_payment_reconcile_isolated_contract.sql"
MIGRATION=ROOT/"supabase/migrations/20261117072000_normalize_arabic_payment_methods_and_block_unpaid_wallet.sql"
DB="vsp_payment_arabic_method_matrix_isolated"
def main()->int:
    reject_nonlocal_targets(dict(os.environ))
    sql=FIXTURE.read_text(encoding="utf-8")
    marker="-- ACTUAL_ARABIC_PAYMENT_NORMALIZATION_MIGRATION"
    if sql.count(marker)!=1:raise RuntimeError("Missing unique source marker")
    sql=sql.replace(marker,MIGRATION.read_text(encoding="utf-8"))
    created=psql("postgres",command="CREATE DATABASE "+DB)
    if created.returncode:raise RuntimeError("Fresh isolated PostgreSQL DB required")
    try:
        result=psql(DB,sql=sql)
        if result.returncode:
            print("ARABIC_PAYMENT_MATRIX_FAIL: "+result.stderr[-3800:],file=sys.stderr)
            return 1
        print("PASS: Arabic wallet/cash/card source, unpaid electronic denial, legacy transition, paid approval and refund precedence")
        return 0
    finally:
        removed=psql("postgres",command="DROP DATABASE IF EXISTS "+DB+" WITH (FORCE)")
        if removed.returncode:raise RuntimeError("Could not clean up isolated PostgreSQL DB")
if __name__=="__main__":
    try:raise SystemExit(main())
    except (RuntimeError,OSError,subprocess.TimeoutExpired) as exc:
        print("ARABIC_PAYMENT_MATRIX_ERROR: "+str(exc),file=sys.stderr)
        raise SystemExit(1)
