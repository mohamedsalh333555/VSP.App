# VSP — 36.01 When captains may enter a challenge result

**Date:** 19 November 2026. **Purpose:** bounded definition of the result-submission time for *team challenges*. This is not implementation or deployment acceptance of the full challenge-result consensus engine.

## Defined window and authority

1. **Earliest permitted submission:** when the recorded booking's **end_time is at or before the database server's current time**. Exactly at the end instant passes the time condition. Any attempt before it returns `MATCH_NOT_FINISHED`. The mobile device clock or UI countdown never grants eligibility.
2. This only applies to a booking identified as a **challenge**. A missing booking, cancelled booking or already confirmed final result must not be treated as a fresh result entry. A captain's team and logged-in authorization are independent gates.
3. **No automatic approval** merely because 24 hours pass, another captain does not respond, or the sender retries. A submitted choice or disagreement remains distinct from an official confirmed result; the two-captain agreement and isolation policy is covered by 84.01–84.04, 36.02–36.07.
4. **No-show/was-not-played cases** must follow their separate owner reporting, exclusion and appeal path (84.05–84.08). Ending on time alone does not establish that a match was played.
5. Bookings and tournaments **other than team challenges** use their own source-specific result policy. No rule here activates the retired standalone 1v1 tournament.

## Source and verification

The checked-in migration `supabase/migrations/20261003193000_challenge_mutual_result_agreement_and_points.sql` declares `v_now` using the database clock, selects the booking `FOR UPDATE`, rejects `v_booking.end_time > v_now` with `MATCH_NOT_FINISHED` **before** changing the booking, and refuses cancelled or finalized results. `scripts/verify_challenge_result_time_contract.py` checks these source-contract invariants in CI.

**Acceptance boundary for 36.01:** precisely the **definition** of allowed submission timing and a static assertion of the recorded SQL source. Not claimed: currently deployed RPC behavior, real JWT/captain isolation, concurrency, official two-captain agreement correctness, time-zone data correctness across devices, lifecycle transitions, or financial reconciliation. Those remain within 36.02–36.07, 37.02–37.07, 84 and staging gates. No SQL writes, production changes, APK or main merge.
