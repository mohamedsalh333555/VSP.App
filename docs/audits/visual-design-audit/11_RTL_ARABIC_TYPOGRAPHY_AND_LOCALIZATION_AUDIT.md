# تدقيق الخط العربي والاتجاه والتوطين (`RTL, Arabic Typography & Localization Audit`)

**التخصصات المسؤولة:** Arabic Typography Designer (48)، RTL and Localization Designer (49)، Typography Designer (19)، Design QA Engineer (38).  
**نطاق التحقق:** فحص حي عبر 77 لقطة شاشة في التطبيق (`Pixel_9`) والموقع ولوحة الإدارة.

---

## 1. قائمة المشكلات الحية المصنفة

### `VSP-RTL-001` — تطبيق `letterSpacing` على النص العربي يمزق اتصال الحروف [CRITICAL]
- **الدليل الحي (`05_create_account_player_ar.png`, `13_create_account_owner_ar.png`, `10_login_ar.png`):** الحروف العربية المتصلة تفقد اتصالها عند فرض `letterSpacing: 1.2` أو `-1.0` وتظهر **`"إ ن ش ا ء   ح س ا ب   ج د ي د"`**، بينما يضيق `height: 0.9` الحروف المنقوطة (`ي، ق، ث`).
- **التوصية (`PROPOSED DESIGN — NOT IMPLEMENTED`):** قاعدة شاملة: **`letterSpacing: 0.0`** في كل أنماط النصوص العربية (`display`, `title`, `body`, `label`) و`height >= 1.35` للعناوين و`1.45` للمتن.

### `VSP-RTL-002` — انعكاس أسهم الاتجاه داخل RTL وانعكاس صف OTP وسالب النسب [CRITICAL]
- **الدليل الحي:**
  1. `17_verify_email_otp_ar.png` (`verify_email_screen.dart:250-262`): خانات الرمز الست تعكس اتجاه القراءة في RTL!
  2. `35_owner_dashboard_ar.png`: **`"كشف الحساب ->"`** سهم لليمين على يسار كلمة عربية!
  3. `40_owner_bookings_ar.png`: **`"300 ج.م ->"`** سهم لليمين!
  4. `36_owner_analytics_ar.png`: **`"%-100.0 تراجع"`** إشارة السالب تقفز لليمين!
  5. `12_global_error_screen_ar.png`: `.been notified` نقطة في بداية السطر!

### `VSP-RTL-003` — تداخل النصوص الإنجليزية والوحدات العامية والرموز في الواجهة العربية والعكس [HIGH]
- **الدليل الحي الموثق:**
  - أسماء محافظات إنجليزية داخل العربية: `Cairo`, `Matrouh` (`07_`, `08_`), `Aswan` (`20_`, `24_`, `25_`, `07_web`, `04_admin`, `10_admin`).
  - تواريخ وأزمنة إنجليزية داخل المباريات العربية (`18_`, `19_`): `Nov 28`, `10 PM-11 PM`.
  - مصطلحات إنجليزية غير مترجمة: `Cup`, `League`, `12d 21h 1m`, `pts 0.0`, `0W-0D-0L`, `XP`, `draft`, `ongoing`, `cancelled`, `active`, `eligible`, `pending`.
  - عملة إنجليزية خاطئة في التطبيق (`34b_player_home_en.png`): **`300 eg`** و**`275 eg`** بدل **`EGP`**.
  - تبعثر علامة `[DEMO]` في Bidi (`34b_`): **`[5 كابتن [DEMO`**.
  - تسرب بنود عربية داخل لوحة الإدارة الإنجليزية (`16_admin_dashboard_en.png`): `المواسم وXP والترتيب`, `بطولة أقوى فريق`, `جوائز Immortal`, `الدعم الفني`.

### `VSP-RTL-004` — تضارب نظام الأرقام (هندي شرق عربي مقابل غربي) في نفس الشاشة [MEDIUM/HIGH]
- **الدليل الحي:**
  - `33_player_checkout_summary_ar.png`: `٢٠٢٦/١١/٢٨` و`١٠:٠٠ ص` (أرقام هندية) بجانب `300 ج.م` و`07:59` (أرقام غربية).
  - `35_owner_dashboard_ar.png`: `١٠:٠٠ ص` مقابل `300 ج.م` و`285 ج.م`.
  - `06_terms_modal_player_ar.png`: عناوين `١، ٢` مقابل `18` و`21` داخل النص.
- **التوصية (`PROPOSED DESIGN — NOT IMPLEMENTED`):** اعتماد الأرقام العربية الغربية (`0–9`) موحدة مع `FontFeature.tabularFigures()` عبر جميع الجداول والفواتير والأزمنة لسرعة المسح المالي ومنع اللبس المحاسبي.

### `VSP-RTL-005` — تعطل خط `Tajawal` الحقيقي في الموقع واختلاط الخطوط في الإدارة [MEDIUM]
- **الدليل (`globals.css:9-11`, `vsp_admin_panel/index.html`):** الموقع يسقط لخطوط `Segoe UI / Tahoma`، ولوحة الإدارة تحمّل `Inter` في رأسها بينما توكنز التصميم تقصد `Poppins`.
