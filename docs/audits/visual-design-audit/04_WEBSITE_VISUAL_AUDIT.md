# التدقيق البصري للموقع العام — `vsp_website`

**حالة المعاينة الحية:** `NOT VISUALLY VERIFIED IN LIVE BROWSER (CHROME_DEVTOOLS_DISCONNECTED)` — الخادم المحلي `http://localhost:3000` تم بناؤه (`next build`: 17/17 صفحة) وتشغيله بنجاح، لكن تعذّر التقاط صور حية لعدم تفعيل `chrome://inspect/#remote-debugging` (`DevToolsActivePort` غير موجود). تم فحص كافة المكونات والأنماط فعليًا عبر التدقيق البصري للكود (`HeroSection.tsx`, `Navbar.tsx`, `Footer.tsx`, `LiveStadiumsSection.tsx`, `ChampionshipSection.tsx`, `TeamRankingShowcaseSection.tsx`, `OwnersSection.tsx`, `ReviewsSection.tsx`, `DownloadCTASection.tsx`, `PricingClient.tsx`, `globals.css`).

---

## الملاحظات البصرية والحلول المقترحة (`PROPOSED DESIGN — NOT IMPLEMENTED`)

### `VSP-WEB-001` — غياب العنوان الرئيسي والدعوة للإجراء (First Fold CTA) في HeroSection [CRITICAL]
- **التخصصات:** Chief Design Officer (1)، Head of Product Design (3)، Brand Strategist (25)، Visual Hierarchy Specialist (18)، Web Interface Designer (13).
- **الدليل الفعلي (`HeroSection.tsx:89-188`):**
  - قسم `HeroSection` يشغل كامل الشاشة (`h-[100svh]`) بفيديو فقط دون عرض أي عنوان بصري (`h1` مخفي بـ `sr-only` للوصول فقط!) ولا جملة تعريفية ولا زر تنزيل/حجز بارز، باستثناء رابط التمرير الصغير `"استكشف الملاعب"` أسفل الشاشة.
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):**
  - **قبل (Before):** فيديو صامت بملء الشاشة + تدرج سفلي أسود + كبسولة "استكشف الملاعب" + أزرار كتم/إيقاف.
  - **بعد (After):** وضع طبقة قراءة تدرجية خفيفة (`from-black/75 via-black/30 to-[#09090B]`) + عنوان رئيسي مقروء (`display-xl`: احجز ملعبك وأدِر فريقك في ثوانٍ) + زر أساسي واحد (`احجز الآن / حمّل التطبيق`) بجانب كبسولة الاستكشاف، مع احترام مسافة `Navbar` العلوية على شاشات الموبايل `375px`.

### `VSP-WEB-002` — تضارب ألوان وأسماء دروع الفرق بين الموقع والتطبيق [CRITICAL]
- **التخصصات:** Brand Identity Designer (26)، Achievement and Badge Designer (41)، Sports App Visual Designer (29)، Design Consistency Specialist (37).
- **الدليل الفعلي (`TeamRankingShowcaseSection.tsx:16-89` مقابل `vsp_design_tokens.dart:40-46`):**
  - الموقع يعرض: `Gold (01)` -> `Platinum (02)` -> `Diamond (03)` -> `Elite (04)` -> `Legendary (05)` -> `Immortal (06)` بلون **أخضر زمردي (`emerald-400` / `#10B981`)**!
  - بينما التطبيق يعرّف في `VSPDSColors`: `Silver (#E2E8F0)` -> `Gold (#FFC107)` -> `Diamond (#38BDF8)` -> `Elite (#A855F7)` -> `Legendary (#F97316)` -> **`Immortal (#FFE082)` ذهبي مضيء ("zero green")**!
  - كما أن شارة القسم العليا في `TeamRankingShowcaseSection.tsx:100` تستخدم `bg-emerald-500/10 text-emerald-400` بدل نظام VSP المعتمد.
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):**
  - **قبل:** تسمية "البلاتيني" بدل "الفضي"، ودرع "الخالد Immortal" أخضر زمردي يشتت عن ذهبية Immortal في التطبيق.
  - **بعد:** توحيد السلسلة تمامًا (`Silver #E2E8F0` -> `Gold #FFC107` -> `Diamond #38BDF8` -> `Elite #A855F7` -> `Legendary #F97316` -> `Immortal #FFE082` بهالة ذهبية ملكية) وإعادة تلوين شارة القسم بلون محايد أو ذهبي خافت.

### `VSP-WEB-003` — تكدس شريط التنقل (Navbar) عند عرض `lg` (1024px) ونقص `aria-label` [MEDIUM]
- **التخصصات:** Web Interface Designer (13)، Responsive Design Specialist (45)، Accessibility Designer (47).
- **الدليل الفعلي (`Navbar.tsx:36-100`):** يحتوي على 7 روابط + شعار + زر لغة + زر تحميل في نطاق `lg:flex` (`1024px`). كما أن زر تبديل اللغة (`EN` / `ع`) يفتقد `aria-label` الصريح ويعتمد على `title`.
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):** رفع نقطة الظهور الكامل للشريط الوسطي من `lg` إلى `xl` (أو تقليص عدد الروابط العلوية لـ 5 روابط أساسية وإدراج البقية في قائمة "المزيد")، وإضافة `aria-label` واضح لزر اللغة والشعار.

### `VSP-WEB-004` — تعطل الخط العربي (`font-tajawal`) وكسر تسلسل العناوين (`h2 -> h4`) [HIGH]
- **التخصصات:** Arabic Typography Designer (48)، Accessibility Designer (47).
- **الدليل الفعلي:**
  - `globals.css:9-11` يستبدل `--font-tajawal` و`--font-cairo` بخطوط النظام العادية (`Segoe UI, Tahoma, Arial`).
  - `OwnersSection.tsx:53` و`Footer.tsx:52, 96` تقفز من `<h2>` إلى `<h4>` مباشرة وتطبق `uppercase tracking-wider` على عناوين عربية.
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):** تضمين ملفات `Tajawal` و`Poppins` محليًا، وتعديل مستويات العناوين إلى `h2 -> h3` بالتسلسل الصحيح، وإلغاء `uppercase tracking-wider` في الوضع العربي.

### `VSP-WEB-005` — رابط التحميل في `DownloadCTASection` واختفاء قسم التقييمات الصامت [MEDIUM]
- **التخصصات:** Brand Experience Designer (27)، Product Designer (7).
- **الدليل الفعلي (`DownloadCTASection.tsx:43` و`ReviewsSection.tsx:15-16`):** زر التحميل يوجه مباشرة إلى رابط مجلد Google Drive عام دون مؤشر أمان أو رقم إصدار، وقسم المراجعات يرجع `null` صامتًا إذا قل عدد المراجعات عن 3 دون fallback واضح.
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):** عرض بطاقة إصدار VSP (النسخة، حجم الملف، التوافق مع أندرويد 8+ / قادمون لـ iOS) بجانب زر التنزيل لزيادة الثقة التجارية.

---

## ملخص حالة فحص شاشات الموقع العام

| المسار | دقة الفحص المتاحة | الحالة البصرية |
|---|---|---|
| `/`, `/about`, `/pricing`, `/championships`, `/ranking`, `/teams`, `/privacy`, `/terms`, `/refund`, `/delivery`, `/delete-account`, `/contact` | فحص كود + أنماط + `next build` (17/17 صفحة) | `NOT VISUALLY VERIFIED IN LIVE BROWSER (CHROME_DEVTOOLS_DISCONNECTED)` — جاهزة للمعاينة فور تفعيل Chrome remote debugging |
