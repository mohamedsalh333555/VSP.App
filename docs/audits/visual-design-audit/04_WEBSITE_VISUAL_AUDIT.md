# التدقيق البصري للموقع العام — `vsp_website`

**حالة المعاينة الحية:** `VISUALLY VERIFIED IN LIVE BROWSER (Chrome DevTools على http://localhost:3000)` عبر **13 لقطة شاشة فعلية** (`01_web_home_ar_desktop.png` إلى `13_web_delete_account_ar_desktop.png`)، بالإضافة إلى الفحص المعماري لكل المكونات والصفحات.  
*(ملاحظة: جميع التعديلات المقترحة موسومة بـ `PROPOSED DESIGN — NOT IMPLEMENTED` ولم يُعدَّل أي كود).*

---

## الملاحظات البصرية والحلول المقترحة (`PROPOSED DESIGN — NOT IMPLEMENTED`)

### `VSP-WEB-001` — غياب العنوان الرئيسي والدعوة للإجراء في `HeroSection` + تعطل `/` و`/en` حيًا بصورة `unsplash` [CRITICAL]
- **التخصصات:** Chief Design Officer (1)، Head of Product Design (3)، Design QA Engineer (38)، Web Interface Designer (13).
- **الدليل الفعلي الحي (`01_web_home_ar_desktop.png`..`04_web_home_ar_mobile.png` + `task-5509.log` + `HeroSection.tsx:89-188`):**
  - عند تشغيل الموقع حيًا على Staging، علق `/` (`Desktop/Tablet/Mobile`) و`/en` على شاشة التحميل `"جاري تحميل منصة VSP..."` بسبب استثناء Next.js `Error: Invalid src prop (https://images.unsplash.com/...) on 'next/image', hostname "images.unsplash.com" is not configured under images in your 'next.config.js'`!
  - على مستوى التصميم الكودي، يشغل `HeroSection` كامل الشاشة (`h-[100svh]`) دون عنوان بصري `h1` ظاهر (`sr-only` فقط) أو زر تنزيل/حجز بارز في أول طية.
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):**
  - **قبل:** تعطل SSR/RSC على روابط `images.unsplash.com`، وهيرو بلا `h1` ظاهر.
  - **بعد:** السماح بالنطاقات المعتمدة (أو استخدام صور محلية/Supabase فقط + `onError` fallback) مع `h1` بارز وزر إجراء رئيسي واحد فوق الفيديو.

### `VSP-WEB-002` — تعطل صفحة `/teams` حيًا بسبب صلاحية `teams_public` (`42501`) [CRITICAL]
- **التخصصات:** Design QA Engineer (38)، Information Designer (15).
- **الدليل الفعلي الحي (`06_web_teams_ar_desktop.png` + `task-5509.log:88-100`):**
  - عند فتح `/teams` بصفة زائر `anon`، يرمي الخادم `{ code: '42501', message: 'permission denied for view teams_public' }` فتظل الواجهة عالقة بصريًا على شاشة `"جاري تحميل منصة VSP..."`.
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):** معالجة الصلاحية من جهة قاعدة البيانات (`GRANT SELECT ON public.teams_public TO anon`) وعرض حالة خطأ ودية واضحة مع زر إعادة محاولة بدل البقاء في دوامة التحميل.

### `VSP-WEB-003` — تضارب الدروع مع التطبيق وأسماء إنجليزية أحادية اللون + صفوف جدول `#` فارغة في `/ranking` [HIGH]
- **التخصصات:** Achievement and Badge Designer (41)، Leaderboard Designer (42)، RTL Designer (49)، Sports App Visual Designer (29).
- **الدليل الفعلي الحي (`07_web_ranking_ar_desktop.png` + `TeamRankingShowcaseSection.tsx:16-89`):**
  - في اللقطة الحية لصفحة `/ranking`:
    1. أسماء المحافظات تظهر بالإنجليزية **`Aswan`** داخل جدول عربي بالكامل.
    2. شريط الدروع العلوي يعرض أسماء إنجليزية فقط (`Immortal`, `Legendary`, `Elite`, `Diamond`, `Gold`, `Silver`, `None`) داخل بطاقات متشابهة أحادية اللون الأخضر الخافت بدل هالة الألوان المعتمدة في التطبيق!
    3. الجدول السفلي **`"الفرق الأكثر نشاطاً في الموسم السنوي"`** يطبع رمز **`#` فقط دون رقم الترتيب** في عمود الترتيب لكل الصفوف!
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):**
  - **قبل:** `#` مكرر بلا رقم، `Aswan` بالإنجليزية، وأيقونات دروع متشابهة اللون.
  - **بعد:** طباعة أرقام الترتيب `1, 2, 3...` (`tabular-nums`)، تعريب المحافظة، وتطابق الدروع الستة (`Silver #E2E8F0` -> `Gold #FFC107` -> `Diamond #38BDF8` -> `Elite #A855F7` -> `Legendary #F97316` -> `Immortal #FFE082`).

