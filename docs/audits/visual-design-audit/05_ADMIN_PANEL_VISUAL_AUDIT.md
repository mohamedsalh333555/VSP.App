# التدقيق البصري للوحة الإدارة — `vsp-admin-panel`

**حالة المعاينة الحية:** `VISUALLY VERIFIED IN LIVE BROWSER (Chrome DevTools على http://localhost:4173 — مُتصل ببيئة Staging)` عبر **16 لقطة شاشة حية** (`01_admin_login_ar_desktop.png` إلى `16_admin_dashboard_en.png`) غطّت الشاشات العربية والإنجليزية والموبايل والصفحات المالية والتشغيلية.  
*(ملاحظة: جميع التعديلات المقترحة أدناه موسومة بـ `PROPOSED DESIGN — NOT IMPLEMENTED`).*

---

## الملاحظات البصرية والحلول المقترحة (`PROPOSED DESIGN — NOT IMPLEMENTED`)

### `VSP-ADM-001` — تسرب بنود عربية صلبة في Sidebar عند التحويل للإنجليزية [CRITICAL]
- **التخصصات:** RTL and Localization Designer (49)، Design QA Engineer (38).
- **الدليل الفعلي الحي (`16_admin_dashboard_en.png` + `AdminSidebar.jsx:75-89`):**
  - في لقطة الإنجليزية الحية `16_admin_dashboard_en.png`، تظهر بنود القائمة اليسرى بالعربية الصريحة وسط واجهة إنجليزية بالكامل: **`المواسم وXP والترتيب`**، **`بطولة أقوى فريق`**، **`جوائز Immortal`**، و**`الدعم الفني`**!
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):** ربط كافة عناصر `AdminSidebar.jsx` بمفاتيح `LanguageContext.jsx`.

### `VSP-ADM-002` — انزلاق/قص الـ Sidebar اليميني خارج عرض `1440px` في عدة صفحات [HIGH]
- **التخصصات:** Layout and Composition Designer (17)، Responsive Design Specialist (45).
- **الدليل الفعلي الحي (`06_admin_disputes_ar.png`, `09_admin_strongest_team_ar.png`, `12_admin_support_tickets_ar.png`):**
  - عند التنقل في مسارات مثل `#disputes` و`#strongest_team` و`#support_tickets` على دقة `1440px`، يظهر الـ Sidebar اليميني مقصوصًا جزئيًا على الحافة اليمنى بحيث لا يظهر منه سوى ~30px تحتوي شارة الرقم `11`، ما يدل على خلل في احتواء `overflow-x` أو عرض الحاوية في RTL!
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):** تثبيت بنية `flex`/`grid` لـ `AdminSidebar` + `main (min-w-0 flex-1)` ومنع دفع الـ Sidebar خارج `viewport` عند اتساع الجداول أو التمرير الأفقي.

### `VSP-ADM-003` — تناقض مؤشرات `0 ج.م` في Dashboard والتسويات رغم وجود حجوزات وأسعار حية [HIGH]
- **التخصصات:** Fintech Interface Designer (43)، Data Visualization Designer (39).
- **الدليل الفعلي الحي (`03_admin_dashboard_ar.png`, `07_admin_payout_settlements_ar.png`, `15_admin_dashboard_mobile.png`):**
  - `03_admin_dashboard_ar.png` تعرض **`إجمالي حجم التداول: 0 ج.م`** في الوقت الذي يعرض الجدول أسفلها مباشرة `113` حجز مباريات وبأسعار `350 ج.م`، `325 ج.م`، `300 ج.م`!
  - `07_admin_payout_settlements_ar.png` تعرض كل بطاقات الـ KPI الخمس بقيمة `0 ج.م` بينما تظهر أزرار `"تمت التسوية"` مع قوائم تسوية فارغة أو صفرية المبالغ المستحقة.
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):** توضيح تسمية المؤشر المالي (هل يجمع حالة `completed/paid` أم يفرق بين الإجمالي والمُسوّى) وعرض تنبيه/مؤشر فرعي يفسّر القيمة الصفرية بدل تركها تبدو معطلة.

