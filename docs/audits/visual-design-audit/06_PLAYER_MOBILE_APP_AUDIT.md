# التدقيق البصري لتطبيق اللاعب وشاشات الدخول — Player App & Auth Visual Audit

**بيئة التشغيل الحية:** `Pixel_9` Android Emulator (`1080x2424`) مع نكهة Staging (`app.vsp.sports.staging`) المتصلة حصريًا ببيئة Staging (`vtwgqyxglevcsxwdmhop`).  
*(ملاحظة: شاشات اللاعب الداخلية بعد تسجيل الدخول موثقة أدناه عبر فحص الكود، وتُصنّف معاينتها البصرية الحية بـ `NOT VISUALLY VERIFIED (AUTH_GATED)` إذا لم يتوفر حساب دخول تجريبي في بيئة الاختبار دون تعديل بيانات المستخدمين).*

---

## الملاحظات البصرية والحلول المقترحة (`PROPOSED DESIGN — NOT IMPLEMENTED`)

### `VSP-PLY-001` — تشويه التباعد الحرفي العربي (`letterSpacing: -1 / 1.2`) وارتفاع السطر الضيق (`0.9 / 1.0`) ووزن `w300` غير المضمن وصغر زر الموقع [HIGH]
- **التخصصات:** Arabic Typography Designer (48)، Typography Designer (19)، Accessibility Designer (47)، Mobile Interface Designer (12).
- **الدليل الفعلي (`create_account_screen.dart:124-136`، `signup_screen.dart:260-266, 312-315`، `login_screen.dart:141-142, 171`، `welcome_onboarding_slide.dart:120`، و`pubspec.yaml:131-145`):**
  - شاشة إنشاء الحساب (`CreateAccountScreen`) تفرض `height: 0.9` و`letterSpacing: -1` على التحية الكبرى (`46px`)، وتحتها `letterSpacing: 1.2` و`FontWeight.w300` (في حين أن حزمة الخطوط تحتوي فقط على `400 / 500 / 700`!).
  - عناوين أقسام `SignupScreen` و`LoginScreen` تفرض `letterSpacing: 1.1`، وعنوان الترحيب `letterSpacing: -0.5`، وعنوان تسجيل الدخول `height: 1.0` — ما يكسر انسيابية الخط العربي.
  - أيقونة التحديد الجغرافي التلقائي `Iconsax.gps_copy` داخل `GestureDetector` بحجم `18px` دون padding مما يجعل هدف اللمس دون الحد الأدنى (`48dp`).
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):**
  - **قبل:** `letterSpacing` موجبة وسالبة + `height: 0.9–1.0` + أوزان خطوط غير محزومة (`w300, w800, w900`) + أيقونة `18px`.
  - **بعد:** `letterSpacing: isAr ? 0.0 : ...` مع `height >= 1.25–1.35` للعناوين العربية، وحصر الأوزان على `400/500/700` (أو تضمين `Tajawal-ExtraBold` في `pubspec.yaml`) + غلاف `IconButton` بأبعاد `48x48dp`.

### `VSP-PLY-002` — شاشة اختيار الدور (`SelectRoleScreen`) وورقة اختيار الدور (`LoginFooter`) غير مترجمتين للإنجليزية [HIGH]
- **التخصصات:** RTL and Localization Designer (49)، Design QA Engineer (38).
- **الدليل الفعلي (`lib/features/auth/screens/select_role_screen.dart:49-80` و`lib/features/auth/widgets/login_footer.dart:77-98`):** جميع النصوص (`أنت هنا عشان إيه؟`، `إنشاء حساب جديد`، `لاعب`، `صاحب ملعب`، `عندك حساب تاني؟`) مكتوبة بالعربية العامية مباشرة دون استخدام `AppLocalizations`، فتظهر بالعربية حتى عند اختيار لغة التطبيق الإنجليزية.
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):** نقل كافة السلاسل إلى `app_ar.arb` و`app_en.arb` عبر `AppLocalizations` وتوحيد تصميم البطاقات بين الشاشتين.

### `VSP-PLY-007` — زر التأكيد في نافذة نسيت كلمة المرور يكسر شكل الكبسولة المعتمد [LOW]
- **التخصصات:** Design Consistency Specialist (37)، Component Design Specialist (34).
- **الدليل الفعلي (`lib/features/auth/widgets/forgot_password_dialog.dart:90-96`):** يستخدم `BorderRadius.circular(VSPRadius.md)` (`16px`) بدل `StadiumBorder` / `VSPDSRadius.button = full` المعتمد في `PrimaryButton` (`primary_button.dart:67`).
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):** استخدام `PrimaryButton` أو `StadiumBorder()` مع `VSPColors.background` للون النص فوق `VSPColors.accent`.

