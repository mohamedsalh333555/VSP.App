# تدقيق مكتبة المكونات واتساق الأنماط (`Component Library & Pattern Consistency Audit`)

**التخصصات المسؤولة:** Design System Architect (31)، Design System Designer (32)، Component Design Specialist (34)، Design Pattern Specialist (35)، Design Consistency Specialist (37).

---

## جدول مقارنة اتساق المكونات المشتركة عبر المنصات

| المكون | الحالة المرصودة فعليًا عبر الأدلة | التباين / الخلل المكتشف | التوصية (`PROPOSED DESIGN — NOT IMPLEMENTED`) |
|---|---|---|---|
| **الأزرار الرئيسية (`PrimaryButton` vs Dialogs)** | `PrimaryButton` يستخدم كبسولة كاملة (`StadiumBorder`) مع `FittedBox(scaleDown)`؛ بينما `ForgotPasswordDialog` (`11_`) يستخدم `radius: 16` | تذبذب حجم الخط بسبب `FittedBox` + اختلاط الأشكال الكبسولية بالمربعة داخل الشاشة الواحدة (`11_`) | توحيد شكل الـ CTA الرئيسي على `StadiumBorder`، واستخدام `maxLines: 2` بدل تصغير الخط العشوائي عبر `FittedBox`. |
| **حقول الإدخال (`CustomTextField` vs `DateOfBirth` vs Web Inputs)** | في `07_`, `08_`: حقل الميلاد بخلفية `surface` وصح خضراء `accent` مقابل بقية الحقول بخلفية `inputFill` وصح زرقاء `success`؛ وفي `12_web`, `13_web` تتعارض محاذاة الـ placeholders | تضارب بصري بين حقول النموذج الواحد وإشارتي صحة مختلفتي اللون | توحيد `SignupDateOfBirthField` مع `CustomTextField`، وتثبيت اتجاه `email/phone` في الويب. |
| **بطاقات المالية والتشغيل (`StatCard` & `OwnerFinanceCard`)** | في `Admin StatCard`: خلفية `bg-vsp-card` مطابقة لـ `bg-vsp-surface` (`#18181B`)؛ في التطبيق (`35_`): تكرار قيمة `300 ج.م` داخل إطارين متداخلين | انعدام الفصل العمقي بين البطاقة وحاوية الأيقونة في الإدارة، وتضخم التداخل في التطبيق | استخدام `surfaceRaised (#222227)` في الإدارة، وتسطيح البطاقة المتداخلة في التطبيق. |
| **الشارات الدلالية (`Badge.jsx` vs App Status Pills)** | `Badge.jsx` (`Admin`) يجعل `warning`, `blue`, `purple` رمادية مثل `default`؛ بينما `App` يستخدم أزرقًا وأخضر وعنبريًا بفاعلية إلا في شارة **`4.5 (0)`** بتفاصيل الملعب (`30_`) وشارات إنجليزية (`draft`, `active`, `cancelled`) | تعارض معاني الشارات في الإدارة، وعرض تقييم افتراضي `4.5` لملعب بلا تقييمات (`0`) | إعادة تفعيل ألوان `Badge.jsx` حسب الدلالة، وعرض `"ملعب جديد"` عند `reviews_count == 0`. |
| **قوائم الحساب (`VSPMenuItem`)** | عناوين البنود كلها خضراء `#9FDF02` في `23_` و`41_` وتستخدم `Radius.circular(20)` في `profile_screen.dart:99` | إجهاد بصري وفقدان التدرج مع زر الحفظ/الإجراء | جعل نصوص القائمة `textPrimary` مع التمييز الأحمر للخروج فقط وتوحيد الحافة على `32px` أو `24px`. |
