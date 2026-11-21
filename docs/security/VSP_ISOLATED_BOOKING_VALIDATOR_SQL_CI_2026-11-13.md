# Isolated PostgreSQL regression gate for booking-window validator

Date: 2026-11-13. GitHub branch `uxlp-44-implementation`. **Do not claim runtime pass until GitHub Action succeeds at this commit.**

The existing `Account SQL security contracts` workflow provisions a local PostgreSQL 17.6 Alpine service for ephemeral tests. Added a bounded, dependency-free Python runner (`scripts/test_booking_window_function_isolated.py`) that refuses execution without `VSP_CONTRACT_ISOLATED=1`, a loopback `PGHOST`, port 5432 and the exact database name `vsp_security_contracts`. Unit tests check all four guard conditions before any database connection.

The runner extracts *only* `vsp_validate_stadium_booking_window` definitions (not whole migration scripts), then:

1. Starts a transaction with the original checked-in validator and executes `supabase/tests/booking_operating_maintenance_guard_contract.sql`. The run **must fail** on the expired-maintenance-marker regression assertion. The connection closes and rolls back.
2. Starts a separate transaction with the candidate corrected validator and executes the *same* SQL contract (including overnight split breaks). This run **must pass** and then explicitly rolls back.

No existing tables, production data, Supabase Auth settings or payment records are used. Do not run this script against an external DB, and do not substitute this unit-level proof for staging role-isolated booking inserts/updates or a full application release gate. The older function is deliberately expected to fail to establish that the contract detects the bug rather than merely passing trivially.
