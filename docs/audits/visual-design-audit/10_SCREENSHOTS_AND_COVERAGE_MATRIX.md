# سجل اللقطات الفعلية ومصفوفة التغطية البصرية (Screenshots & Coverage Matrix)

## 1. اللقطات الفعلية الملتقطة والمُتحقَّق منها (`Pixel_9` Android Emulator — `1080x2424`)

| # | الملف | الشاشة / الحالة | اللغة والاتجاه | أبرز الملاحظات المرصودة بالصورة |
|---|---|---|---|---|
| 1 | [01_welcome_slide1.png](screenshots/android/01_welcome_slide1.png) | شاشة الترحيب — الشريحة 1 | EN (`LTR`) | زر المتابعة الأخضر بلا `content-desc` (`NAF="true"`), وزر `Skip` دون كبسولة تباين، وفراغ سفلي كبير |
| 2 | [02_welcome_slide2_en.png](screenshots/android/02_welcome_slide2_en.png) | شاشة الترحيب — الشريحة 2 | EN (`LTR`) | `VSPBackButton` بلا `content-desc` (`NAF="true"`) وتكرار الفراغ السفلي |
| 3 | [03_welcome_slide3_en.png](screenshots/android/03_welcome_slide3_en.png) | شاشة الترحيب — الشريحة 3 | EN (`LTR`) | رابط `Login` ارتفاعه ~18dp (`[745,2124][850,2171]`) وأزرار الدور بمحيط `24px` بدل `full` |
| 4 | [04_welcome_slide3_ar.png](screenshots/android/04_welcome_slide3_ar.png) | شاشة الترحيب — الشريحة 3 | AR (`RTL`) | تناسق RTL في ترتيب الزرين (`لاعب` يسار / `صاحب ملعب` يمين)، وتقارب أحرف العنوان عند `letterSpacing: -0.5` |
| 5 | [05_create_account_player_ar.png](screenshots/android/05_create_account_player_ar.png) | إنشاء حساب — اللاعب | AR (`RTL`) | **تفكك واضح لحروف `"إ ن ش ا ء   ح س ا ب   ج د ي د"`** (`letterSpacing: 1.2 + w300`) وتقاطع التسطير مع `"شروط_الخدمة"` |
| 6 | [06_terms_modal_player_ar.png](screenshots/android/06_terms_modal_player_ar.png) | نافذة الشروط والخصوصية — اللاعب | AR (`RTL`) | شارات محايدة نظيفة بعد المرحلة 1 ومحتوى موحّد 100% Paymob؛ مزج أرقام هندية في العناوين (`١، ٢`) مع عربية بالمتن (`18, 21`) |
| 7 | [07_signup_player_ar.png](screenshots/android/07_signup_player_ar.png) | تسجيل اللاعب — الجزء العلوي | AR (`RTL`) | ظهور المحافظة بالإنجليزية **`"Cairo"`** داخل نموذج عربي RTL؛ تباين خلفية وحدود حقل الميلاد عن بقية الحقول |
| 8 | [08_signup_player_bottom_ar.png](screenshots/android/08_signup_player_bottom_ar.png) | تسجيل اللاعب — الجزء السفلي | AR (`RTL`) | ظهور المحافظة بالإنجليزية **`"Matrouh"`** بعد GPS؛ زر `"حارس مرمى"` ضيق الحواف؛ تسطير يقطع نقاط الشرط |
| 9 | [09_vsp_date_picker_ar.png](screenshots/android/09_vsp_date_picker_ar.png) | منتقي تاريخ الميلاد (3 خطوات) | AR (`RTL`) | اتجاه سليم (`سنة -> شهر -> يوم`)؛ قطع حاد للعنصر `2001` عند حافة زر التأكيد السفلي |
| 10 | [10_login_ar.png](screenshots/android/10_login_ar.png) | تسجيل الدخول | AR (`RTL`) | زر العين لإظهار كلمة المرور بلا `content-desc` (`NAF="true"`), وتفكيك طفيف لـ `letterSpacing: 1.1` على العنوان الفرعي |
| 11 | [11_forgot_password_dialog_ar.png](screenshots/android/11_forgot_password_dialog_ar.png) | نافذة نسيت كلمة المرور | AR (`RTL`) | تباين شكل زر `"إرسال"` المربع (`radius: 16`) فوق زر `"تسجيل دخول"` الكبسولي في الخلفية |
| 12 | [12_global_error_screen_ar.png](screenshots/android/12_global_error_screen_ar.png) | شاشة الخطأ العام (التُقطت أثناء التنقل السريع) | مختلط AR/EN | جملة إنجليزية كاملة بنقطة مقلوبة **`.been notified`** وزر **`Try Again`** غير مترجم في واجهة عربية |
| 13 | [13_create_account_owner_ar.png](screenshots/android/13_create_account_owner_ar.png) | إنشاء حساب — المالك | AR (`RTL`) | التفاف `"مرحباً بصاحب الملعب"` إلى سطرين ودفع العناصر لأسفل + نفس مشكلة تقطع حروف `"إ ن ش ا ء   ح س ا ب   ج د ي د"` |
| 14 | [14_terms_modal_owner_ar.png](screenshots/android/14_terms_modal_owner_ar.png) | نافذة الشروط والخصوصية — المالك | AR (`RTL`) | وضوح التفريق بين `18` عامًا للمنصة و`21` عامًا للتعاقد التجاري والدفع 100% Paymob؛ همزة وصل زائدة في `"وإلتزامات"` |
| 15 | [15_signup_owner_ar.png](screenshots/android/15_signup_owner_ar.png) | تسجيل المالك | AR (`RTL`) | نفس عرض `"Matrouh"` بالإنجليزية، ووهج أخضر خافت أسفل يسار الشاشة |

