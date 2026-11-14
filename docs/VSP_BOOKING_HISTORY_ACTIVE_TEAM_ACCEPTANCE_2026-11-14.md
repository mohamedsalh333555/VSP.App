# VSP — Booking history and active-team acceptance

Date: 2026-11-14  
Branch: `uxlp-44-implementation`  
PR: #35

## Accepted tasks

### 16.07 — Booking-history account isolation

Accepted for the client/provider boundary. The booking provider immediately
invalidates cached player history when identity or role changes, ignores late
results from the previous account, scopes in-flight action locks by account,
and prevents an old detail/mutation response from repopulating the new
account. Direct race tests cover delayed reads, cancellation, shared booking
IDs, owner-role switching and mutation results.

This does not replace server RLS or real two-account staging verification.

### 18.02 — Active-team selection

Accepted for selecting only from the account's verified team memberships.
An unverified/out-of-membership team ID is rejected.

### 18.03 — Persist active-team choice

Accepted for per-account local persistence and restoration. Storage keys are
derived from the authenticated account ID and the saved team must still exist
in the verified membership list.

### 18.05 — Deleted/left-team handling

Accepted for clearing a stale saved selection when the account has no
remaining verified teams and falling back to the first current verified team
when a previously selected team is no longer present.

### 18.06 — Switch between teams

Accepted for switching from one verified team to another and proving that the
selection is not inherited by a different account on the same device.

## Automated evidence

- `test/core/providers/booking_account_scope_race_test.dart`
- `test/core/providers/booking_mutation_result_identity_test.dart`
- `test/core/providers/booking_read_and_owner_edit_scope_test.dart`
- `test/architecture/booking_scope_loading_contract_test.dart`
- `test/architecture/booking_detail_scope_contract_test.dart`
- `test/architecture/booking_async_mutation_scope_contract_test.dart`
- `test/core/services/active_team_service_test.dart`
- Flutter CI run `43586678490`: analyzer, privacy/deletion gate,
  architecture gate, Cairo booking-date verification and full suite passed
  (**1389 passed, 11 explicitly skipped**).
- Android E2E smoke `43586678492`, account SQL security `43586678514`,
  owner checkout security `43586678561` and iOS compliance `43586678522`
  completed successfully on the same branch head.

## Limits

- No production or staging data was changed.
- No payment, pricing, permission, schema or subscription rule changed.
- Tasks 18.01 (fetch all memberships) and 18.04 (challenge integration) stay
  open until their independent acceptance evidence is complete.
- Real multi-device/two-account staging remains part of the broader release
  gates and is not implied by these client tests.
