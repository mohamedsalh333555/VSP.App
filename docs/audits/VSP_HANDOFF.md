# ملف التسليم والمراجعة المستقلة — VSP Handoff

**مرجع المراجعة:** تم إنجاز المراحل الأربع (المزامنة وإغلاق الثغرات + حزمة الامتثال المصري PDPL + المراجعة البصرية للـ 50 خبيرًا + التحقق النهائي) على فروع المراجعة دون أي دمج في `main` ودون أي مساس ببيئة الإنتاج (`mktqkddbcddrxjxabdua`).

---

## 1. ملخص التصنيف النهائي بالبراهين

### أ. مُنفَّذ تقنيًا ومُتحقَّق منه (Completed & Technically Remediated)
1. **مزامنة التعديلات السابقة (`06200410`):** دمج `c0213c34` و`06200410` بـ Fast-forward دون Force Push مع الحفاظ على التعديلات المحلية.
2. **تأمين قاعدة بيانات Staging (`660f1aee`):**
   - تطبيق الهجرة `20261128080000_pdpl_and_security_advisor_remediation.sql` على `vtwgqyxglevcsxwdmhop`.
   - إغلاق ثغرة `auth.uid() IS NULL` وسحب صلاحية `anon` من الدالة المالية `import_paymob_reconciliation_row` وتريجر `trg_award_field_championship_xp` ودالة `get_challenge_opponent_repeat_status`.
   - تثبيت `search_path` لـ `vsp_cairo_month_key` و`vsp_slice_avg_weight` وإصلاح `immortal_winners_public` (`security_invoker = true`).
3. **توحيد النصوص القانونية والعمرية والدفع الأونلاين (`660f1aee` و`1922fc5`):**
   - إزالة الادعاء غير الموثق للامتثال الكامل لـ PDPL من `terms_and_privacy_screen.dart` (بعد المودال).
   - إزالة النصوص القديمة للحجز النقدي والعربون وحظر الكاش عند 2 غياب من `vsp_terms_and_privacy_modal.dart` و`vsp_website/src/locales/{ar,en}.ts`.
   - توحيد السن: `18+` لاستخدام المنصة، و`21+` للتعاقد التجاري للمنشأة.
   - استبدال الخلفية الخضراء الزخرفية لأيقونات البطاقات في المودال بأسطح محايدة.
4. **حزمة الامتثال المصري PDPL 151/2020 ولائحة 816/2025 (`e23f7165`):** 22 وثيقة شاملة داخل `docs/audits/egyptian-pdpl-compliance/`.
5. **المراجعة البصرية للـ 50 خبيرًا (`b3bb9c41` — صفر تعديلات كود):** 10 تقارير + 15 لقطة شاشة حقيقية على محاكي `Pixel_9` (`app.vsp.sports.staging`).

### ب. شاشات لم تُعاين بصريًا بالصورة (`NOT VISUALLY VERIFIED`) وسببها
- **الموقع العام (`vsp_website`):** تعذر الاتصال بـ Chrome DevTools (`DevToolsActivePort` غير موجود لأن `chrome://inspect/#remote-debugging` غير مفعّل)؛ تم التحقق ببناء `next build` (17/17 صفحة) وفحص المكونات.
- **لوحة الإدارة (`vsp-admin-panel`):** محجوبة بتسجيل دخول Google للمشرف + `CHROME_DEVTOOLS_DISCONNECTED`؛ تم التحقق ببناء `vite build` وفحص الصفحات.
- **شاشات اللاعب والمالك الداخلية + iOS:** محجوبة خلف المصادقة (`AUTH_GATED`) وعدم توفر جهاز iOS على نظام Windows.

### ج. محظورات تقنية موثقة (`BLOCKED / TECHNICAL_BACKLOG`)
- **`auth_leaked_password_protection` (HIBP):** رفض Supabase Management API التفعيل على Staging (`entitlement_required`: مخصص لخطة Pro فأعلى).
- **مسار تقني مؤجل (`TECHNICAL_BACKLOG`):** `no_show_dispute_service.dart:207-218` يرفع في `owner_documents` ويستدعي `getPublicUrl`، و`PricingClient.tsx:77` يثبت رابط الإنتاج مباشرة، بالإضافة لتوصيات التوكنز والخطوط العربية الموثقة في المرحلة 3 (`PROPOSED DESIGN — NOT IMPLEMENTED`).

### د. متطلبات قانونية وتنظيمية على المؤسس والمحامي (`LEGAL_REVIEW_REQUIRED` / `LICENSE_REQUIRED`)
- انظر القائمة التنفيذية المباشرة في [`egyptian-pdpl-compliance/22_FOUNDER_ACTION_CHECKLIST_AND_SIGNOFF.md`](egyptian-pdpl-compliance/22_FOUNDER_ACTION_CHECKLIST_AND_SIGNOFF.md) (المحامي، السجل التجاري/الضريبي، تعيين وتسجيل DPO، تراخيص مركز حماية البيانات PDPC وتصريح نقل البيانات لـ `eu-west-1` وFirebase، وعقود DPA و2FA للإدارة).