### `VSP-PLY-008` — طغيان النص الأخضر على كل بنود قائمة الإعدادات (`VSPMenuItem`) وعدم اتساق حقل الميلاد [HIGH]
- **التخصصات:** Visual Hierarchy Specialist (18)، Digital Art Director (11)، Component Design Specialist (34).
- **الدليل الفعلي (`lib/core/ui/components/vsp_menu_item.dart:50-67` و`signup_date_of_birth_field.dart:37-55`):**
  - `VSPMenuItem` يلوّن **كل عناوين القائمة (`title`) باللون الأخضر النيوني `#9FDF02`** بدل `VSPDSSemanticColors.textPrimary` (`#E4E4E7`)، مما يفقد الشاشة تدرجها البصري ويزاحم أزرار الإجراءات الحقيقية.
  - حقل تاريخ الميلاد (`SignupDateOfBirthField`) يستخدم خلفية `VSPColors.surface` وحدًا `accent.withValues(alpha: 0.1)` وعلامة صح خضراء `accent`، بينما باقي الحقول (`CustomTextField`) تستخدم `inputFill` وحد `divider` وعلامة صح زرقاء `VSPColors.success`.
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):**
  - جعل `title` في `VSPMenuItem` بلون `textPrimary` مع أيقونة محايدة `textSecondary` (وتمييز الخروج فقط بالأحمر `error`)، وتوحيد خلفية وحدود وعلامة صحة `SignupDateOfBirthField` مع `CustomTextField`.

### `VSP-PLY-009` — فرض `TextDirection.ltr` على السعر داخل شريط الحجز العربي وخط `10px` [MEDIUM]
- **التخصصات:** RTL and Localization Designer (49)، Accessibility Designer (47).
- **الدليل الفعلي (`stadium_bottom_booking_bar.dart:46-75` و`profile_screen.dart:99`):** يفرض `Directionality(textDirection: TextDirection.ltr)` على السعر (`350 ج.م`) مع شارة `"دفع إلكتروني فوري 100%"` بحجم `10px` فقط! كما يستخدم `profile_screen.dart:99` حافة `Radius.circular(20)` بدل `VSPRadius.bottomSheet = 32`.

### `VSP-PLY-010` — انعكاس ترتيب خانات رمز التحقق (OTP) في الوضع العربي RTL [CRITICAL]
- **التخصصات:** RTL and Localization Designer (49)، Mobile Interface Designer (12)، Design QA Engineer (38).
- **الدليل الفعلي (`lib/features/auth/screens/verify_email_screen.dart:250-262`):**
  - صف الـ 6 خانات (`Row` من `OtpBox` بدون غلاف `Directionality(textDirection: TextDirection.ltr)`) ينعكس تلقائيًا في اللغة العربية؛ فعند إدخال الكود الرقمي `123456` يوضع الرقم الأول في أقصى اليمين ويتحرك التركيز نحو اليسار ليظهر بصريًا `654321`!
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):**
  - **قبل:** `Row(children: List.generate(6, ...))` يرث اتجاه RTL.
  - **بعد:** تغليف `Row` الخانات بـ `Directionality(textDirection: TextDirection.ltr, child: Row(...))` دائمًا لأن رموز OTP تُقرأ وتُكتب من اليسار لليمين عالميًا.

### `VSP-PLY-003` — تقلص زر "تخطي" (`Skip`) في شاشة الترحيب دون حد اللمس `48dp` [MEDIUM]
- **التخصصات:** Accessibility Designer (47)، Mobile Interface Designer (12).
- **الدليل الفعلي (`lib/features/auth/screens/welcome_screen.dart:164-180`):** استخدام `minimumSize: Size.zero` و`MaterialTapTargetSize.shrinkWrap` على `TextButton` يجعل منطقة النقر أصغر من `48x48dp`.
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):** الإبقاء على `minimumSize: const Size(48, 44)` مع حشوة واضحة.

### `VSP-PLY-004` — تذبذب إيقاع المسافات الرأسية في الرئيسية (`10 -> 14 -> 16`) ومسافات زائدة بنصوص الحالة الفارغة [LOW]
- **التخصصات:** Layout and Composition Designer (17)، Design Consistency Specialist (37).
- **الدليل الفعلي (`home_feed_content.dart:35-42` و`home_stadiums_section.dart:58, 61, 80`):**
  - `SizedBox(height: 10)` -> `14` -> `16` بدل إيقاع موحد (`VSPDSSpacing.sm = 12` / `md = 16`).
  - فراغ نصي زائد في نهاية `"لم نصل إلى $cityName بعد! "` و`"اقترح ملعباً في منطقتك "` وأيقونة موقع خضراء كبيرة `64px` بنسبة شفافية `0.3` بدل رمز محايد.

### `VSP-PLY-005` — تصغير نص زر `PrimaryButton` عبر `FittedBox` ومشاكل شاشة الشروط [LOW/MEDIUM]
- **التخصصات:** Component Design Specialist (34)، Typography Designer (19)، Dark Mode Designer (46).
- **الدليل الفعلي (`primary_button.dart:94-97` و`terms_and_privacy_screen.dart:42, 51, 239`):**
  - `FittedBox(fit: BoxFit.scaleDown)` يغيّر حجم خط CTA من زر لآخر عند اختلاف طول الكلمات.
  - `terms_and_privacy_screen.dart` ما زال يستخدم `Colors.white` مباشرة بدل `VSPColors.textPrimary` وإطارًا أخضرًا خافتًا حول البطاقة الترحيبية الثابتة.

