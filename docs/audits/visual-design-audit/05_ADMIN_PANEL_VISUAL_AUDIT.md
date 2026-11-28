# التدقيق البصري للوحة الإدارة — `vsp-admin-panel`

**حالة المعاينة الحية:** `NOT VISUALLY VERIFIED IN LIVE BROWSER (CHROME_DEVTOOLS_DISCONNECTED)` + جميع المسارات الداخلية محمية بتسجيل دخول Google المصرّح للمشرفين (`LoginPage.jsx`). تم بناء اللوحة محليًا (`vite build` بنجاح) وتشغيلها على `http://localhost:4173`، وتم فحص صفحاتها ومكوناتها فعليًا من الكود (`LoginPage.jsx`, `AdminSidebar.jsx`, `StatCard.jsx`, `DashboardOverview.jsx`, `OwnerAuditsPage.jsx`, `PayoutSettlementsPage.jsx`, `GamificationSeasonsPage.jsx`, `index.css`, `tailwind.config.js`).

---

## الملاحظات البصرية والحلول المقترحة (`PROPOSED DESIGN — NOT IMPLEMENTED`)

### `VSP-ADM-001` — نصوص عربية صلبة داخل القائمة الجانبية عند التحويل للإنجليزية [HIGH]
- **التخصصات:** RTL and Localization Designer (49)، Design QA Engineer (38).
- **الدليل الفعلي (`AdminSidebar.jsx:75-89`):**
  - الأسطر `77, 82, 87` تكتب `'المواسم وXP والترتيب'` و`'بطولة أقوى فريق'` و`'جوائز Immortal'` كنصوص عربية ثابتة بدل استدعاء `t(...)`، فتظهر بالعربية حتى عند اختيار الإنجليزية!
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):**
  - **قبل:** نصوص عربية مختلطة مع روابط إنجليزية في Sidebar عند تفعيل EN.
  - **بعد:** ربط جميع بنود القائمة بمفاتيح ترجمة في `LanguageContext.jsx`.

### `VSP-ADM-002` — محاذاة يمينية ثابتة (`text-right`) في جداول بيانات `GamificationSeasonsPage` [MEDIUM]
- **التخصصات:** RTL and Localization Designer (49)، Dashboard Designer (14).
- **الدليل الفعلي (`GamificationSeasonsPage.jsx:332, 381`):** `<table className="w-full text-xs text-right">` تفرض المحاذاة لليمين حتى في الواجهة الإنجليزية LTR.
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):** استبدال `text-right` بـ `text-start` وتوحيد محاذاة أعمدة الأرقام بـ `tabular-nums`.

### `VSP-ADM-003` — خط `10px` وتباين ضعيف (`text-zinc-500` على `#18181B`) وموقع زر اللغة في `LoginPage` [HIGH]
- **التخصصات:** Accessibility Designer (47)، Color and Contrast Specialist (20)، RTL Designer (49).
- **الدليل الفعلي:**
  - `LoginPage.jsx:52`: يستخدم `text-[10px] text-zinc-500` و`StatCard.jsx:53` يستخدم `text-[11px] text-zinc-500` فوق `#18181B` بنسبة تباين ~`3.87:1` (دون حد WCAG AA البالغ `4.5:1`).
  - `LoginPage.jsx:25`: زر اللغة مثبت بـ `right-6` بدل `end-6`.
  - `LoginPage.jsx:24`: يطبق `select-none` على الشاشة كلها مما يمنع نسخ رسالة الخطأ عند دعم المشرف!
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):**
  - ترقية النصوص الثانوية إلى `text-xs (12px)` بدرجة `text-zinc-400` (`#A1A1AA`, تباين ~`7.1:1`)، استخدام `end-6` للزر العائم، وحذف `select-none` عن نصوص التنبيهات.

### `VSP-ADM-004` — غياب `tabular-nums` في بطاقات KPI (`StatCard`) وانعدام الفصل اللوني للـ `bg-vsp-card` [MEDIUM]
- **التخصصات:** Data Visualization Designer (39)، Fintech Interface Designer (43)، Visual Hierarchy Specialist (18).
- **الدليل الفعلي (`StatCard.jsx:24, 31`):** الأرقام المالية/الإجمالية الكبيرة (`text-2xl lg:text-3xl`) تفتقد `tabular-nums`، ومربع الأيقونة `bg-vsp-card` له نفس خلفية البطاقة الأم `bg-vsp-surface` (`#18181B`)، وتدرج الـ glow في `index.css` لا يزال `#CCFF00` بدل `#9FDF02`.
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):** إضافة `tabular-nums` على أرقام `StatCard` وجميع خلايا المبالغ المالية، وفصل `surfaceRaised (#222227)` لصندوق الأيقونة، وتوحيد الـ glow على `#9FDF02`.

### `VSP-ADM-005` — انهيار تنوع شارات الحالة (`Badge.jsx` يطابق `warning/blue/purple` مع اللون الرمادي!) [HIGH]
- **التخصصات:** Information Designer (15)، Color and Contrast Specialist (20)، Design QA Engineer (38).
- **الدليل الفعلي (`vsp_admin_panel/src/components/ui/Badge.jsx:4-13`):**
  - المتغيرات `accent`, `primary`, `warning`, `blue`, `purple` كلها ترسم `bg-zinc-800 text-zinc-300 border-zinc-700` بالرمادي! ما يجعل شارة `"action_required"` (`variant="warning"` في `OwnerAuditsPage.jsx:376`) أو أوسمة التصنيف تبدو غير عاجلة ومتطابقة مع `default`. كما أن `size="xs"` يستخدم `text-[10px]`.
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):**
  - **قبل:** `warning` رمادي محايد و`xs = 10px`.
  - **بعد:** إعادة ربط `warning` باللون العنبري (`bg-amber-500/15 text-amber-300 border-amber-500/30`)، و`info/blue` بالأزرق (`#3B82F6`)، و`xs` إلى `11px`/`12px` على الأقل.

---

## سجل الشاشات المحجوبة خلف تسجيل الدخول

| الصفحة | الحالة | السبب |
|---|---|---|
| `LoginPage.jsx` | فحص كود + حزمة مبنية (`vite build`) | `NOT VISUALLY VERIFIED IN LIVE BROWSER (CHROME_DEVTOOLS_DISCONNECTED)` |
| `DashboardOverview`, `OwnerAuditsPage`, `UsersModerationPage`, `DisputesPage`, `PayoutSettlementsPage`, `GamificationSeasonsPage`, `StrongestTeamAdminPage`, `ImmortalRewardsAdminPage`, `TournamentControlPage`, `BannersManagementPage`, `SupportTicketsPage`, `AuditLogsPage`, `CRMSettingsPage`, `OwnerSubscriptionsPage`, `League1v1Page` | فحص كود ومكونات معزول | `NOT VISUALLY VERIFIED (AUTH_GATED & CHROME_DEVTOOLS_DISCONNECTED)` — تتطلب تسجيل دخول Google مصرحًا للمشرف + اتصال DevTools |
