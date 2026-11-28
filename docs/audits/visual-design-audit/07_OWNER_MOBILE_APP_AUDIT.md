# التدقيق البصري لتطبيق صاحب الملعب — Owner App UI Audit

**حالة المعاينة الحية:** شاشات المالك الداخلية تتطلب حساب مالك مُصادقًا في Staging — سيتم توثيق الشاشات المحجوبة بـ `NOT VISUALLY VERIFIED (AUTH_GATED)`، بينما تخضع جميع شاشات المالك المفحوصة في الكود (`owner_dashboard_screen.dart`, `owner_dashboard_header.dart`, `owner_operational_finance_card.dart`, `owner_delete_account_card.dart`, `owner_bookings_screen.dart`, `owner_ledger_screen.dart`, `stadium_card.dart`, `vsp_terms_and_privacy_modal.dart`) للتحليل المعماري والبصري الدقيق أدناه.

*(ملاحظة: جميع الحلول المقترحة موسومة بـ `PROPOSED DESIGN — NOT IMPLEMENTED`).*

---

## الاكتشافات البصرية والحلول المقترحة

### `VSP-OWN-001` — هدف لمس صغير جدًا (`~16px`) في زر "كشف الحساب" وتضارب الأيقونات [CRITICAL]
- **التخصصات:** Accessibility Designer (47)، Mobile Interface Designer (12)، Iconography Designer (21).
- **الدليل الفعلي (`owner_operational_finance_card.dart:73-98`):**
  - زر `"كشف الحساب"` مبني بـ `GestureDetector` مباشر حول `Row(Text(12px), Icon(14px))` دون `Padding` أو `ConstrainedBox(minHeight: 48)` — مساحة اللمس الفعلية لا تتجاوز ~16–20px مقارنةً بمعيار `VSPDSizes.touchTarget = 48.0`.
  - يستخدم `Icons.arrow_back` / `Icons.arrow_forward` من Material بدل عائلة `Iconsax` المعتمدة في باقي البطاقة (`Iconsax.card_copy`, `Iconsax.wallet_3_copy`), ويفتقد `Semantics(button: true)`.
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):**
  - **قبل:** `GestureDetector` عارٍ بأيقونة Material `14px`، صعب الضغط بالإبهام.
  - **بعد:** غلاف `InkWell` أو `TextButton.icon` بحد أدنى للمس `48x44px`، مع `Iconsax.arrow_left_2_copy` / `Iconsax.arrow_right_3_copy` حسب RTL، وشارة خلفية خفيفة `VSPColors.surfaceAlt`.

### `VSP-OWN-002` — غياب `tabularFigures` وفواصل الآلاف في الأرقام المالية الكبيرة + تكرار القيمة اليومية [HIGH]
- **التخصصات:** Fintech Interface Designer (43)، Data Visualization Designer (39)، Information Designer (15).
- **الدليل الفعلي (`owner_operational_finance_card.dart:106-135, 175-182`):**
  - الرقم البارز (`collectedTotal.toStringAsFixed(0)`) يستخدم `TextStyle(fontSize: 38, letterSpacing: -1.2)` يدويًا بدل `VSPDSTypography.priceHero` الذي يوفر `FontFeature.tabularFigures()`، وبدون تنسيق فواصل الآلاف (`12500` بدل `12,500`).
  - `_MoneySplit` في السطر `129` يعرض نفس القيمة مرة أخرى كـ `"أونلاين متحصل"` بعد إلغاء الكاش، ما يكرر المعلومة دون قيمة مضافة!
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):**
  - **قبل:** `12500 ج.م` بالأخضر المتكرر في سطرين متتاليين.
  - **بعد:** استبدال السطر المكرر بملخص تفصيلي مفيد: **"صافي بعد عمولة 5%"** أو **"حجوزات مؤكدة اليوم (X)"** مع تنسيق `#,##0` و`FontFeature.tabularFigures()`.

### `VSP-OWN-003` — هالة خضراء على صورة المالك حتى مع غياب اشتراك Pro [LOW]
- **التخصصات:** Visual Hierarchy Specialist (18)، Brand Identity Designer (26).
- **الدليل الفعلي (`owner_dashboard_header.dart:80-91`):** رغم توثيق إزالة شارات Pro/Free في التعليق أعلى الملف، لا تزال صورة المالك محاطة بحد وظل `VSPColors.accent` الأخضر، مما يعطي ثقلًا زخرفيًا غير مبرر بدل ترك اللون الأخضر للأزرار والإجراءات الرئيسية.
- **Before / After (`PROPOSED DESIGN — NOT IMPLEMENTED`):** إطار محايد `VSPColors.divider` (`#262626`) وظل ناعم محايد ما لم يكن هناك تنبيه حالة فعلي.

### `VSP-OWN-004` — ارتفاع ثابت (`height: 260`) لبطاقة الملعب في عرض المالك (`StadiumCard`) [MEDIUM]
- **التخصصات:** Responsive Design Specialist (45)، Design QA Engineer (38).
- **الدليل الفعلي (`stadium_card.dart:38`):** ارتفاع ثابت `isOwnerView ? 260 : 210` مع نصوص متراكبة بالأسفل؛ مع تكبير خط النظام (`textScaleFactor >= 1.3`) في أندرويد قد تتزاحم النصوص السفلية داخل الطبقة المتدرجة.