---

## 2. الشاشات والأسطح غير المحققة بصريًا بالصورة (`NOT VISUALLY VERIFIED`)

| المجموعة | السبب الموثق | وضع التدقيق البديل المنفذ |
|---|---|---|
| **الموقع العام `vsp_website` (12 مسارًا — `localhost:3000`)** | `CHROME_DEVTOOLS_DISCONNECTED`: المتصفح Chrome لم يكن مفعّلًا على `chrome://inspect/#remote-debugging` (`DevToolsActivePort` غير موجود). | بناء الإنتاج (`next build` 17/17 صفحة) وفحص جميع مكونات الواجهة (`04_WEBSITE_VISUAL_AUDIT.md`) |
| **لوحة الإدارة `vsp-admin-panel` (`localhost:4173`)** | `AUTH_GATED & CHROME_DEVTOOLS_DISCONNECTED`: تتطلب مصادقة Google لمشرف مصرح + اتصال DevTools. | بناء الإنتاج (`vite build`) وفحص صفحات الإدارة ومكوناتها (`05_ADMIN_PANEL_VISUAL_AUDIT.md`) |
| **شاشات اللاعب الداخلية (`PlayerHome`, `StadiumDetails`, `BookingConfirmation`, `Champion`, `TeamDashboard`, `Profile`, إلخ)** | `AUTH_GATED`: تتطلب حسابًا مسجلًا ومفعّل البريد الإلكتروني في Staging دون إنشاء حسابات اختبارية أو المساس ببيانات المستخدمين. | فحص تفصيلي لمكونات الواجهة والأزرار والأرقام والتوكنز (`06_`, `07_`, `08_`) |
| **شاشات المالك الداخلية (`OwnerDashboard`, `OwnerBookings`, `OwnerLedger`, `AddStadiumWizard`, `OwnerDocuments`)** | `AUTH_GATED`: تتطلب حساب مالك موثق في Staging. | فحص تفصيلي لبطاقات المالية والحجز (`07_OWNER_MOBILE_APP_AUDIT.md`) |
| **Flutter Web & iOS Native** | بيئة التشغيل هي Windows مع Android Emulator (`Pixel_9`) — لم يتم اختبار iOS Native (عدم توفر macOS/Xcode هنا)، وتعذر معاينة Flutter Web لعدم اتصال Chrome DevTools. | تم بناء حزمة Flutter Web (`flutter build web --release`) والتحقق من تحذير الخطوط (`CupertinoIcons`) |
