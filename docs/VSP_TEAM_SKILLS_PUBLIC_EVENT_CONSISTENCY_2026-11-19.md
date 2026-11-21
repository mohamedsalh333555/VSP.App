# Team Skills Cup — conflicting public event fields (19 Nov 2026)

Branch: `uxlp-44-implementation`; Draft PR #35.

The public competitions discovery intentionally refuses two copies of the same cup ID when the official displayed fee, team capacity, start/end time or venue disagree. Previously only name/status/governorate conflicts were rejected, so overlapping stale reads could pick the first fee or date. Identical duplicate rows remain valid. Public summary capacity is now bounded to 1000, consistent with the detailed view.

Two focused regression tests cover conflicting duplicate prices/dates/venues and the shared capacity rule. This is source-level publication trust hardening (86.04 and 86.05 partial); it does not authorize tournament publication, override a server state, change registration/fees, or prove parity with Admin Panel and Website.

Counter unchanged: 640 total / 343 accepted / 297 open pending CI and staging. No main merge, production deployment, payments or feature-flag change.