### `VSP-ADM-004` — ازدحام `Payout Ledger` بـ 11 عمودًا والتفاف `#ID` بشكل مكسور (`d98c39c6-#`) [HIGH]
- **التخصصات:** Dashboard Designer (14)، Fintech Interface Designer (43)، Typography Designer (19).
- **الدليل الفعلي الحي (`14_admin_payout_ledger_ar.png`):**
  - الجدول يضغط 11 عمودًا بحجم خط `11px`، وينكسر معرّف العملية ليظهر علامة `#` بعد المعرّف عند الالتفاف (`d98c39c6-#`)!
  - ألوان الأخضر والعنبري عالية التشبع مكدسة عموديًا عبر كل الصفوف.
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):** تثبيت `whitespace-nowrap dir="ltr"` على عمود `#ID` واختصار الأعمدة الفرعية داخل Drawer جانبي لتبقى الجدولة بـ 6–7 أعمدة مريحة للعين.

### `VSP-ADM-005` — اختلاط الإنجليزية في الشارات والقوائم وتنسيق التاريخ داخل الوضع العربي [MEDIUM/HIGH]
- **التخصصات:** RTL and Localization Designer (49)، Design QA Engineer (38).
- **الدليل الفعلي الحي (`04_`, `08_`, `09_`, `10_`, `11_`):**
  - `04_admin_owner_audits_ar.png`: حرف الأفاتار الأول يلتقط القوس **`[`** للأسماء التي تبدأ بـ `[DEMO]`، والمدينة تظهر بالإنجليزية `Cairo`.
  - `08_admin_gamification_ar.png`: حقول التواريخ تعرض تنسيقًا إنجليزيًا **`01/31/2027 10:00 PM`** وشارة خضراء نصها `active`.
  - `09_admin_strongest_team_ar.png`: شارات `cancelled` / `ongoing` / `registration_open` / `draft` وأسماء `Aswan` بالإنجليزية.
  - `10_admin_immortal_rewards_ar.png`: قوائم مفلترة بقيم خام `eligible` / `pending` وسلسلة `Aswan • شريف حمدي () • Ch: 60 • XP: 17339` بقوسين فارغين `()` عند غياب اسم الفريق!
  - `11_admin_tournaments_ar.png`: خلط بطاقات تجريبية `'test'` و`[VSP E2E Private Cup]` وسط الواجهة.
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):** إنشاء دالة تطبيع موحدة للحالات (`draft -> مسودة`, `active -> نشط`, `eligible -> مؤهل`)، وتجاهل علامات الترقيم عند استخراج حرف الأفاتار، وإخفاء الأقواس الفارغة `()` عند عدم وجود فريق.

### `VSP-ADM-006` — تباين `text-zinc-500`، انهيار ألوان `Badge.jsx`، وغياب الفصل بين `card/surface` [HIGH]
- **التخصصات:** Accessibility Designer (47)، Color and Contrast Specialist (20)، Design Token Specialist (33).
- **الدليل الفعلي (`LoginPage.jsx:52`, `StatCard.jsx:53`, `Badge.jsx:4-13`, `tailwind.config.js:21-22`):** أحجام `10px/11px` بتباين ~`3.87:1`، واختفاء اللون التحذيري في `Badge.jsx` لصالح الرمادي، وتطابق `bg-vsp-card` و`bg-vsp-surface` عند `#18181B`.

---

## سجل اللقطات الفعلية المُتحقَّق منها في لوحة الإدارة (16 PNG)

| الفئة / الصفحة | اللقطات الملتقطة | الحالة |
|---|---|---|
| الدخول (`AR` & `EN`) | `01_admin_login_ar_desktop.png`, `02_admin_login_en_desktop.png` | `VISUALLY VERIFIED` |
| الرئيسية (`AR` / `Mobile` / `EN`) | `03_admin_dashboard_ar.png`, `15_admin_dashboard_mobile.png`, `16_admin_dashboard_en.png` | `VISUALLY VERIFIED` |
| المراجعة والرقابة | `04_owner_audits`, `05_users`, `06_disputes`, `12_support_tickets`, `13_audit_logs` | `VISUALLY VERIFIED` |
| المالية والتسويات | `07_payout_settlements`, `14_payout_ledger` | `VISUALLY VERIFIED` |
| المواسم والأبطال | `08_gamification`, `09_strongest_team`, `10_immortal_rewards`, `11_tournaments` | `VISUALLY VERIFIED` |
| صفحات لم تُلتقط (`Secondary`) | `BannersManagementPage`, `CRMSettingsPage`, `OwnerSubscriptionsPage`, `League1v1Page` | `NOT VISUALLY VERIFIED IN LIVE BROWSER` (مراجعة كود فقط) |
