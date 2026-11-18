# VSP — Team profile, honest head-to-head and official award rollout (18 November 2026)

Status: **CODE SUBMITTED; CI/STAGING/DEVICE GATES NOT YET ACCEPTED**. Scope: current UX task package group 86, not new task IDs.

- Team Skills award history now obeys the *same project-bound* AppEnv rollout as the published Cup tab. A disabled flag never initiates a history RPC, reducing unnecessary data access and traffic.
- The knockout stage award `one_v_one_champion` is labeled “Skills final champion / بطل نهائي المهارات” within the new Cup, not advertised as the retired standalone 1v1 tournament. The pre-existing legacy profile hero badge is explicitly historical; legacy data remains untouched.
- Team Profile opponent history now describes **aggregate head-to-head totals**, not the score of a single match, localizes AR/EN, and shows an unknown state instead of fabricated zero counts when source data are incomplete.
- Reuse existing `team_skills_team_history` and `team_skills_player_history` security-invoker views (completed cups only), existing component and Charcoal tokens. No new schema, Home layout, production, payments, owner subscriptions, Admin/Website edits, or release.
- Focused tests: two locales, normal/corrupt counters, legacy label, award titles, project-gate helper and disabled RPC spy. Live staging award publication, cross-platform parity, historical records audit, actor isolation and real-device QA **remain open**; in particular 86.03–86.05 must **not** be marked accepted on this batch alone.
