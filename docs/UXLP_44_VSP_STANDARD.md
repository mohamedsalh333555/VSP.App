# VSP UXLP-44 — Product UX Quality Standard

**Status:** Adopted implementation standard; screen-by-screen verification is tracked separately.  
**Scope:** Flutter player and owner experiences, navigation, forms, booking, teams, tournaments, payments, support, notifications, dialogs, sheets, empty/loading/error/success states, Arabic/English content, and responsive/accessibility behavior.  
**Important:** This is the VSP-specific operational set of 44 UX rules, authored for this repository. It is not represented as a verbatim recovery of a prior external list.

## A. Perception & Vision — 11 rules

1. **Clear hierarchy:** Every screen has one visually dominant task or content focus.
2. **Consistent grouping:** Related information and actions are spatially grouped; unrelated groups are visibly separated.
3. **Contrast first:** Text, icons, borders, and states remain distinguishable against their actual backgrounds.
4. **Typography roles:** Titles, section headings, body, metadata, and helper text use consistent semantic type roles.
5. **One icon language:** Similar actions use consistent icon families, stroke/fill states, size, and containers.
6. **Color semantics:** Success, warning, error, selected, disabled, and informational colors have stable meanings.
7. **Stable alignment:** Repeated cards, fields, labels, and actions share predictable alignment and spacing.
8. **Scan-friendly density:** Important information is visible without forcing users to inspect dense paragraphs or crowded clusters.
9. **State visibility:** Selected, current, unavailable, pending, and completed states are visually unmistakable.
10. **Bilingual visual integrity:** Arabic RTL and English LTR layouts preserve hierarchy, alignment, truncation, and number readability.
11. **Responsive legibility:** Content remains readable and unclipped under narrow widths, large text, keyboard display, and safe-area insets.

## B. Processing & Decision — 15 rules

12. **Recognition over recall:** Show relevant choices and context instead of requiring users to remember hidden values or previous steps.
13. **Plain language:** Use familiar words; explain unavoidable domain terms at the point of use.
14. **One primary decision:** Each decision surface makes its recommended or primary action clear.
15. **Progressive disclosure:** Reveal advanced or optional details only when they are relevant.
16. **Decision context:** Show the information needed to decide before asking for confirmation.
17. **Transparent cost:** Show total price, fees, payment timing, and refund/cancellation conditions before commitment.
18. **No misleading promises:** Never imply a payment, refund, booking, or verification succeeded before the backend confirms it.
19. **Meaningful defaults:** Defaults must be safe, explainable, and consistent with the user's current context.
20. **Choice economy:** Avoid duplicate, redundant, or low-value options.
21. **Chunk complex tasks:** Split long workflows into logical steps and preserve entered data between steps.
22. **Explain constraints:** State limits, eligibility, required fields, and why an action is unavailable.
23. **Comparable information:** Present alternatives using the same units, labels, and decision criteria.
24. **Contextual help:** Put concise guidance next to the field or decision it explains.
25. **Error prevention:** Validate inputs early and prevent invalid state transitions before submission.
26. **Decision reversibility:** Explain irreversible or costly actions and provide a safe way back wherever possible.

## C. Behavior & Interaction — 11 rules

27. **Affordance clarity:** Every interactive element looks and behaves like its actual interaction type.
28. **Immediate feedback:** Taps, submissions, loading, success, and failure produce timely visible feedback.
29. **No duplicate submission:** Disable or guard repeated submissions while an operation is in progress.
30. **Predictable navigation:** Back, close, tab, and deep-link behavior preserve user context and avoid unexpected exits.
31. **State-driven actions:** Available actions reflect the real booking/payment/team/tournament state; contradictory actions are not shown together.
32. **Safe destructive actions:** Destructive actions require clear intent and identify their consequence.
33. **Touch ergonomics:** Interactive targets have adequate hit areas and sufficient separation.
34. **Form resilience:** Keyboard type, focus order, validation, autofill, and submit behavior match the field's purpose.
35. **Scroll and modal safety:** Long content scrolls; dialogs and sheets respect keyboard, device insets, and reachable action areas.
36. **Feedback recovery:** Errors explain what happened and the next useful action; retry does not silently lose entered data.
37. **Consistent gestures:** Swipe, long-press, drag, and dismiss gestures are discoverable and never the only way to perform a critical action.

## D. Management & System Coherence — 6 rules

38. **Single source of truth:** User-visible business state comes from authoritative application/backend state, not decorative or stale local assumptions.
39. **Role-based relevance:** Player and owner surfaces expose only actions and data appropriate to the authenticated role and permissions.
40. **Lifecycle consistency:** Booking, payment, refund, tournament, team, and notification states use consistent transitions and labels across screens.
41. **Persistent communication:** Important notifications and status history remain available according to product retention rules; opening one must not accidentally erase unrelated items.
42. **Design-system governance:** Shared tokens and components are preferred; one-off styling requires a documented reason.
43. **Operational observability:** Failed critical actions provide traceable diagnostics without exposing secrets or sensitive backend details to users.

## E. Performance & Arousal — 1 rule

44. **Optimal cognitive load:** Match information density, urgency, motion, and feedback intensity to task complexity; avoid both overwhelming stimulation and insufficient feedback.

## Required audit record

For each screen and state, record: screen/component path; player/owner role; locale; device/layout condition; rule number; observed evidence; severity; user impact; proposed change; verification method; status (pass, fail, needs product decision, not applicable, not yet inspected).

A rule is not marked pass merely because a shared component appears to support it. Verify the actual screen usage and relevant runtime state. Do not claim full coverage until every in-scope screen, dialog, sheet, notification, and state has a recorded result.

## Execution gates

- Fix objectively clear UI defects in grouped changes.
- Escalate changes that alter business policy, payment/refund behavior, permissions, or data retention for product approval.
- Do not apply database migrations without approval of the exact SQL.
- Run one consolidated validation pass after the grouped changes, not a separate test cycle for each finding.
- A successful CI/build verifies compilation and automated checks only; it does not replace device-level UX verification.
