# VSP design and performance review — 2026-11-04

Branch `uxlp-44-implementation`, PR #35. Baseline `c45867d4dce03cf5297f9dddf6cd23095fdb0958`.

This additional task follows the source implementation batch and does not replace the seven original phases. Final aggregate review, analyzer/tests and APK remain on hold at the user's request. No Supabase, payment, permission, booking algorithm, captain-result confirmation or league/tournament-rule changes were made.

## Confirmed findings and implemented fixes

| Finding / cause | Impact | Source remedy | Risk / pending evidence |
|---|---|---|---|
| Owner inbox creates its conversation stream in build | Local rebuilds recreate subscription identity | Retain stream per authenticated owner; explicit refresh/retry; renew on owner change | Low–medium; account switching/reconnect runtime check pending |
| Missing profiles never enter inbox cache and completion always rebuilds | Absent profiles can cause a repeated read/rebuild loop | Deduplicate IDs; remember attempted IDs per scope/retry; reject old-generation completions; clear cache on account change | Low–medium; transient misses retain fallback names until explicit refresh |
| Search suggestions/results create a new Future each build | Same query can repeat repository requests | Retain only the current query Future inside the account-scoped delegate; changed query fetches again | Low; unchanged-query freshness waits for query change/reopening |
| Four fixed-height tab headers duplicate layout/direction code | Large text clips; selection behavior diverges | Shared wrapping, directional segmented control with selected semantics and minimum touch target | Medium; Arabic/English large-text/device checks pending |
| Animated action/back controller ranges and tweens are reversed | Resting controls shrink; absent callback appears enabled through wrapper | Correct pressed/rest scale, preserve null callback, respect reduced motion | Low; cooldown behavior preserved |
| Edit dialog closes before async save | Failure loses editing context; save has no duplicate guard | Owned/disposed controller, await save, retained draft and localized error, disable concurrent save/cancel | Medium; repository and permissions unchanged, failure/navigation checks pending |
| Physical chat edges and immediate clipboard confirmation | Locale mismatch; possible false copy success | Directional bubble/blockquote/copy placement, awaited clipboard with localized failure, accessible target | Low; platform/RTL checks pending |
| Fixed date rows, shrinking position text, dim hint/error layout and unscrollable insight sheet | Large-text/keyboard usability problems | Minimum row height, wrapping labels, semantic hint color, multiline errors, safe scrollable sheets | Low–medium; viewport and contrast measurements pending |
| Countdown equates scheduled expiry with server transition; partial slot search claims universal unavailability | Misleading competition/booking status | Describe scheduled start and current search results; canonical empty states | Low; no state/booking mutation |
| Equivalent palette/motion literals bypass the design system | Maintenance inconsistency | Reuse existing exact aliases and named durations; preserve identity and timings | Low; protected/mixed payment controls excluded |
| Skeleton shimmer ignores reduced motion | Unnecessary decorative animation | Static identical placeholder when animations are disabled | Low; visual approval pending |

Principal source locations: `owner_inbox_screen.dart`, `user_search_delegate.dart`, `vsp_segmented_control.dart`, `vsp_animated_button.dart`, `vsp_back_button.dart`, `chat_message_bubble.dart`, `copilot_chat_bubble.dart`, `custom_text_field.dart`, date picker step views, position selector, insight sheet, `vsp_countdown_timer.dart`, `book_tonight_sheet.dart` and `skeleton_loader.dart`.

## Reviewed areas and deferred changes

