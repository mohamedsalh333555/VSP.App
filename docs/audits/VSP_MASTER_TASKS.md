# سجل المهام الموحد لمشروع VSP (Master Task Tracker)

**آخر تحديث:** 2026-11-28  
**المسؤول الفني والتدقيق:** Antigravity (بعد تجاوز ChatGPT Work لحد الاستخدام؛ دور ChatGPT لاحقًا مراجعة مستقلة فقط).  
**الفروع المفتوحة للمراجعة (دون دمج في `main` ودون لمس Production):**
- `VSP.App`: `feat/vsp-recovery-gamification-ds` (Draft PR #47)
- `vsp_website`: `feat/unify-commission-paymob-fees` (PR #5)
- `vsp-admin-panel`: `feat/unify-commission-paymob-fees` (PR #11)

---

## جدول تتبع المهام الرئيسية الثلاث والفرعيات

| Task ID | المهمة / المرحلة | الأولوية | الحالة | الاعتماديات (Dependencies) | معايير القبول (Acceptance Criteria) | دليل التنفيذ (Implementation Evidence) | دليل التحقق (Verification Evidence) | Commit SHA | العمل المتبقي (Remaining Work) |
|---|---|---|---|---|---|---|---|---|---|
| **T1-SYNC** | مزامنة تعديلات ChatGPT (`c0213c34`, `06200410`) والحفاظ على التعديلات المحلية | P0 | `DONE` | — | سحب التحديثات بـ Fast-forward دون Force Push أو فقدان تعديلات محلية | `git merge --ff-only` على `feat/vsp-recovery-gamification-ds` | `git log` يظهر `c0213c34` و`06200410` مدمجين بسلام | `06200410` | لا يوجد |
| **T1-SEC-DB** | معالجة تنبيهات Security Advisors الحرجة في `vsp-staging` | P0 | `DONE` | T1-SYNC | إزالة خطأ `security_definer_view`، تثبيت `search_path`، منع `anon` من `import_paymob_reconciliation_row` والتريجر | `supabase/migrations/20261128080000_pdpl_and_security_advisor_remediation.sql` | تطبيق على `vtwgqyxglevcsxwdmhop`؛ `security_definer_view=0`, `search_path_mutable=0`, `anon_import_paymob=false`, `anon_trg=false`, `anon_repeat=false`; HIBP API عاد بـ `entitlement_required` (خطة Pro+) | `660f1aee` | ترقية الإنتاج لخطة Pro+ وتفعيل `password_hibp_enabled` |
| **T1-COPY** | توحيد نصوص الدفع الأونلاين والسن القانوني وإزالة ادعاء PDPL غير الموثق | P0 | `DONE` | T1-SYNC | خلو نافذة وشاشة الشروط في التطبيق ونص No-Show في الموقع من الكاش والعربون وتناقض السن | `vsp_terms_and_privacy_modal.dart`, `terms_and_privacy_screen.dart`, `vsp_website/src/locales/{ar,en}.ts` | `flutter analyze --no-pub` (0 issues)، 81/81 اختبار Flutter ناجح، `vsp_website` build (17/17 pages)، `vsp_admin_panel` vite build | `660f1aee` (`VSP.App`), `1922fc5` (`vsp_website`) | مواءمة النصوص التسويقية القديمة في `vsp_website` عند الطلب |
| **T2-PDPL** | إعداد حزمة الامتثال الكاملة للقانون المصري 151/2020 ولائحة 816/2025 (22 ملفًا) | P0 | `DONE` | T1-SEC-DB, T1-COPY | 22 ملفًا عربيًا متكاملًا تفصل الإصلاحات التقنية عن التزامات المؤسس والمحامي والتراخيص دون ادعاءات كاذبة | `docs/audits/egyptian-pdpl-compliance/` (`EXECUTIVE_SUMMARY.md` + `02_` إلى `22_`) | فحص فعلي لـ 104 جداول و3 حاويات وEdge Functions و`AndroidManifest.xml` و`delete_user_permanently` | قيد الرفع في Commit المرحلة 2 | تنفيذ المسار القانوني/التراخيص من المؤسس + بنود `TECHNICAL_BACKLOG` بعد الإطلاق/الموافقة |
| **T3-AUDIT** | المراجعة البصرية الشاملة بواسطة لجنة الـ 50 خبير تصميم (قراءة فقط — صفر تعديلات كود) | P1 | `IN_PROGRESS` | T1-COPY, T2-PDPL | صور حقيقية لجميع الشاشات المتاحة (`vsp_website`, `vsp-admin-panel`, Flutter Web/Android) + مقترحات Before/After + توثيق `NOT VISUALLY VERIFIED` لما تعذر الوصول إليه + صفر تعديلات كود | سيُنشأ في `docs/audits/visual-design-audit/` | قيد التنفيذ (تشغيل الخوادم والتقاط الصور عبر المتصفح/المحاكي) | — | تشغيل الواجهات، التقاط Screenshots، إعداد تقرير الـ 50 خبيرًا |
| **T4-HANDOFF** | التحقق المستقل النهائي وبناء `EVIDENCE_MANIFEST.json` وتسليم الفروع | P0 | `PENDING` | T3-AUDIT | التحقق من عدم وجود تعديلات كود في المرحلة 3، خلو الأسرار، تحديث `EVIDENCE_MANIFEST.json` والرد النهائي بالأدلة | سيُنشأ في `docs/audits/EVIDENCE_MANIFEST.json` و`VSP_HANDOFF.md` | قيد الانتظار | — | مراجعة نهائية ورفع على فروع PR |
