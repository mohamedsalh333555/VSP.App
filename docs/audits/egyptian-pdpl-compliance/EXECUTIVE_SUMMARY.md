# الملخص التنفيذي للامتثال لقانون حماية البيانات الشخصية المصري (PDPL) — مشروع VSP

**تاريخ آخر تحديث:** 2026-11-28  
**بيئة التحقق التقني:** مشروع Staging (`vtwgqyxglevcsxwdmhop` في منطقة `eu-west-2` بالمملكة المتحدة) + تحليل مستودعات `VSP.App` و`vsp_website` و`vsp-admin-panel`  
**المرجع الأساسي في الإنتاج:** مشروع Production (`mktqkddbcddrxjxabdua` في منطقة `eu-west-1` بأيرلندا — لم يتم التعديل عليه نهائيًا)  
**الوضع القانوني والإداري العام:** `PARTIALLY_COMPLIANT` (المضبوطات التقنية الأساسية مُفعّلة ومُصلحة، والامتثال التجاري الكامل موقوف على استكمال التراخيص والتصاريح والتوقيعات القانونية من المالك والمستشار القانوني `[LEGAL_REVIEW_REQUIRED]` / `[LICENSE_REQUIRED]`)

---

## 1. نطاق الحزمة وتقييم الجاهزية

تمتد هذه الحزمة على **22 وثيقة مرجعية** تغطي الجوانب التقنية والتشغيلية والقانونية لقانون حماية البيانات الشخصية المصري رقم **151 لسنة 2020** ولائحته التنفيذية الصادرة بقرار رئيس مجلس الوزراء رقم **816 لسنة 2025**:

- **ما تم التحقق منه تقنيًا (Verified Evidence):**
  - تفعيل سياسات عزل الصفوف (RLS) على **104 من 104** جدول في مخطط `public` و**10 من 10** جداول في مخطط `storage` داخل Staging.
  - فصل حاوية وثائق الملاك الحساسة (`owner_documents`, `public: false`) عن حاويات الصور العامة (`profile-pictures`, `stadium-images`).
  - التحقق الصارم من السن القانوني (`18+`) على مستوى الواجهة وقاعدة البيانات عبر `public.vsp_is_adult_date_of_birth` و`public.enforce_vsp_minimum_age` (`20261005020000_store_compliance_18_plus_and_owner_docs_hardening.sql`).
  - وجود آلية حذف نهائي آمنة للحساب داخل التطبيق (`public.delete_user_permanently`) تحمي الالتزامات المالية النشطة وتمنع الحذف الجزئي.
  - عدم تخزين بيانات البطاقات البنكية (PAN / CVV) داخل قواعد بيانات VSP، مع إسناد المعالجة لبوابة **Paymob** المتوافقة مع PCI-DSS.

- **الإصلاحات التقنية المنفذة في المرحلة الأولى (`660f1aee` & `1922fc5`):**
  1. إغلاق ثغرة وصول `anon` وتجاوز فحص `auth.uid() IS NULL` في الدالة المالية `public.import_paymob_reconciliation_row` وتشديد صلاحيات الدوال `trg_award_field_championship_xp` و`get_challenge_opponent_repeat_status` وتثبيت `search_path` للدوال `vsp_cairo_month_key` و`vsp_slice_avg_weight` وتحويل `public.immortal_winners_public` إلى `security_invoker = true` (`20261128080000_pdpl_and_security_advisor_remediation.sql`).
  2. إزالة ادعاء الامتثال الكامل غير الموثق لـ PDPL من شاشة `lib/features/player/screens/terms_and_privacy_screen.dart` لتتطابق مع `vsp_terms_and_privacy_modal.dart` (بعد تعديل ChatGPT `c0213c34`).
  3. توحيد نصوص الدفع الإلكتروني الكامل (100% Paymob)، وإزالة نصوص الحجز النقدي والعربون وحظر الكاش عند التغيب (2 no-shows) في التطبيق والموقع (`vsp_terms_and_privacy_modal.dart`, `vsp_website/src/locales/ar.ts`, `en.ts`).
  4. توحيد التفرقة العمرية بوضوح: **18 عامًا** فأكثر لحسابات اللاعبين والملاك على المنصة، و**21 عامًا** فأكثر للمفوضين بتوقيع التعاقدات التجارية للمنشآت الرياضية.

- **ما تبقى خارج نطاق التعديل الآلي (مُصنف بوضوح):**
  - `[TECHNICAL_BACKLOG]`: تفعيل الحماية ضد كلمات المرور المسربة (HIBP) يتطلب خطة Supabase Pro فأعلى (فشل التفعيل على Staging Free-tier برسالة `entitlement_required`). كما أن خدمة طعن التغيب بالسيلفي (`no_show_dispute_service.dart:208-213`) ترفع في مسار `disputes/` داخل `owner_documents` الخاص وتستخدم `getPublicUrl` بدل `createSignedUrl`.
  - `[LEGAL_REVIEW_REQUIRED]`: مراجعة واعتماد النصوص القانونية بواسطة محامٍ مصري، واستكمال بيانات السجل التجاري/البطاقة الضريبية والكيان القانوني، وتوقيع عقود معالجة البيانات (DPAs) مع الموردين.
  - `[LICENSE_REQUIRED]`: استخراج تراخيص المراقب/المعالج، وتسجيل مسؤول حماية البيانات (DPO)، والحصول على تصريح نقل البيانات عبر الحدود من مركز حماية البيانات الشخصية (PDPC).