| Area | Evidence / decision | Why deferred or unchanged |
|---|---|---|
| Booking speed | `BookTonightService.findTonightOffers` already caps candidates at six and uses `Future.wait` | No proven need to rewrite availability calculation or introduce stale booking caches |
| Screen/data loading | Home already guards by user; stadium provider has generation protection and pagination | Preserve sequencing of bookings/captain checks; benchmark before parallelizing shared state |
| Challenges / result confirmation | Actions depend on authoritative lifecycle and captain scope | No optimistic result success or confirmation changes; test both captains/conflicts at final gate |
| Leagues / tournaments | Build-time Futures exist in top scorers, title/champion indicators; bracket stream lifecycle is a candidate | Caching needs explicit refresh/invalidation contracts for live scores; no speculative stale-data optimization |
| Database / indexes | Source migrations already define booking user/status-time, conversation, tournament round/team and governorate indexes; public profile name search uses `ilike` | No query is proven slow without actual plans. Do not assume migrations deployed. Read-only EXPLAIN/pg_stat evidence may later justify a composite/filter or trigram index; no SQL/index change or live access here |
| Search error contract | Existing repository converts failures to empty results | Future reuse does not fix error/empty conflation; defer repository contract and retry integration for dedicated coverage |
| Background jobs | Stadium image compression already awaits `FlutterImageCompress.compressWithList` | Profile CPU/frame cost before isolates or new job infrastructure; payment/reconciliation work out of scope |
| Dependencies | Existing dependency scan finds direct imports for every non-SDK runtime dependency | No unused package proven; no removal/lockfile change. Import presence does not establish binary-size efficiency |
| Optimistic UI | Local tab selection is immediate; mutations affect shared/sensitive data | Preserve server authority for booking, payment and results. Chat edit waits for save and retains draft |

## Before / after evidence

A reproducible lexical scan reads all 338 unique registered paths across 366 table rows. It records hashes and locations in `UXLP_44_SOURCE_SCAN.json`.

| Static candidate count | Baseline | Current source |
|---|---:|---:|
| Raw palette matches | 189 | 14 |
| Physical Alignment matches | 26 | 14 |
| Inline millisecond duration matches | 45 | 4 |
| Missing registered files | 0 | 0 |

Remaining physical directions are gradient axes. Remaining palette/duration hits are protected payment/ledger/checkout or mixed tournament payment controls. Pattern matches are not all literals, proven defects, runtime acceptance or performance measurements.

For R unchanged-scope/query rebuilds, the old code could construct R stream/Future objects; the new inbox/search retains one until owner/query/retry changes. This is a source property, **not measured network request reduction**. Missing profile IDs are attempted once per scope/retry rather than after every completion-triggered build.

No before/after milliseconds, FPS, memory, SQL timing or APK-size benchmark was run. After the user opens the final-review gate, compare baseline/current on the same device, build mode, dataset, locale and network: cold/warm load, request/subscription counts, frame timings, unchanged-query rebuilds, offline retry and account switching. Record sample count, median and p95; do not infer speedup from lexical counts.

## Prepared validation and limits

- New `test/core/ui/vsp_pre_review_regressions_test.dart`: Arabic/English segmented labels at 2× text scale, minimum targets/callbacks, disabled action/rest scale and honest countdown wording.
- Updated `test/features/owner/owner_inbox_components_test.dart`: fake-repository request count across unchanged-query suggestions/results rebuilds and changed queries.
- These tests are prepared, **not run**. Existing tests remain in place; live-stream/account-switch and edit-failure runtime scenarios are still pending.
- Standalone Dart formatter parsing accepted all 100 changed/new Dart files. It emitted local `flutter_lints` package-resolution warnings; it is not analyzer/type/test evidence. `git diff --check` passed.
- Historical baseline CI run `41794033975`: 824 passed, 2 skipped opt-in live Supabase checks. This does not validate the new source.
- CI push trigger removed to avoid starting the forbidden final suite on publication. All CI/APK/release workflows remain manual and none was dispatched.

## Decisions and remaining gates

`DESIGN.md` indexes the existing Design System V2; it does not replace the brand or duplicate the token catalog. Small-header intrinsic layout is an explicit tradeoff, limited to two/three-item controls, not long lists. No architecture rewrite or wholesale redesign.

Five historical product/server decisions remain open in the UXLP audit. They were not revalidated live in this continuation. Full rule × screen × state runtime coverage and final aggregate review remain incomplete; no claim that all seven phases passed or that this branch is release-ready. See `UXLP_44_EXECUTION_GATE.md` for current phase status.