### `VSP-WEB-004` — عمود `Footer` الأيسر فارغ تمامًا (`0` روابط) + بقاء رابط `"باقات الاشتراك"` المتقاعد [HIGH]
- **التخصصات:** Visual Hierarchy Specialist (18)، Layout Designer (17)، Design QA Engineer (38).
- **الدليل الفعلي الحي (`05_web_about_ar_desktop.png`, `08_web_championships_ar_desktop.png`):**
  - العمود الأخير (الأيسر) في التذييل بعنوان **`"الدعم الفني والتواصل"`** فارغ تمامًا (`0` عناصر تحته بينما الأعمدة المجاورة ممتلئة بالروابط)، ما يترك ثغرة بصرية واضحة أسفل يسار الصفحة.
  - الشريط العلوي (`Navbar`) والتذييل (`Footer`) لا يزالان يعرضان رابط **`"باقات الاشتراك"`** رغم أن `/pricing` يُحوّل تلقائيًا إلى `/`.
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):** ملء عمود `"الدعم الفني والتواصل"` بروابط `"تواصل معنا"`, `"حذف الحساب"`, والبريد الرسمي للدعم؛ وحذف رابط `"باقات الاشتراك"` أو استبداله بـ `"لأصحاب الملاعب"`.

### `VSP-WEB-005` — محاذاة واختلاط حقول الإدخال وزر الإرسال في `/contact` و`/delete-account` [MEDIUM]
- **التخصصات:** Mobile/Web Interface Designer (13)، RTL and Localization Designer (49).
- **الدليل الفعلي الحي (`12_web_contact_ar_desktop.png`, `13_web_delete_account_ar_desktop.png`):**
  - أمثلة الإدخال (`example@email.com` محاذى لليمين مقابل `01xxxxxxxxx` محاذى لليسار) تتذبذب اتجاهيًا، كما أن زر الإرسال الأساسي أسفل النموذج الواسع محاذى إلى أقصى اليسار دون انسجام مع عرض البطاقة أو محاذاة متسقة.
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):** تثبيت `dir="ltr" text-end` (أو `text-start`) لقيم البريد والهاتف داخل RTL مع توحيد عرض زر الإرسال `w-full` أو محاذاته لليمين (`start`).

### `VSP-WEB-006` — تعطل الخط العربي (`font-tajawal`) وكسر تسلسل العناوين وروابط التنزيل المباشر [HIGH]
- **التخصصات:** Arabic Typography Designer (48)، Accessibility Designer (47).
- **الدليل الفعلي (`globals.css:9-11`, `OwnersSection.tsx:53`, `DownloadCTASection.tsx:43`):** الخط يرجع إلى `Segoe UI / Tahoma / Arial`، وتسلسل العناوين يقفز من `h2` إلى `h4`، ورابط Google Drive العام في زر التحميل يفتقد رقم الإصدار والموثوقية.

---

## مصفوفة الشاشات واللقطات الفعلية للموقع العام (13/13)

| المسار | اللقطة الحية الملتقطة | نتيجة الفحص البصري الحي |
|---|---|---|
| `/` & `/en` (Desktop/Tablet/Mobile) | `01_`, `02_`, `03_`, `04_` | **رُصد عالقًا على `loading.tsx`** (`Error: Invalid src prop images.unsplash.com`) |
| `/teams` | `06_web_teams_ar_desktop.png` | **رُصد عالقًا على `loading.tsx`** (`42501 permission denied for view teams_public`) |
| `/about` | `05_web_about_ar_desktop.png` | مُتحقق حيًا: تخطيط واضح؛ **عمود Footer أيسر فارغ** + رابط `"باقات الاشتراك"` |
| `/ranking` | `07_web_ranking_ar_desktop.png` | مُتحقق حيًا: **`Aswan` إنجليزي** + **جدول `#` بلا أرقام** + أسماء دروع إنجليزية |
| `/championships` | `08_web_championships_ar_desktop.png` | مُتحقق حيًا: بطاقات جيدة، نفس فجوة الـ Footer ورابط `"باقات الاشتراك"` |
| `/privacy`, `/terms`, `/refund` | `09_`, `10_`, `11_` | مُتحقق حيًا: متسقة المحتوى وتدعم Paymob 100%؛ تعاني غياب خط `Tajawal` الحقيقي |
| `/contact`, `/delete-account` | `12_`, `13_` | مُتحقق حيًا: تناقض محاذاة placeholders وزر الإرسال اليساري |
