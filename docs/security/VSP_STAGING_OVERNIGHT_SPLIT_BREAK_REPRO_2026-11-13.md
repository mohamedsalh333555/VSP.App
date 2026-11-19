# VSP — overnight split-shift break bypass reproduced on staging (NO DATA WRITES)

Date: 2026-11-13. Staging project `vtwgqyxglevcsxwdmhop`. No bookings, customers or stadium rows accessed. Calls to `vsp_validate_stadium_booking_window` used literal synthetic timestamps only.

## Reproduction

Example Cairo local operating hours: **22:00 → 02:00**. Sample slot: **2026-11-16 23:30 → 2026-11-17 00:30**. Split-shift breaks on the same business shift can start after midnight of the next calendar day.

```sql
WITH slot AS (
  SELECT
    (timestamp '2026-11-16 23:30' at time zone 'Africa/Cairo') st,
    (timestamp '2026-11-17 00:30' at time zone 'Africa/Cairo') en
)
SELECT
  public.vsp_validate_stadium_booking_window(
    '22:00','02:00',null,null,false,null,st,en) no_break_valid,
  public.vsp_validate_stadium_booking_window(
    '22:00','02:00','00:00','01:00',true,null,st,en) crossing_midnight_break_current,
  public.vsp_validate_stadium_booking_window(
    '22:00','02:00','23:45','00:15',true,null,st,en) spanning_break_current,
  public.vsp_validate_stadium_booking_window(
    '22:00','02:00','00:15','01:15',true,null,st,en) after_midnight_break_current
FROM slot;
```

**Observed deployed result:** `true / true / true / true`. The first `true` is correct (no closure). The remaining three are incorrect because the booking overlaps an explicit break. Another synthetic booking ending at 02:30 returned `false`, confirming the outer closing-time constraint works for that case.

Root cause in deployed source: `v_break_start_ts := v_day + p_break_start_time` anchors the break to the booking's start date even when the break belongs to the next calendar day in the same operating shift. The condition that shifts overnight breaks only runs when the break's `end_time <= start_time`, so a 00:00→01:00 break is never shifted to the following date.

## Branch-only proposed fix

The **same migration that fixes expired emergency closures** now anchors the break start to `v_open_ts::date + p_break_start_time`, advances that timestamp to the next day if it precedes the opening timestamp, and constructs the break end on the resulting date (advancing by a day if necessary). SQL regression tests cover 00:00→01:00, 23:45→00:15, 00:15→01:15 overlaps and a valid early slot before the break.

**NOT APPLIED to staging or production.** Stage currently has 0 split shifts, 0 configured base breaks and 0 active maintenance markers (previous inventory), so actual paid-booking impact is not established. Before acceptance: run the migration and regression SQL in an isolated disposable database, compare existing schedule decisions, test `create_booking_atomic` and direct trigger insert/update with role-isolated fixtures, then re-check migrations/rollback and Android availability. No `main` merge.
