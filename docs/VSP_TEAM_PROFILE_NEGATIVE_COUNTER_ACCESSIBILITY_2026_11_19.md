# VSP — Team Profile invalid aggregate presentation (19 November 2026)

In the player Team Profile stats grid, negative wins, draws or losses were previously shown as if valid. Now invalid negative counts render an unknown dash (not a synthetic zero), and the Semantics label says "Unavailable" or "غير متاح". This also applies to a negative total member count; null remains unknown. Genuine zero and positive counts stay unchanged.

Added counter-format and bilingual accessibility regressions to the existing team-profile member-count tests. The change is a defensive client display fix only; match outcomes, standing calculations, historical data and backend policy are unchanged. Full authoritative data QA and Android/TalkBack acceptance remain open. Ledger unchanged: 640 / 346 / 294.
