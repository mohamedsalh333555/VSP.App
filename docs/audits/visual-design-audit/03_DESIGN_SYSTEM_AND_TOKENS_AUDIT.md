# تدقيق نظام التصميم والمتغيرات البصرية (Design System & Tokens Audit)

**المرجع الأساسي:** `lib/core/ui/tokens/vsp_design_tokens.dart`، `lib/core/ui/tokens/vsp_tokens.dart`، `vsp_website/src/styles/generated_tokens.ts` + `globals.css`، `vsp_admin_panel/tailwind.config.js` + `src/index.css`.  
*(ملاحظة: جميع التعديلات المقترحة أدناه موسومة بـ `PROPOSED DESIGN — NOT IMPLEMENTED` ولن تُنفذ في المرحلة الثالثة).*

---

## 1. الاكتشافات الحرجة وعالية الأولوية عبر منظومة التوكنز

### `VSP-VD-001` — تصادم لون النجاح والمعلومات (`success == info == #3B82F6`) عبر المنصات الثلاث [HIGH]
- **التخصصات المكتشفة:** Design System Architect (31)، Design Token Specialist (33)، Color and Contrast Specialist (20)، Fintech Interface Designer (43)، Design QA Engineer (38).
- **الدليل الفعلي:**
  - `lib/core/ui/tokens/vsp_design_tokens.dart:91-92`: `info = VSPDSColors.blue500;` و`success = VSPDSColors.blue500;` (`#3B82F6`).
  - `vsp_website/src/styles/generated_tokens.ts:16-17`: `"info": "#3B82F6", "success": "#3B82F6"`.
  - `vsp_admin_panel/tailwind.config.js:31-32`: يقرأ نفس القيمة المتصادمة (`tokens.colors.success` & `tokens.colors.info`).
  - **الأثر البصري:** علامة التحقق الإيجابية في حقول الإدخال (`custom_text_field.dart:81` -> `VSPColors.success`) وشاشات الدفع/الحالة تظهر باللون الأزرق نفسه المستخدم للتنبيهات المعلوماتية!
- **الحل المقترح (`PROPOSED DESIGN — NOT IMPLEMENTED`):**
  - **قبل:** `success: #3B82F6` و`info: #3B82F6`.
  - **بعد:** تخصيص `success: #22C55E` (أو `#10B981` الأخضر الزمردي الدلالي للحالات الإيجابية والمدفوعات الناجحة) مع إبقاء `voltGreen: #9FDF02` كلون علامة تجارية/CTA فقط (`Brand Accent`)، والإبقاء على `info: #3B82F6` للإرشادات المعلوماتية.

### `VSP-VD-002` — انحراف لون الـ Accent في لوحة الإدارة (`#CCFF00` vs `#9FDF02`) [HIGH]
- **التخصصات المكتشفة:** Brand Identity Designer (26)، Design Consistency Specialist (37)، Design Technologist (36).
- **الدليل الفعلي:**
  - `VSP.App` و`vsp_website` و`vsp_admin_panel/tailwind.config.js` تستخدم `#9FDF02` (`rgba(159, 223, 2, ...)`).
  - بينما `vsp_admin_panel/src/index.css:48, 53, 57` تستخدم `#CCFF00` (`rgba(204, 255, 0, ...)`) في `.glass-panel-interactive:hover`, `.glow-accent`, `.glow-accent-sm`.
- **الحل المقترح (`PROPOSED DESIGN — NOT IMPLEMENTED`):**
  - استبدال `204, 255, 0` في `vsp_admin_panel/src/index.css` بالقيم المتولدة `159, 223, 2` المرتبطة مباشرة بـ `var(--vsp-accent)`.

### `VSP-VD-003` — تضارب اسمي في `bg-vsp-card` مقابل `bg-vsp-surface` في Admin Panel [MEDIUM]
- **التخصصات المكتشفة:** Visual Hierarchy Specialist (18)، Dashboard Designer (14)، Design Token Specialist (33).
- **الدليل الفعلي:**
  - `vsp_admin_panel/tailwind.config.js:21-22`: كلاهما يشير لنفس الدرجة `surface: tokens.colors.surface` (`#18181B`), مثلما يظهر في `StatCard.jsx:15, 24` و`LoginPage.jsx:31, 33` (`bg-vsp-card` داخل `bg-vsp-surface` بدون أي فارق لوني!).