### `VSP-PLY-006` — تحذير خط غير مستخدم في بناء Flutter Web (`CupertinoIcons`) [LOW]
- **التخصصات:** Design QA Engineer (38)، Design Technologist (36).
- **الدليل الفعلي (مخرجات `flutter build web --release`):** تحذير `Expected to find fonts for (packages/iconsax_flutter/FlutterIconsax, MaterialIcons, packages/cupertino_icons/CupertinoIcons), but found (MaterialIcons, packages/iconsax_flutter/FlutterIconsax)`.

---

## سجل اللقطات الفعلية الملتقطة على `Pixel_9` (`app.vsp.sports.staging`)

تم التقاط **15 لقطة شاشة حقيقية** على محاكي `Pixel_9` (`1080x2424`, Skia Android `enable-impeller=false`) ومراجعتها بصريًا بالبكسل:

1. `01_welcome_slide1.png` — شاشة الترحيب 1 (EN): أكّد الـ `uiautomator` وجود **`NAF="true"` و`content-desc=""`** على زر المتابعة الدائري الأخضر (`[875,2177][1017,2319]`)، بالإضافة إلى زر `Skip` دون كبسولة حماية التباين فوق الصورة، وفراغ أسود واسع أسفل النص.
2. `02_welcome_slide2_en.png` — شاشة الترحيب 2 (EN): نفس الفراغ السفلي الواسع و`VSPBackButton` في الأعلى بدون `content-desc` (`NAF="true"`).
3. `03_welcome_slide3_en.png` و`04_welcome_slide3_ar.png` — شاشة الترحيب 3 (EN & AR): تم التحقق من انعكاس RTL للأزرار (`لاعب` / `صاحب ملعب`)، مع تكدس طفيف في `"جاهز للبداية؟!"` بسبب `letterSpacing: -0.5` وصغر منطقة لمس رابط `Login` (`[745,2124][850,2171]`, ارتفاع ~18dp).
4. `05_create_account_player_ar.png` و`13_create_account_owner_ar.png` — إنشاء حساب (لاعب / مالك): **إثبات بصري قاطع** لتفكك الحروف العربية في `"إ ن ش ا ء   ح س ا ب   ج د ي د"` نتيجة `letterSpacing: 1.2 + FontWeight.w300`، وتقاطع خط التسطير (`underline`) مع نقاط `"شروط_الخدمة و سياسة_الخصوصية"`، والتفاف عنوان المالك `"مرحباً بصاحب الملعب"` على سطرين.
5. `06_terms_modal_player_ar.png` و`14_terms_modal_owner_ar.png` — نوافذ الشروط والخصوصية (لاعب / مالك): التحقق البصري الكامل من نجاح تعديل المرحلة 1 (شارات أيقونات محايدة، وضوح 18+/21+، والدفع الأونلاين 100% Paymob)، مع ملاحظة إملائية طفيفة (`إلتزامات` -> `التزامات`) واستمرار اللون الأخضر النصي داخل الشريط العلوي الثابت.
6. `07_signup_player_ar.png`، `08_signup_player_bottom_ar.png`، `15_signup_owner_ar.png` — شاشات التسجيل (لاعب / مالك): **إثبات بصري قاطع** لظهور اسم المحافظة بالإنجليزية (`"Cairo"` ثم `"Matrouh"` بعد الجلب التلقائي لـ GPS) داخل نموذج عربي RTL 100%! وتباين خلفية وحدود حقل `تاريخ الميلاد` عن بقية الحقول، وضيق زر `"حارس مرمى"`.
7. `09_vsp_date_picker_ar.png` — منتقي تاريخ الميلاد 3 خطوات: تدرج RTL سليم بين `السنة / الشهر / اليوم`، لكن عنصر `"2001"` أسفل القائمة يُقطع حادًا فوق زر `"تأكيد التاريخ"` دون تدرج تلاشي (`fade gradient`).
8. `10_login_ar.png` و`11_forgot_password_dialog_ar.png` — شاشة الدخول ونافذة نسيت كلمة المرور: أيقونة إظهار كلمة المرور تفتقد `content-desc` (`NAF="true"`)، ونافذة نسيت كلمة المرور تعرض بوضوح زر `"إرسال"` بزوايا مربعة (`16px`) فوق زر `"تسجيل دخول"` الكبسولي (`pill`) بالخلفية!
9. `12_global_error_screen_ar.png` — شاشة الخطأ العام: ظهرت فعليًا عند الانتقال المتسارع من التسجيل/النوافذ، وتُظهر نصًا إنجليزيًا وسط الواجهة العربية مع خطأ اتجاه النقطة `.been notified` وزر `"Try Again"` غير المترجم! *(تم التحقق تقنيًا بإغلاق الشاشة عبر Try Again والعودة بسلام).*
