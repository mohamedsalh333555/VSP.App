# Team Skills Cup — fail-closed roster refresh and captain registration
19 November 2026; branch uxlp-44-implementation; Draft PR #35.

The player registration form now invalidates its verified-roster flag while a new roster read is running and on account/team switch, and clears selected members and roles after a failed read. Both form button and submit action use the same pure guard: exactly five selected member IDs must belong to the latest verified list, with goalkeeper and representative included.

Three focused unit tests cover valid submission, stale/unknown roster, invalid roles and missing players. This is a Flutter-side defensive gate only; backend RPC remains authoritative. No policy/payment/production writes or change to tournament rules. No task closure without full QA; counter remains 640 / 346 / 294.
