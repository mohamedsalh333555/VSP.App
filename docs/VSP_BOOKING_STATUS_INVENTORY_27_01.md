# 27.01 — Booking status inventory (implementation evidence)

Source reviewed: `lib/data/models/booking_enums.dart` and `lib/data/models/booking_mapper.dart` on `uxlp-44-implementation`.

| Dart state | Database serialization | Meaning | Terminal? |
|---|---|---|---|
| `pending` | `pending` | Created / awaiting confirmation or payment | No |
| `confirmed` | `confirmed` | Confirmed reservation | No |
| `upcoming` | `confirmed` | Client-side alias of confirmed | No |
| `completed` | `completed` | Match finished | Yes |
| `noShow` | `noShow` via `toDbValue()` | Participant did not attend | Yes |
| `cancelled` | `cancelled` | Booking cancelled | Yes |
| `expired` | `expired` | Reservation/payment hold expired | Yes |

**Existing mapper normalization:** legacy `upcoming` reads as `confirmed`; `no_show` / `noshow` read as `noShow`. Unrecognized values are logged and mapped to `pending` (potential risk, not a validated transition). `BookingStatus.upcoming.toDbValue()` maps to `confirmed`.

**Separate axes, not booking states:** `MatchResultStatus` (`noResult`, `waitingOpponent`, `confirmed`, `disputed`), `MatchOutcome` (`homeWin`, `draw`, `awayWin`), and payment status strings are independent. Booking types (`personal`, `openJoin`, `challenge`, `team`, `matchup`, `maintenance`) are also not lifecycle states.

**Scope of this artifact:** exhaustive inventory of the declared Dart booking states and their currently implemented mapper behavior. This does **not** establish that every backend RPC uses these values, nor that state transitions are safe. Those are separate tasks 27.02–27.08. In particular `noShow` serialization must be checked against actual database constraints before a backend change.

**Acceptance:** task 27.01 requires a documented inventory, not tests or new server behavior. Inventory completed from the source files above; backend reconciliation remains separately tracked.
