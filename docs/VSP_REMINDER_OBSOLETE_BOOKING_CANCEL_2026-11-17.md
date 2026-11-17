# VSP — obsolete local reminder invalidation

2026-11-17. Correction to 54.03 and the 54.05 local quota.

When a previously scheduled booking moves to a past/too-soon time or to a fully capped UTC reminder day, the scheduler must cancel the old native reminder ID and remove the old account-scoped day marker. Returning early without this cleanup would surface stale booking time notifications.

The new pure with-out-booking-marker helper and Flutter regression test cover retaining unrelated reminders while deleting the stale booking marker. No direct database, FCM or production changes. OS integration and multi-device testing remain open.
