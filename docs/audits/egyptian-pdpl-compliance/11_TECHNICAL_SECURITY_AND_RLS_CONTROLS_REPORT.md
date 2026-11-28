# تقرير الضوابط الأمنية التقنية وتدقيق قواعد البيانات (Technical Security & RLS Report)

**البيئة المفحوصة:** `vsp-staging` (`vtwgqyxglevcsxwdmhop`) — التحقق الفعلي قبل وبعد هجرة `20261128080000_pdpl_and_security_advisor_remediation.sql` (Commit `660f1aee`).

## 1. نتائج فحص عزل الصفوف (RLS Verification)
- **مخطط `public`:** تم التحقق عبر استعلام `pg_tables` من تفعيل RLS على **104 من 104 جداول** (`missing_rls = 0`).
- **مخطط `storage`:** تم التحقق من تفعيل RLS على **10 من 10 جداول** (`missing_rls = 0`).
- **فصل ملفات التحقق الحساسة:** حاوية `owner_documents` مضبوطة كحاوية خاصة (`public: false`) وبها سياسة `owner_documents_owner_manage` لمالك المجلد وحده.

## 2. نتائج فحص Supabase Security Advisors (قبل وبعد المعالجة)

| التنبيه الأمني | الحالة قبل المرحلة 1 | الإجراء المنفذ في `660f1aee` | الحالة بعد المرحلة 1 |
|---|---|---|---|
| `security_definer_view` (`public.immortal_winners_public`) `[ERROR]` | نشط (1 خطأ) | `ALTER VIEW public.immortal_winners_public SET (security_invoker = true);` | **تم الإغلاق (0 أخطاء)** |
| `function_search_path_mutable` (`vsp_cairo_month_key`, `vsp_slice_avg_weight`) `[WARN]` | 2 تحذيران | تثبيت `search_path = public, pg_temp` للدالتين | **تم الإغلاق (0 تحذيرات)** |
| `anon_security_definer_function_executable` (`import_paymob_reconciliation_row`) `[WARN + P0]` | قابل للتنفيذ من `anon` مع ثغرة `IF auth.uid() IS NOT NULL` تتجاوز التحقق! | تعديل جسم الدالة لمنع `auth.uid() IS NULL` لغير `service_role` + `REVOKE ALL FROM PUBLIC, anon` | **تم الإغلاق (`anon_import_paymob = false`)** |
| `anon_security_definer_function_executable` (`trg_award_field_championship_xp`, `get_challenge_opponent_repeat_status`) | قابلان للتنفيذ من `PUBLIC/anon` | `REVOKE ALL FROM PUBLIC, anon` (و`authenticated` لدالة التريجر) | **تم الإغلاق (`anon_trg = false`, `anon_repeat = false`)** |
| الدوال السبع العامة المتبقية (`calculate_booking_pricing_v2`, leaderboard/ranking/season helpers) | 7 تحذيرات `anon_security_definer` | دوال قراءة/حساب أسعار عامة مقصودة بدون كشف PII | **مقبولة وظيفيًا وموثقة** |
| `auth_leaked_password_protection` (`HaveIBeenPwned`) `[WARN]` | معطّل في Staging | محاولة التفعيل عبر Management API (`PATCH /config/auth`) | **مؤجل لـ Pro Plan:** رد الـ API الرسمي `entitlement_required` (متاح لخطة Pro فأعلى فقط) |

## 3. تحديث المرحلة الثانية — إصلاحات الحوكمة الأمنية P0 (`20261128090000_p0_security_definer_auth_hardening.sql`)
1. **إغلاق ثغرة `current_user` داخل دوال `SECURITY DEFINER` (`P0`):**
   - اكتُشف أن `current_user` داخل دوال `SECURITY DEFINER` المملوكة لـ `postgres` يُقيّم دائمًا كـ `'postgres'`، ما عطّل فحوصات الصلاحية في `import_paymob_reconciliation_row` وعدد 26 دالة وتريجر أخرى.
   - تم استبدال النمط بدالة `public.vsp_is_service_or_db_owner()` و`public.require_active_admin_actor()` و`public.require_owner_or_active_admin_actor()`، وتأكيد صفر استخدام تنفيذي متبقٍ لـ `current_user` على Staging، مع نجاح **35 من 35 اختبار HTTP حي** + اختبارات SQL (`docs/audits/evidence/staging_p0_auth_verification.md`).
2. **معالجة العروض والدوال المكشوفة:**
   - تحويل `admin_pending_refunds` و`admin_stadium_settlements` و`v_financial_reconciliation` إلى `security_invoker = true` (`views_without_invoker = 0`).
   - تحويل `get_server_timestamp()` إلى `SECURITY INVOKER` وإتاحتها لـ `anon` لحل خطأ `42501` قبل تسجيل الدخول بأمان.
3. **إغلاق نقطة ضعف صور طعون التغيب في `lib/core/services/no_show_dispute_service.dart`:**
   - تم تعديل مسار الرفع ليكون `${currentUid}/disputes/selfie_...` داخل `owner_documents` الخاصة المتوافقة مع سياسة `owner_documents_owner_manage` وإلغاء `getPublicUrl` بالكامل وحفظ مسار التخزين الخاص فقط.
4. **متبقيات `[TECHNICAL_BACKLOG]`:**
   - تفعيل `password_hibp_enabled = true` (HIBP) في الإنتاج عند ترقية الخطة إلى Supabase Pro (`entitlement_required` على الخطة المجانية).
   - إبقاء إضافات `extension_in_public` الأربع (`pg_net`, `http`, `btree_gist`, `pg_trgm`) كما هي للحفاظ على التوافقية.
