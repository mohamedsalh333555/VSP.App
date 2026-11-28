# التدقيق البصري لأنظمة التحفيز والمالية والخطوط العربية — Gamification & Fintech UI Audit

*(ملاحظة: جميع الحلول المقترحة موسومة بـ `PROPOSED DESIGN — NOT IMPLEMENTED`).*

---

## أولاً: تصميم الدروع والمنصات ولوحة الصدارة (Gamification, Badges & Leaderboard)

### `VSP-GAM-001` — ارتفاع ثابت في عناصر منصة التتويج (`ChampionPodiumItem`) يهدد بالقص (Overflow) [HIGH]
- **التخصصات:** Leaderboard Designer (42)، Responsive Design Specialist (45)، Design QA Engineer (38).
- **الدليل الفعلي (`champion_podium_components.dart:79, 86-87`):**
  - `height = isCenter ? 260.0 : 210.0;` داخل `Container(height: height)` مع أسماء فرق عربية متعددة الكلمات وشعارات. إذا كبّر المستخدم حجم خط النظام أو طال اسم الفريق، يصبح الـ Column معرضًا للـ Overflow.
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):**
  - **قبل:** `Container(height: 210.0)` / `260.0` صارم.
  - **بعد:** `ConstrainedBox(constraints: BoxConstraints(minHeight: isCenter ? 248 : 200))` مع `maxLines: 2, overflow: TextOverflow.ellipsis` لاسم الفريق وتثبيت ارتفاع منطقة الشعار.

### `VSP-GAM-002` — طغيان الإطار والظل الأخضر على بطاقة الفريق البطل (`TeamCardHero`) بدل لون الدرع [HIGH]
- **التخصصات:** Achievement and Badge Designer (41)، Gamification Designer (40)، Sports App Visual Designer (29).
- **الدليل الفعلي (`team_card_hero.dart:45-55`):** بطاقة الفريق القابلة للمشاركة (`TeamCardHero`) تفرض ظلًا وحدًا أخضر (`VSPColors.accent.withValues(alpha: 0.3)` / `0.2`) على كل الفرق أيًا كان درعها (`Silver / Gold / Diamond / Elite / Legendary / Immortal`)!
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):**
  - **قبل:** كل بطاقات الفرق متشابهة بإطار أخضر موحّد.
  - **بعد:** ربط لون الحد الخفيف والهالة الخلفية بدرجة `shieldTier.primaryColor` (وباللون المحايد لـ `tierNone`) ليصبح الارتقاء بالدرع مكافأة بصرية ملموسة عند المشاركة!

---

## ثانياً: واجهات الدفع والمالية (Fintech Interface & Checkout Clarity)

### `VSP-FIN-001` — نقص وسائل الدفع المذكورة في ملخص الدفع (`BookingFinancialSummary`) [MEDIUM]
- **التخصصات:** Fintech Interface Designer (43)، Marketplace Interface Designer (44)، Information Designer (15).
- **الدليل الفعلي (`booking_financial_summary.dart:34-41`):**
  - يعرض النص العربي: `"(بالفيزا أو المحفظة)"` ويغفل ذكر **ميزة (Meeza)** و**ماستركارد (MasterCard)** و**إنستاباي (InstaPay)**، كما يستخدم `Colors.white` مباشرة بدل `VSPColors.textPrimary`.
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):**
  - **قبل:** شريط بنص عام `(بالفيزا أو المحفظة)` دون تفصيل الشفافية.
  - **بعد:** شريط مضغوط يعرض شارات/أيقونات وسائل الدفع المعتمدة (`Visa / MasterCard / Meeza / محافظ / InstaPay`) مع تفكيك واضح قبل الدفع: `سعر الملعب + 5% منصة VSP + رسوم Paymob`.

### `VSP-FIN-002` — شريط التبويبات الثلاثي في شاشة الأبطال (`ChampionScreen`) وتعدد أنماط الحدود [LOW]
- **التخصصات:** Component Design Specialist (34)، Micro-interaction Designer (24).
- **الدليل الفعلي (`champion_screen.dart:86-168`):** الشريط ينجح في مراعاة `Directionality.of(context) == TextDirection.rtl` (نقطة إيجابية!)، لكنه يكسر التزامه بالخط (`fontSize: 13` على `bodyLarge` بدل `labelLarge`) مع سماكة حد `0.5` غير موجودة في `VSPDSBorders` (`hairline = 1.0`).
