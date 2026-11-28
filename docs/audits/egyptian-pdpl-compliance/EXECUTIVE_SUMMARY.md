# الملخص التنفيذي للامتثال لقانون حماية البيانات الشخصية المصري (PDPL) — مشروع VSP

**تاريخ آخر تحديث:** 2026-11-28  
**بيئة التحقق التقني:** مشروع Staging (`vtwgqyxglevcsxwdmhop` في منطقة `eu-west-2` بالمملكة المتحدة) + تحليل مستودعات `VSP.App` و`vsp_website` و`vsp-admin-panel`  
**المرجع الأساسي في الإنتاج:** مشروع Production (`mktqkddbcddrxjxabdua` في منطقة `eu-west-1` بأيرلندا — لم يتم التعديل عليه نهائيًا)  
**الوضع القانوني والإداري العام:** `PARTIALLY_COMPLIANT` (المضبوطات التقنية الأساسية مُفعّلة ومُصلحة، والامتثال التجاري الكامل موقوف على استكمال التراخيص والتصاريح والتوقيعات القانونية من المالك والمستشار القانوني `[LEGAL_REVIEW_REQUIRED]` / `[LICENSE_REQUIRED]`)

---

## 1. نطاق الحزمة وتقييم الجاهزية

تمتد هذه الحزمة على **23 وثيقة مرجعية** تغطي الجوانب التقنية والتشغيلية والقانونية لقانون حماية البيانات الشخصية المصري رقم **151 لسنة 2020** ولائحته التنفيذية الصادرة بقرار وزير الاتصالات وتكنولوجيا المعلومات رقم **816 لسنة 2025** (صدر في **1 نوفمبر 2025** ويعمل به من **2 نوفمبر 2025**):

- **ما تم التحقق منه تقنيًا (Verified Evidence):**
  - تفعيل سياسات عزل الصفوف (RLS) على **104 من 104** جدول في مخطط `public` و**10 من 10** جداول في مخطط `storage` داخل Staging.
  - فصل حاوية وثائق الملاك الحساسة (`owner_documents`, `public: false`) عن حاويات الصور العامة (`profile-pictures`, `stadium-images`).
  - التحقق الصارم من السن القانوني (`18+`) على مستوى الواجهة وقاعدة البيانات عبر `public.vsp_is_adult_date_of_birth` و`public.enforce_vsp_minimum_age` (`20261005020000_store_compliance_18_plus_and_owner_docs_hardening.sql`).
  - وجود آلية حذف نهائي آمنة للحساب داخل التطبيق (`public.delete_user_permanently`) تحمي الالتزامات المالية النشطة وتمنع الحذف الجزئي.
  - عدم تخزين بيانات البطاقات البنكية (PAN / CVV) داخل قواعد بيانات VSP، مع إسناد المعالجة لبوابة **Paymob** المتوافقة مع PCI-DSS.

- **الإصلاحات التقنية المنفذة والموثقة (`660f1aee`, `1922fc5` + حزمة التصلب P0 في `20261128090000`):**
  1. **إغلاق ثغرة `current_user` داخل دوال `SECURITY DEFINER` بالكامل (`20261128090000_p0_security_definer_auth_hardening.sql`):**
     - استبدال فحص `current_user` غير الموثوق بدالة `public.vsp_is_service_or_db_owner()` و`public.require_active_admin_actor()` في `import_paymob_reconciliation_row` و**26 دالة وتريجر** مالية وإدارية أخرى (تشمل `request_owner_payout_settlement_atomic` و`owner_create_manual_booking_atomic` و`create_booking_atomic` و`get_owner_dashboard_analytics` و`get_owner_financial_summary` وتريجرز حماية الحجوزات والفرق والملاعب والبطولات).
     - إثبات الإغلاق فعليًا على `vsp-staging` باختبار **35 حالة HTTP سلبية وإيجابية** (رفض `anon` و`authenticated` بلا سجل و`player` و`owner` و`blocked_admin`، وقبول `active_admin` و`service_role` فقط) + اختبار SQL عبر `SET LOCAL ROLE authenticated` (تفاصيل في `docs/audits/evidence/staging_p0_auth_verification.md`).
  2. إغلاق التحذيرات الأمنية المتبقية في `vsp-staging`: تحويل 3 عروض مالية (`admin_pending_refunds`, `admin_stadium_settlements`, `v_financial_reconciliation`) مع `immortal_winners_public` إلى `security_invoker = true` (أصبح `views_without_invoker = 0`)، وإتاحة `get_server_timestamp()` كـ `SECURITY INVOKER` لـ `anon` لحل خطأ `42501` قبل تسجيل الدخول بأمان.
  3. **إصلاح وصول حاوية `owner_documents` في `lib/core/services/no_show_dispute_service.dart`:** تغيير مسار الرفع إلى `${currentUid}/disputes/...` ليتوافق مع سياسة العزل (`folder[1] = auth.uid()`) وإلغاء استدعاء `getPublicUrl` على الحاوية الخاصة، دون جعل الحاوية عامة.
  4. **إزالة رابط الإنتاج الثابت من `vsp_website/src/app/pricing/PricingClient.tsx` و`server.ts`:** مع التحقق من أن مسار `/pricing` يُحوّل تلقائيًا إلى `/` بعد إيقاف باقات اشتراكات الملاك (`create_paymob_intention` يرد `410`).
  5. إزالة ادعاء الامتثال الكامل غير الموثق لـ PDPL من `terms_and_privacy_screen.dart` وتوحيد نصوص الدفع الإلكتروني الكامل (100% Paymob) والتفرقة العمرية (`18+` للحسابات و`21+` للتفويض التجاري).

- **ما تبقى خارج نطاق التعديل الآلي (مُصنف بصراحة كاملة):**
  - `[TECHNICAL_BACKLOG]`: تفعيل الحماية ضد كلمات المرور المسربة (HIBP) يتطلب خطة Supabase Pro فأعلى (فشل التفعيل على Staging Free-tier برسالة `entitlement_required`؛ لم يتم شراء أو تعديل خطط مدفوعة دون إذن).
  - `[LEGAL_REVIEW_REQUIRED]`: مراجعة واعتماد النصوص القانونية بواسطة محامٍ مصري، واستكمال بيانات السجل التجاري/البطاقة الضريبية والكيان القانوني، وتوقيع عقود معالجة البيانات (DPAs) مع الموردين.
  - `[LICENSE_REQUIRED]`: استخراج تراخيص المراقب/المعالج، وتسجيل مسؤول حماية البيانات (DPO)، والحصول على تصريح نقل البيانات عبر الحدود من مركز حماية البيانات الشخصية (PDPC).

---

## 2. فهرس ملفات الحزمة (23 وثيقة)

| # | الملف | الموضوع |
|---|---|---|
| 0 | `EXECUTIVE_SUMMARY.md` | الملخص التنفيذي وخريطة الأدلة |
| 1 | `01_DATA_FLOW_DIAGRAM_DFD.md` | مخطط تدفق البيانات الشخصية (DFD) ومسارات النقل عبر الحدود |
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
