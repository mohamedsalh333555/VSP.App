# VSP — Full Product Experience, Emotional UX & Retention Implementation

**Task intake 18 November 2026 — OPEN, not implemented.** Branch: uxlp-44-implementation. Draft PR #35.

## Scope and source-of-truth

Before each batch inspect latest GitHub head and the prior [behavioral audit](VSP_UX_PRODUCT_AUDIT_BEHAVIORAL_RETENTION_2026-11-18.md), [Phase 10 plan](PHASE10_BEHAVIORAL_UX.md), [experiments](PHASE10_EXPERIMENTS.md), [report](PHASE10_FINAL_REPORT.md), [original counter](VSP_CURRENT_TASK_COUNTER.md), and [captain challenge consent spec](VSP_TEAM_CHALLENGE_CODE_CONSENT_SPEC.md). Discover and inspect real linked Admin Panel, Website, Flutter, Supabase RPCs, Firebase and design tokens before changing any of them. Classify features: source+runtime working; working but improvable; partial; absent; source present but not runtime tested. Do not duplicate working tables/features.

**Immutable UX boundaries:** Home layout, ads, discovery, match/challenge browsing and navigation remain intact; no achievement or personal ranking cards on Home. Verified achievements in Team Profile; Cup in competitions; rebooking in Bookings. Charcoal/Zinc only, navbar selected Bold/unselected Outline; no neon. Owner subscription business model, never booking commission. No fake reviews, capacity, scarcity, results, prices, badges, ranks or outcome metrics.

## Nine behavioral principles → existing tasks

| Principle | Existing original IDs | Truly new integration if needed |
|---|---|---|
| Pain relief (booking, transparent prices, offline) | 03, 14, 16, 21, 26–31, 51, 53 | 86.06 |
| Emotional (verified wins, fair loss handling) | 36–44, 84, Phase 10 | 86.02 |
| Belonging (roster, captain, invitations) | 15, 17, 18, 32–34, 81–82 | 86.03 |
| Achievement (official trophies and medals) | 37–44, 61, 69–70, 81 | 86.05 |
| Social proof (real reviews, standings, public view) | 12, 21, 37, 41, 53, 79 | 86.05 |
| Real FOMO (server-based seats and deadlines only) | 14, 35, 39, 53 | no extra task |
| Habit (booking → match → result → challenge) | 16, 34–36, 45–49, 54 | 86.02/86.06 |
| Progress (last games, ranking corrections) | 36–42, 81, 84 | 86.03 |
| Referrals (consented join, not share clicks) | 17, 33–35, 46, 50, 55 | 86.07 |

## Five actual implementation batches

1. **Team first:** 81.07/81.09 official team awards and roster permissions; new 86.03 compact team card/history and authentic ranking delta, new 86.02 post-match approved outcome to next match, 86.01 Home no-redesign regression. No duplicate cards or premature celebrations.
2. **Codes and invites:** existing 82.02–82.09 and 34.02–34.13 on Supabase RPC/PostgreSQL, 8-digit per-team captain-only challenge code stable until both captains confirm exact match; atomic consume/rotate and idempotency; real staging account+concurrency+permission tests. Distinguish temporary player membership code; never authorize result or booking from code possession alone.
3. **Competitions:** original 36–44, 61, 69–70, 81, 84 and new 86.04/86.05: Team Skills Cup admin-only verified official outcomes, trophies and prizes, public Website parity, historical 1v1 kept in records/financial history but not as a current tournament; role and staging tests before feature flag.
4. **Repeat booking, invitation and notifications:** 86.06 always refetch fresh slot, authoritative price, deposit and explicit confirmation; no duplicate booking/payment. 86.07 share/deep-link to consented accepted invite with privacy-safe attribution. Reuse 45–49 and 54 for event-triggered notification consent, dedupe, frequency and delivery, never open-app-only pressure.
5. **Measurement and acceptance:** original 50–55, 57–60, 78–80 track meaningful first booking/join, repeat booking, active teams, accepted invites, qualified D1/D7/D30, verified result views, cup participation; role-separated, privacy/consent/deletion-aware, actual Firebase collection and dashboards, staged experiments. Verify Flutter analyze/unit/widget/integration, SQL authorization/two accounts, payment idempotency, Arabic/English RTL, weak network, device, Admin+Website. Do not claim retention improvement without cohort and controlled data.

