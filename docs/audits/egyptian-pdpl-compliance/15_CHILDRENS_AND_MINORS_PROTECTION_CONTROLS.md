# ضوابط حماية القُصّر والأهلية العمرية (Children & Minors Protection Controls)

**المرجع القانوني:** المادة (2) من قانون حماية البيانات الشخصية المصري رقم 151 لسنة 2020 (التزامات حماية بيانات الأطفال وموافقة الولي الطبيعي)، والقانون المدني المصري (سن الرشد 21 سنة للتعاقد التجاري الكامل)، وسياسات متاجر التطبيقات (18+).

## 1. الضوابط التقنية المفعّلة حاليًا (Verified)
1. **منع التسجيل دون 18 عامًا في التطبيق:**
   - واجهة اختيار تاريخ الميلاد في `signup_screen.dart:75` تقصر الحد الأقصى للسنة على `DateTime.now().year - 18`.
   - دالة التحقق `SignupValidationService` (مختبرة في `signup_validation_service_test.dart`: 11 اختبارًا ناجحًا بما فيها اختبار حد يوم الميلاد الدقيق `isAtLeast18 handles the exact birthday boundary`).
2. **الحماية الصارمة في قاعدة البيانات (Defense in Depth):**
   - الهجرة `20261005020000_store_compliance_18_plus_and_owner_docs_hardening.sql`:
     - دالة `public.vsp_is_adult_date_of_birth(p_dob)` تتحقق من الصيغة والتاريخ وتفرض `age >= 18`.
     - التريجر `aaa_trg_enforce_vsp_minimum_age` (`BEFORE INSERT OR UPDATE` على `public.users`) يرفض أي صف يخص `player` أو `owner` إذا كان العمر أقل من 18 أو إذا اكتمل التسجيل بدون تاريخ ميلاد صالح (`REGISTRATION_REQUIRES_18_PLUS` / `VSP_AGE_RESTRICTED`).
     - دالة `complete_user_registration` تتحقق مجددًا من تاريخ الميلاد للقادمين عبر Google OAuth.
3. **اتساق النصوص القانونية (تم توحيدها في `660f1aee`):**
   - التطبيق (`vsp_terms_and_privacy_modal.dart`, `terms_and_privacy_screen.dart`) والموقع (`privacy_age_restriction_desc`, `terms_age_restriction_desc`) متفقان الآن على: **18 عامًا فأكثر** لاستخدام المنصة وإجراء الحجوزات، و**21 عامًا فأكثر** للمفوض بتوقيع التعاقدات التجارية للمنشآت الرياضية.

## 2. القيود المتبقية
- تعتمد المنصة للاعبين على **الإقرار الذاتي بتاريخ الميلاد** (Self-declaration) دون طلب بطاقة رقم قومي من اللاعبين (تطبيقًا لمبدأ تقليل البيانات Data Minimization). أما الملاك المفوضون فيخضعون للتحقق الوثائقي عبر `owner_documents`.
- إذا ورد بلاغ أو ثبت أن صاحب حساب قاصر (دون 18 عامًا) أدخل تاريخًا غير صحيح، يجب تجميد الحساب فورًا وحذف بياناته بعد تصفية أي مستحقات وفق إجراءات الدي إس إيه آر (DSAR).