- **الحل المقترح (`PROPOSED DESIGN — NOT IMPLEMENTED`):**
  - **قبل:** `surface: #18181B`, `card: #18181B`.
  - **بعد:** `surface: #141417` (أو `#121215`) للكروت الرئيسية، و`card/surfaceRaised: #1F1F24` للعناصر المتداخلة (`Icon box` / `nested chips`) لخلق تدرج عمق فوري ومقروء في الوضع الداكن.

### `VSP-VD-004` — تعدد درجات الداكن المبعثرة في الموقع العام (7 درجات سطح متنافسة) [HIGH]
- **التخصصات المكتشفة:** Dark Mode Designer (46)، Principal Visual Designer (10)، Design System Designer (32).
- **الدليل الفعلي:** في صفحة `HomePage` وحدها بالموقع: `#09090B`، `#0E100F` (`DownloadCTASection.tsx:20`)، `#111312` (`LiveStadiumsSection.tsx:99`, `ChampionshipSection.tsx:56`)، `#121413` (`Navbar.tsx:73`)، `#141615` (`LiveStadiumsSection.tsx:89`)، `#161817` (`ChampionshipSection.tsx:63, 87`)، `#18181B` (`OwnersSection.tsx:47`).
- **الحل المقترح (`PROPOSED DESIGN — NOT IMPLEMENTED`):**
  - تقليص الأسطح إلى 3 مستويات قياسية من `generated_tokens.ts`: `bg (#09090B)` -> `surface (#141417)` -> `surfaceRaised (#222226)` وإلغاء الدرجات المائلة للأخضر الخفي (`#111312`, `#161817`) لتبدو الواجهة أنقى وأفخم.

### `VSP-VD-005` — تضارب الخطوط العربية وتشويه `letterSpacing` على النص العربي [HIGH]
- **التخصصات المكتشفة:** Arabic Typography Designer (48)، Typography Designer (19)، Accessibility Designer (47).
- **الدليل الفعلي:**
  1. `vsp_design_tokens.dart:285-311`: `displayLarge` و`displayMedium` يفرضان `letterSpacing: 0.5` و`height: 1.20` مع fallback لـ `'Tajawal'`. كما أن `signup_screen.dart:263` يضع `letterSpacing: 1.1` على عنوان عربي (`المعلومات الشخصية`)!
  2. `vsp_design_tokens.dart:429-462`: أحجام `10.0px` (`labelSmall`) و`11.0px` (`navigationSelected`, `status`) بارتفاع سطر `1.10` تضيّق الحروف العربية المزودة بنقاط سفلية (`ي، ق، ج`).
  3. `vsp_website/src/app/globals.css:9-11`: متغيرات `--font-cairo` و`--font-tajawal` معطّلة فعليًا إلى `'Segoe UI', 'Tahoma', 'Arial'` بينما الكلاسات في الصفحات ما زالت تكتب `font-tajawal`، وفي `vsp_admin_panel/index.html` يُحمّل `Inter` بدل `Poppins`!
- **الحل المقترح (`PROPOSED DESIGN — NOT IMPLEMENTED`):**
  - إلغاء `letterSpacing > 0` تمامًا عند اللغة العربية (`locale == 'ar' -> letterSpacing: 0`)، ورفع أقل ارتفاع سطر للعربي إلى `1.35` للعناوين و`1.45` للنصوص، ورفع أقل حجم خط إلى `12.0px` (`caption/nav`) بدل `10–11px`، وتوحيد استضافة خطوط `Tajawal` + `Poppins` محليًا (`next/font` أو `/public/fonts`).

### `VSP-VD-006` — تعارض دلالة `VSPSpacing.xl` (`20px`) مقابل `VSPDSSpacing.xl` (`32px`) [MEDIUM]
- **التخصصات المكتشفة:** Layout and Composition Designer (17)، Design System Architect (31).
- **الدليل الفعلي:** `vsp_tokens.dart:100` يحوّل `VSPSpacing.xl` إلى `VSPDSSpacing.inputHorizontal` (`20.0px`) بدل `VSPDSSpacing.xl` (`32.0px`)! مما يجعل شاشات مثل `BookingBottomBar` و`TeamCardHero` تظن أنها تستخدم مسافة `xl` فتأخذ `20px` فقط.
- **الحل المقترح (`PROPOSED DESIGN — NOT IMPLEMENTED`):** فصل `VSPSpacing.xl = 32.0` بوضوح واستخدام `VSPDSSpacing.inputHorizontal` لحقول الإدخال فقط بعد مراجعة الهوامش.