## Seven new unique tasks — one accepted with bounded evidence, six remain OPEN

| ID | Priority | Actual engineering deliverable | Acceptance | Status |
|---|---|---|---|---|
| 86.01 | P1 | حماية الصفحة الرئيسية من أي كروت إنجازات أو ترتيب شخصي أو إعادة ترتيب وظائف الاكتشاف والحجز والبانر والتنقل، بعقد UI رجوعي بالعربية والإنجليزية | اختبار الشاشات الحالية عربي وإنجليزي، عدم إزاحة المحتوى أو إنشاء كارت شخصي | ACCEPTED — [source/layout/nav, not device](VSP_HOME_STRUCTURE_BOUNDED_ACCEPTANCE_86_01_2026-11-19.md) |
| 86.02 | P1 | حلقة بعد المباراة: نتيجة تحدٍ معتمدة ثم أثرها الحقيقي في فريق المستخدم ثم فعل واحد لمباراة أو تحدٍ جديد، بلا مكافأة لنتيجة معلقة أو متنازع عليها | اختبار widget وربط نتيجة مؤكدة على Staging بحسابين، وحالات الرفض والنزاع والإلغاء | OPEN |
| 86.03 | P1 | ملخص آخر خمس مواجهات معتمدة وتغير الترتيب وفق نفس المسابقة وقواعد النقاط في Team Profile من دون تكرار الكارت | اختبار مصدر الترتيب وتصحيح النتائج والبيانات الناقصة والتواريخ وRTL | OPEN |
| 86.04 | P1 | إزالة عرض 1v1 كمسابقة حالية من أسطح اللاعب وربط بطولة Team Skills Cup بإذن النشر الرسمي مع حفظ السجلات التاريخية والمالية | اختبارات current/legacy وfeature flag مع جرد الاعتماديات بلا حذف بيانات | OPEN |
| 86.05 | P1 | توحيد عرض مصدر النتائج والبطولات والشارات والجوائز الرسمية عبر Flutter وAdmin Panel والموقع مع صلاحيات نشر المسؤول وحجب بيانات الفريق الخاصة | اختبار بيانات Staging واحدة على الأنظمة الثلاثة ورفض نتائج غير معتمدة وRLS بحسابين | OPEN |
| 86.06 | P2 | إجراء احجز تاني من الحجز السابق بعد جلب سعر وتوفر وعربون وسياسة حديثة من الخادم ثم موافقة صريحة وحجز جديد idempotent | اختبارات تغيّر السعر والتوقيت والإغلاق والتكرار؛ لا دفع آلي ولا اعتماد على الموعد القديم | OPEN |
| 86.07 | P2 | ربط مشاركة الفريق أو المباراة بدعوة وانضمام مؤكد بموافقة صريحة وقياس تحويل الإحالات الفعلية دون جمع PII أو كشف الأكواد | اختبارات deep-link وانضمام/رفض/تكرار بحسابين وFirebase consent وDebugView | OPEN |

## Gates, authorization and exclusions

Relevant staged server tests precede accepting any RLS, challenge, award, payment or booking tasks. Do not merge main, deploy production, modify Paymob, issue APK, remove historical records, create parallel design/schema, or invent metrics. Do not change Home beyond fixing a confirmed defect. Successful code/test alone is not live UX or uplift evidence; record source, test run and exceptions for every acceptance.

## Deduplicated counter

Original: **633 (328 accepted, 305 open)**. New: **7 unique OPEN 86.01–86.07**. Active: **640 total / 328 accepted / 312 remaining = 51.25%**. Addition is scope only, not product implementation. All other requested work retains its existing IDs.
> 19 November bounded status: 86.01 accepted at source/Flutter widget scope. Six 86.* tasks remain OPEN. The intake-time 328/640 baseline above is historical; current accounting is 343/640. No player Home component/layout change was made.
