# 51.05 — Booking availability copy acceptance

Accepted scope: automated architecture regression coverage for distinct Arabic/English availability messages and error states in the slot-selection view. This is **not** real-booking, server synchronization, or physical-device acceptance.

## Tested branches

- `timeSlots.isEmpty`: no configured slots; does not assert stadium is closed.
- `allSlotsPassed`: all time slots elapsed.
- `allSlotsBooked`: every slot booked.
- `!hasBookableSlot`: mixed past and booked slots, no selectable times.
- `snapshot.hasError` and `!snapshot.hasData`: error and retry, no unverified selection.

Evidence in repository:
- `test/architecture/booking_slot_day_state_contract_test.dart`
- `test/architecture/booking_empty_slots_copy_contract_test.dart`
- `test/architecture/booking_slot_stream_fail_closed_contract_test.dart`
- `lib/features/player/widgets/booking/booking_slot_stream_section.dart`

[Flutter CI success on 6ea1dc38](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43320006151) exercises the availability-copy architecture checks; [Android smoke success](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43320006172) verifies onboarding/login **only**, and is not cited as an availability-device test.

Acceptance is limited to **51.05 automated availability message contracts**. Task **83.01** still requires diagnosis and real reproduction of the specific 11 November failure and operational-hours source. Task **83.04** still requires device/RTL calendar behavior checks. No server-side availability claim is made.