---

## 2. فهرس ملفات الحزمة (22 وثيقة)

| # | الملف | الموضوع |
|---|---|---|
| 1 | `EXECUTIVE_SUMMARY.md` | الملخص التنفيذي وخريطة الأدلة |
| 2 | `02_LEGAL_GAP_MATRIX_151_2020_AND_816_2025.md` | مصفوفة الفجوات القانونية (قانون 151/2020 ولائحة 816/2025) |
| 3 | `03_DATA_INVENTORY_AND_CLASSIFICATION.md` | جرد وتصنيف البيانات عبر الـ 104 جداول وحاويات التخزين |
| 4 | `04_ROPA_PROCESSING_ACTIVITIES_REGISTER.md` | سجل أنشطة المعالجة (ROPA) لكل مسار بالمنصة |
| 5 | `05_LAWFUL_BASIS_AND_CONSENT_AUDIT.md` | الأساس القانوني وتدقيق آليات الموافقة الصريحة |
| 6 | `06_CROSS_BORDER_DATA_TRANSFER_ASSESSMENT.md` | تقييم نقل البيانات عبر الحدود (أيرلندا / بريطانيا / خدمات جوجل) |
| 7 | `07_THIRD_PARTY_PROCESSORS_AND_DPA_CHECKLIST.md` | المعالجون الخارجيون وقائمة التحقق لعقود DPA |
| 8 | `08_PRIVACY_POLICY_AND_TERMS_PARITY_AUDIT.md` | مطابقة نصوص الخصوصية والشروط بين التطبيق والموقع ولوحة الإدارة |
| 9 | `09_DSAR_AND_DATA_SUBJECT_RIGHTS_SOP.md` | إجراءات حقوق أصحاب البيانات وطلبات الوصول والمحو (DSAR) |
| 10 | `10_RETENTION_AND_SECURE_DELETION_SCHEDULE.md` | جدول مدد الاحتفاظ والحذف الآمن والالتزامات المالية |
| 11 | `11_TECHNICAL_SECURITY_AND_RLS_CONTROLS_REPORT.md` | تقرير الضوابط الأمنية التقنية ونتائج Security Advisors |
| 12 | `12_DPO_APPOINTMENT_CHARTER_AND_ROLE_SPEC.md` | ميثاق وتوصيف مسؤول حماية البيانات الشخصية (DPO) |
| 13 | `13_DATA_BREACH_INCIDENT_RESPONSE_PLAN_72H.md` | خطة الاستجابة لحوادث خرق البيانات (72 ساعة / 3 أيام عمل) |
| 14 | `14_DPIA_HIGH_RISK_PROCESSING_ASSESSMENT.md` | تقييم أثر حماية البيانات (DPIA) للعمليات عالية المخاطر |
| 15 | `15_CHILDRENS_AND_MINORS_PROTECTION_CONTROLS.md` | ضوابط حماية القُصّر ومنع التسجيل دون 18 عامًا |
| 16 | `16_MOBILE_PERMISSIONS_AND_SDK_PRIVACY_AUDIT.md` | تدقيق أذونات تطبيق الهاتف (GPS/الكاميرا/الإشعارات) والحزم البرمجية |
| 17 | `17_ADMIN_ACCESS_GOVERNANCE_AND_AUDIT_LOGGING.md` | حوكمة صلاحيات الإدارة وسجلات التدقيق (`system_audit_logs` و`financial_audit_logs`) |
| 18 | `18_WEBSITE_COOKIES_AND_FORMS_COMPLIANCE.md` | امتثال الموقع العام ونموذج حذف الحساب وملفات الارتباط |
| 19 | `19_PAYMOB_FINANCIAL_AND_KYC_COMPLIANCE_NOTE.md` | الحدود التقنية والمالية لبوابة Paymob وبيانات KYC للملاك |
| 20 | `20_PDPC_LICENSING_AND_FILING_PACK.md` | ملف التراخيص والتصاريح المطلوبة أمام مركز حماية البيانات الشخصية |
| 21 | `21_REMEDIATION_ROADMAP_TECH_VS_LEGAL.md` | خارطة طريق المعالجة (مسار تقني مقابل مسار قانوني/مؤسس) |
| 22 | `22_FOUNDER_ACTION_CHECKLIST_AND_SIGNOFF.md` | قائمة المهام التنفيذية للمؤسس قبل الإطلاق التجاري |
