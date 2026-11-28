# مقترحات التحسين البصرية الدقيقة (Before / After Visual Specifications)

> **تحذير التزامي:** كافة المقترحات هنا هي توصيفات بصرية دقيقة جاهزة للتنفيذ في مرحلة لاحقة (`PROPOSED DESIGN — NOT IMPLEMENTED`)، ولم يتم تعديل أي ملف برمجي خلالها في المرحلة الثالثة.

---

## 1. لوحة الألوان والدلالات البصرية الموحدة (Color & Token Unification)

| العنصر | الوضع الحالي (`Before`) | الوضع المقترح (`After — PROPOSED`) | المبرر التصميمي |
|---|---|---|---|
| **حالة النجاح مقابل المعلومات** | `success: #3B82F6` و`info: #3B82F6` (`vsp_design_tokens.dart:91-92` & `generated_tokens.ts:16-17`) | `success: #22C55E` (زمردي نقي لحقول الإدخال والنجاح) / `info: #3B82F6` (أزرق) / `accent: #9FDF02` (CTA فقط) | إزالة الالتباس البصري في التحقق من الهواتف/الإيميلات وحالات السداد |
| **وهج لوحة الإدارة (`index.css`)** | `rgba(204, 255, 0, ...)` (`#CCFF00`) | `rgba(159, 223, 2, ...)` (`#9FDF02`) | توحيد الهوية البصرية للعلامة عبر المنصات الثلاث 100% |
| **أسطح الوضع الداكن بالموقع** | 7 درجات مختلطة (`#0E100F`, `#111312`, `#121413`, `#141615`, `#161817`, `#18181B`, `#09090B`) | 3 مستويات فقط: `Canvas #09090B` -> `Surface #141417` -> `Raised #1F1F24` | تقليل الضجيج البصري وإبراز الصور والبطاقات |
| **درع الخالد (Immortal) بالموقع** | أخضر زمردي `emerald-400` + اسم `Platinum` للرتبة الثانية (`TeamRankingShowcaseSection.tsx`) | ذهبي ملكي `#FFE082` + رتبة ثانية `Silver #E2E8F0` تطابق التطبيق | توحيد اقتصاد التحفيز البصري بين التطبيق والموقع ("zero green on shields") |
| **شارات Admin Panel (`Badge.jsx`)** | `warning` و`blue` و`purple` كلها رمادي `bg-zinc-800` | `warning -> amber`, `info -> blue`, `success -> emerald/accent`, `danger -> red` | استرجاع دلالة الأولوية العاجلة للمشرف (`action_required`) |

---

## 2. الخطوط العربية والتسلسل البصري وإمكانية الوصول

| العنصر | الوضع الحالي (`Before`) | الوضع المقترح (`After — PROPOSED`) |
|---|---|---|
| **التباعد بين الحروف العربية (`letterSpacing`)** | `letterSpacing: 0.5` في `displayLarge/Medium` و`letterSpacing: 1.1` في `signup_screen.dart:263` | شرط لغوي: `letterSpacing: isArabic ? 0.0 : 0.5`، مع `height >= 1.35` للعناوين |
| **أحجام الخطوط الصغيرة والتباين** | `10px` (`labelSmall`, `LoginPage:52`) و`11px text-zinc-500` (`StatCard:53`, تباين `3.87:1`) | حد أدنى `12px` للنصوص المقروءة ورفع لون النص الثانوي إلى `#A1A1AA` (تباين `> 7:1`) |
| **خط الموقع (`globals.css`)** | يستدعي `Segoe UI / Tahoma` رغم تسمية `--font-tajawal` | استضافة خطوط `Tajawal` + `Poppins` محليًا عبر `next/font/google` أو `/public/fonts` |
| **أول شاشة في الموقع (`HeroSection`)** | شاشة فيديو صامتة بدون عنوان ظاهر (`h1 sr-only`) | إضافة عنوان ظاهر + قيمة واضحة + زر CTA رئيسي فوق تدرج حماية قراءة |
| **أهداف اللمس في التطبيق (`Tap Targets`)** | زر `"كشف الحساب"` (`~16px`)، زر GPS بالتسجيل (`18px`)، زر `"تخطي"` بـ `Size.zero` | غلاف `48x44px` بـ `InkWell/TextButton` يطابق `VSPDSizes.touchTarget = 48.0` |
| **الأرقام المالية (`Fintech UI`)** | `collectedTotal.toStringAsFixed(0)` وKPI بدون `tabularFigures` وبدون فواصل آلاف | استخدام `VSPDSTypography.priceHero` + تنسيق `#,##0` + `tabular-nums` في الويب ولوحة الإدارة |
| **النصوص المترجمة (`Localization`)** | `AdminSidebar:77,82,87` و`SelectRoleScreen:49-80` عربي فقط + `GamificationSeasonsPage` بـ `text-right` ثابت | ربط كامل بملفات الترجمة و`text-start` المنطقي في RTL/LTR |
