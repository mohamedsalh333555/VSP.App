# 04.07 — Arabic long text, masculine/feminine counts (bounded acceptance)

**Date:** 20 November 2026 (Africa/Cairo). **Branch:** `uxlp-44-implementation`. **Acceptance scope:** two important Flutter player surfaces only — Team Skills Cup published counts and team-invitation sheet.

## Product changes and observed checks

| Surface | Expected behavior | Reproducible proof |
|---|---|---|
| Team Skills Cup card | `1` = `فريق واحد`, `2` = `فريقان`, `3–10` = `فرق`, and `11+` = `فريق`; English singular/plural also correct; untrusted zero or over-cap is not advertised | `test/features/player/team_skills_published_details_test.dart` — `Team Skills team counts agree in Arabic and English` |
| Published skills stage list | Feminine singular `مرحلة واحدة`, dual `مرحلتان`, plural `مراحل` and 11+ `مرحلة`; dynamic published count rather than fabricated stage total | Same test file — `official phase counts use correct Arabic singular dual and plural` |
| Player team invitation | Long authentic Arabic/English team name, Accept/Decline both reachable on a 320dp viewport at 2x text scaling; action pair wraps rather than clipping alongside a ListTile trailing area | `test/features/player/team_invitations_sheet_test.dart` — two `invitation labels and actions fit narrow 320dp at 2x` widget cases, one per language |
| Account change during inbox access | Old account invite content is hidden, fresh read is required on return; stale async success does not leak across accounts | Same invitation tests — account-switch and pending-reply scenarios |

**Passing CI, exact coverage:**
- [Team Skills Published Data Truth, successful 73 focused tests](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44639256095) at `d26abace`, includes both grammar checks.
- [VSP Account Scoped Team Membership Lookup, successful 13 tests](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44639977832) at `a7f33c50`, includes the narrow RTL/English long-text cases.

**Explicit limits:** this accepts **04.07 as a bounded automated Arabic copy/number test deliverable**, not completion of the source-wide RTL and locale/device matrix. It does not certify every Arabic masculine/feminine construction, all 338 screens, font packages, real TalkBack navigation or physical Android. Tasks **04.06, 05.07, 09.*, 10.*** and the release gates remain open. No payments, Supabase, release build or production changes.
