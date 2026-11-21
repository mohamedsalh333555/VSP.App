# VSP — server operating-hours columns take precedence in Flutter booking picker

Date: 2026-11-13. Branch-only, pending Flutter CI and integration validation.

The authoritative booking trigger validates fields on stadiums: opening_time, closing_time, is_split_shift, break_start_time and break_end_time. Previously the Flutter picker preferred features.workingHours and features.breakTimes; Stadium.fromFirestore ignored top-level split/break fields. A stale JSON schedule could show slots that the database would reject.

The live model now marks hasServerOperatingHours only when both SQL time columns are present, and reads the server split-shift/break columns with legacy JSON fallback. The picker prefers those SQL opening/closing fields for actual database rows, while retaining feature-based schedules for legacy/offline records lacking both SQL columns. It excludes explicit server breaks, including post-midnight ones, and rejects incomplete or conflicting overlapping breaks rather than fabricating availability.

Unit cases test canonical SQL precedence, daytime break, overnight break, conflicting break records, missing server break with split shift, and legacy fallback. No database rows or booking financial logic changed.

**Limit:** this does not implement court_operating_hours priority or prove consistency of multi-break feature JSON with the single canonical SQL break. Real booking trigger/RPC, network, DST, owner data and direct role tests remain required. Do not mark 66.07 or 83.01 accepted merely from these unit tests.
