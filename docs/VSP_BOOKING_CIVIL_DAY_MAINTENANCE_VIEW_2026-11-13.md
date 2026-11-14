# Booking civil dates and maintenance information — branch-only

2026-11-13. Two narrow UX corrections were implemented:

- The 14-day booking selector used elapsed `Duration(days: index)`. Egypt's DST transitions can make a *civil calendar day* 23 or 25 hours. `AppDateFormatter.addCivilDays()` constructs each date from year/month/day plus the offset. Tests cover leap day, month boundaries and spring/fall transition weeks. This does not replace server timezone and booking conflict checks.
- A verified venue with active emergency maintenance should not have its entire profile hidden. The player now sees a maintenance warning and can open the slot picker to choose a booking **after the emergency closure ends**. The schedule and confirmation handler still reject closed slots, and administratively blocked stadiums remain fully unavailable.

No live venue, booking, Paymob or Supabase schema changed. Device and integration testing remains necessary. The proposed server maintenance SQL migration is still unapplied.
