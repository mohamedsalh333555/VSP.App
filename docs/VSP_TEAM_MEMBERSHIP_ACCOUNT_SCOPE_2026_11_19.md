# Team membership lookup scope — 19 November 2026

The team's active-selection UI already uses getUserTeamsStrict(userId), which first reads team_members by user_id and then fetches matching teams from teams_public. This is not based on a saved active-team ID alone.

Repository test coverage previously included two memberships, deterministic ordering, empty state and restoring the verified saved active team. Three added synthetic HTTP tests assert querying distinct accounts by distinct user IDs, propagating a 503 failure instead of reporting zero memberships, and deduplicating membership rows rather than duplicating cards.

Focused CI now runs the repository test directly. Real JWT/RLS cross-user enforcement and multi-account staging remain open. Eligibility is server authoritative; no real team data is read or edited. This work may provide bounded acceptance for 18.01 if CI passes.
