# VSP — client availability distinguishes closed venues from booked slots

Date: 2026-11-13. Development branch only; no deployed database migration.

- A venue blocked by administration is shown as unavailable for booking on the player slot grid, with no actionable slots.
- An active emergency maintenance end time blocks **only slot starts before that end** while the closure is active, preserving booking of a later slot after the end. Past closure markers must not permanently disable a pitch.
- Slot cards now display distinct **Closed / مغلق** rather than presenting closure as another player's booked slot. Mixed-booked, closed and expired slots have a neutral no-availability explanation instead of falsely claiming full booking.
- The slot selection calculator guards tapped, extended and previously selected slots. The confirm handler rechecks before payment navigation even for stale/deep-link selections.
- Pure unit tests cover blocked venue, active closure, exact maintenance-end boundary, future slot after closure, expired marker, and absent marker. Architecture test traces the check into grid, card, calculator and confirmation handler.

**Limit:** this is a client-side preview and still requires live booked-slot stream, operator changes after page load, actual DB trigger/RPC and Android widget tests. The server-side maintenance correction remains an unapplied migration. No charge or booking was created, no main merge.
