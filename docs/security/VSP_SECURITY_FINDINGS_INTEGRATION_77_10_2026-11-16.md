# 77.10 — تقرير أمن موحد وربط أدلة Issue #38 وVSP release gates

**16 نوفمبر 2026 | قبول جزئي النطاق: ربط التقرير والتصنيف فقط. لا يعني اجتياز فحوص الأمن أو جاهزية النشر.**

## المصادر التي يرتبط بها هذا التقرير

- [Issue #38 — security-definer views and executable privileged RPCs](https://github.com/mohamedsalh333555/VSP.App/issues/38)؛ أرقامه القديمة 198 دالة و4 عروض هي لقطة تاريخية وليست جرد Staging الحاضر.
- [Issue #37 — schema, bookings, payments and RLS](https://github.com/mohamedsalh333555/VSP.App/issues/37): ما زالت قائمة مراجعة التناقضات والاختبارات التشغيلية مفتوحة.
- [PR #35 — التطوير الجاري](https://github.com/mohamedsalh333555/VSP.App/pull/35): Draft، ولا يعني نجاح CI أو إغلاق بنود توثيق صلاحية الدمج أو النشر.
- [77.01 جرد التواقيع](VSP_STAGING_PRIVILEGED_RPC_INVENTORY_2026-11-13.md)، [77.02/77.03 تصنيف المصادر](VSP_STAGING_PRIVILEGED_RPC_TRIAGE_2026-11-13.md)، [77.05 وصول المجهول](VSP_STAGING_ANON_PRIVILEGED_RPC_ACCEPTANCE_2026-11-14.md)، [77.09 سجل الاستثناءات الـ12](VSP_PRIVILEGED_RPC_EXCEPTIONS_77_09_2026-11-16.md).
- [76.03–76.07 حماية العروض](VSP_STAGING_VIEW_ROLE_MATRIX_ACCEPTANCE_2026-11-14.md)، [78.03 مصفوفة الأدوار](VSP_ROLE_ACCESS_MATRIX_78_03.md)، [78.06 استثناءات الأدوار](VSP_ROLE_PERMISSION_EXCEPTION_REGISTER_78_06_2026-11-13.md).
- [سياسة الإفراج](RELEASE_ACCEPTANCE_POLICY.md)، [قائمة المهام التفصيلية](../VSP_80_DETAILED_SUBTASK_BREAKDOWN.md)، [دفتر التسليم](../VSP_LIVE_DELIVERY_LEDGER.md).

## واقع Staging المعاد التحقق منه بالقراءة فقط

| السطح | الحقيقة القابلة للتحقق | النتيجة وحدود الإثبات |
|---|---|---|
| 4 عروض تاريخيًا SECURITY DEFINER | `courts`, `public_subscription_plans`, `tournament_clean_sheets`, `owner_subscription_status`: جميعها `security_invoker=true` في `pg_class.reloptions` | المصدر المنشور في Staging محمي من تجاوز invoker الافتراضي؛ لا إثبات تلقائي لكل صف/عميل في Production |
| وصول العروض | `anon` يستطيع SELECT على الثلاثة الأولى ولا يستطيع على `owner_subscription_status`، و`authenticated` لديه SELECT على الأربعة | سماح العام هو سلوك مقصود للملاعب والخطط؛ التحقق من عزل مالكين في توثيق 76.07 محدود بأدوار/مطالبات جلسة SQL |
| دوال ذات امتياز | 200 توقيع `public SECURITY DEFINER` قابل للتنفيذ بواسطة PostgreSQL role `authenticated` | تحذير مراجعة لا يثبت 200 ثغرة. 0 من المجموعة يستطيع `anon` تنفيذها |
| استثناءات الاستدعاء | 12 من 200 لا تتضمن مباشرة نصوص `auth.uid()` أو `auth.jwt()` | بعض الاستثناءات فوّضت الفحص، أو تعتمد على `service_role` أو عامة القراءة؛ [فحص كل 12](VSP_PRIVILEGED_RPC_EXCEPTIONS_77_09_2026-11-16.md)، لا إعفاء من اختبارات caller |
| صلاحيات النتائج الرياضية | الـRPC الجديد لتصويت القائد وبلاغ/استبعاد المباراة يعمل فقط كـSQL مرشح في GitHub | اجتاز PostgreSQL معزول؛ لا يثبت وجود وظائفه في Staging أو صلاحيات JWT حقيقية |
| نتائج التحدي القديمة | 20 مباراة تحدي confirmed، 0 `waitingOpponent`، 0 candidate tables، وعمود `bookings.pending_outcome` ما زال قابلًا للقراءة لمن لديه صف الحجز | لا تفتح ميزة التصويت الخاص قبل نشر/اختبار الحماية. عدم وجود حالات pending حاليًا لا يعالج تسريبها مستقبلًا |
| نظام احتساب النقاط | `reconcile_daily_elo_ratings()` يستخدم معادلة Elo تاريخية مختلفة عن 3/1/0 في trigger الحالي؛ 0 cron jobs تشير إليه، و0 confirmed غير معالجة | خطر كامن وليس فسادًا حاليًا مثبتًا؛ [حارس no-op مرشح واختبار SQL معزول](sql/challenge_legacy_elo_reconciliation_guard_candidate.sql) دون نشر |

## ربط المخاطر الفعلية ببوابات القبول

| عائلة الخطر | التصنيف من الدليل | أولوية متابعة | العمل المتبقي القابل للفحص |
|---|---|---|---|
| صلاحية مستخدم لقراءة/كتابة بيانات مستخدم آخر عبر RPC | **غير مثبت؛ يحتاج JWT حقيقي** | P0 إن ثبت تجاوز التفويض | 77.06, 77.07, 77.11 و79.02–79.06 مع حسابي لاعب/مالك منفصلين، anonymous، admin محظور |
| مسارات إلغاء/استرداد مالي تنفذ بصلاحيات مرتفعة | **دالة تفويض مفوّض مرصودة؛ أثر التجاوز غير مثبت** | P0 اختبار | اقرأ `cancel_booking_with_refund_atomic_impl`، `vsp.system_override`، القيمة الموثوقة للمبلغ، وغطّ إعادة المحاولة وملكية الحجز والـwebhook، 77.04/77.07 وB06 |
| 1v1 الدفع عبر `confirm_1v1_payment_atomic` | **بوابة `auth.role()='service_role'` مرصودة؛ صلاحية EXECUTE للـauthenticated وحدها لا تمنح نجاح الوظيفة** | P0 تحقق | إثبات server-only عبر JWT حقيقي وتوقيع webhook ورفض أي actor مختلف، دون اختبار تسوية حقيقية |
| عروض المستخدم/المالك | **حماية `security_invoker` المنشورة مثبتة على Staging** | P1 تكامل | إعادة فحص schema والمصدر عند النشر؛ اختبارات JWT أصلية عبر مالكين، بيانات خاصة ومنتجات عامة، خصوصًا بطولة clean sheets ذات عينة صفرية |
| عمليات الفرق/التحديات والنتائج | **كود مرشح مُختبر محليًا فقط** | P0 للإطلاق | انشر على Staging فقط بعد خطة عكس، اختبر اللاعبين والقائدين والتزامن والمالية والـRealtime والعرض العام |
| تحسين تحذيرات RLS Advisor | **44 initplan و51 multiple permissive تاريخيًا؛ لا دليل أن إصلاحها جميعًا آمن** | P1/P2 | 74.03–74.07 و75.04–75.07: قارن RLS الفعّال قبل/بعد ولا تدمج سياسات عشوائيًا |

## ما يُقبل وما لا يُقبل

**77.10 مكتمل كتقرير ربط فقط:** تجميع العدد الحالي، وأدلة العروض/الدوال، وسجل استثناءات 77.09، وIssue #37/#38 وPR #35، مع حالة تحقق، مسؤولية الفرق، وخطوات متابعة قابلة للإعادة. هذا مخرج مختلف عن وصف كل استثناء فردي (77.09).

**لا يُقبل بذلك:** إثبات أمان الـ200 وظيفة، إغلاق Issue #38، تطبيق إصلاح صلاحية، دفع/استرداد، اختبار سيناريوهات JWT حقيقية، أو تصريح Main/Release. الحالات المفتوحة تشمل 77.04، 77.06–77.08، 77.11، 78.04–78.05، 79.*, 80.04–80.08، ومهام النتائج 84.*, إلى أن يوجد دليل تشغيلي كامل.

**أدلة CI المشتركة (اختبارات كود/معزولة وليست JWT-Staging):** [Flutter CI 43777510189](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43777510189)، [Account SQL 43777510195](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43777510195)، [Owner Checkout 43777510205](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43777510205). فحص schema الحالي Select-only، دون استدعاء RPC مؤثر أو تغيير GRANT/RLS أو عمولات. هذا التقرير يضاف إلى Issue #38 وPR #35 للتتبع.
