# سجل اللقطات الفعلية ومصفوفة التغطية البصرية (Screenshots & Coverage Matrix)

**إجمالي اللقطات الفعلية الملتقطة والمُراجَعة بصريًا:** **77 صورة PNG حية** موزعة على:
- **`screenshots/android/` (48 صورة):** تطبيق `VSP.App` على محاكي `Pixel_9` (`1080x2424`, Staging `app.vsp.sports.staging`).
- **`screenshots/web/` (13 صورة):** الموقع العام `vsp_website` عبر Chrome DevTools (`http://localhost:3000`).
- **`screenshots/admin/` (16 صورة):** لوحة الإدارة `vsp-admin-panel` عبر Chrome DevTools (`http://localhost:4173`، Staging).

---

## 1. لقطات تطبيق الموبايل — `Pixel_9` (`48` صورة)

| # | الملف | الشاشة / التدفق | اللغة | أبرز ما رُصد بصريًا في الصورة |
|---|---|---|---|---|
| 1–4 | `01_welcome_slide1.png` .. `04_welcome_slide3_ar.png` | شاشات الترحيب الثلاث + اختيار الدور (EN & AR) | EN/AR | زر المتابعة والرجوع بلا `content-desc` (`NAF="true"`)، ارتفاع رابط الدخول ~18dp، وفراغ سفلي |
| 5–9 | `05_create_account_player_ar.png`, `06_terms_modal_player_ar.png`, `07_signup_player_ar.png`, `08_login_ar.png`, `08_signup_player_bottom_ar.png` | إنشاء حساب اللاعب + نافذة الشروط + فورم التسجيل + الدخول | AR | تفكك `"إ ن ش ا ء   ح س ا ب   ج د ي د"`، **`Cairo`/`Matrouh` بالإنجليزية**، شارات شروط نظيفة (Paymob 100%) |
| 10–15 | `09_vsp_date_picker_ar.png`, `10_login_ar.png`, `11_forgot_password_dialog_ar.png`, `12_global_error_screen_ar.png`, `13_create_account_owner_ar.png`, `14_terms_modal_owner_ar.png`, `15_signup_owner_ar.png` | منتقي التاريخ، دخول، نسيت كلمة المرور، الخطأ العام، إنشاء وتسجيل المالك | AR/Mix | قطع رقم `2001`، زر مربع فوق كبسولي، **`.been notified` + `Try Again`**، التفاف عنوان المالك، `"وإلتزامات"` |
| 16–17 | `16_offline_state_ar.png`, `17_verify_email_otp_ar.png` | حالة انقطاع الإنترنت + التحقق بالرمز OTP | AR | رسالة أوفلاين واضحة بأزرار متزاحمة نسبيًا؛ 6 مربعات OTP غير محمية بـ LTR وزر تأكيد باهت التباين |
| 18–23 | `18_player_home_ar.png`, `19_player_matches_ar.png`, `20_player_champions_ar.png`, `21_player_my_bookings_ar.png`, `22_player_profile_ar.png`, `23_player_profile_scrolled_ar.png` | الرئيسية (أسوان)، المباريات، الأبطال، حجوزاتي، الملف الشخصي (أعلى وأسفل) | AR | هيرو `"لم نصل إلى أسوان بعد!"` فوق مباريات نشطة، **`Nov 28` / `10 PM-11 PM` / `Cup` / `League` / `Aswan`**، تداخل `BottomNavBar` مع القائمة |
| 24–28 | `24_player_champions_teams_ar.png`, `25_player_strongest_team_ar.png`, `26_player_tournament_detail_ar.png`, `27_player_my_team_ar.png`, `28_player_location_picker_ar.png` | منصة ترتيب الفرق، أقوى فريق، تفاصيل البطولة، فريقي، منتقي المحافظة | AR | اقتطاع شارات الجوائز (`500...`), دوائر منصة فارغة، **`pts 0.0`**، **`0W-0D-0L`**، زر **`تحميل صورة`** باهت |
| 29–33b | `29_player_home_cairo_ar.png`, `30_player_stadium_detail_ar.png`, `30b_stadium_status_tab_ar.png`, `31_player_booking_slots_ar.png`, `32_player_slot_selection_ar.png`, `32b_player_slot_selected_ar.png`, `33_player_checkout_summary_ar.png`, `33b_checkout_leave_dialog_ar.png` | الرئيسية (القاهرة)، تفاصيل الملعب، تبويب الحالة، خيارات المباراة، المواعيد، التأكيد المالي، تأكيد المغادرة | AR | هيرو صورة أسود ~450px، **`4.5 (0)`**، نص **`العربون/المبلغ`** (`30b_`)، **`325.8 ج.م` مقابل `325.82 ج.م` + `تشفر آمن` + `٢٠٢٦/١١/٢٨`** (`33_`)، قص `"3 الخميس"` |
| 34–34b | `34_player_profile_en.png`, `34b_player_home_en.png` | تبديل التطبيق للإنجليزية (الملف الشخصي + الرئيسية) | EN (`LTR`) | **`300 eg`** و**`275 eg`** بدل `EGP`، تبعثر `[DEMO]` مع العربية، تداخل `BottomNavBar` أسفل القائمة |
| 35–43 | `35_owner_dashboard_ar.png`, `36_owner_analytics_ar.png`, `37_owner_ledger_ar.png`, `38_owner_payout_withdraw_ar.png`, `39_owner_tournaments_ar.png`, `40_owner_bookings_ar.png`, `41_owner_profile_ar.png`, `42_owner_stadiums_ar.png`, `43_owner_payout_history_ar.png` | لوحة المالك كاملة: التشغيل اليومي، التحليلات الذكية، السجل، السحب، البطولات، جدول الحجوزات، الملف الشخصي، الملاعب، سجل السحوبات الفارغ | AR | أسهم **`كشف الحساب ->`** و**`300 ج.م ->`** لليمين في RTL، **`تحصيل كاش ونقدي (0%)`** + `0 كاش` (`36_`)، **`كاش مطلوب تحصيله`** (`40_`)، `%-100.0`، وعلامة `#3B82F6` الزرقاء (`42_`) |

---

## 2. لقطات الموقع العام — `vsp_website` (`13` صورة)

| # | الملف | المسار والدقة | الحالة البصرية المرصودة |
|---|---|---|---|
| 1–4 | `01_web_home_ar_desktop.png`, `02_web_home_en_desktop.png`, `03_web_home_ar_tablet.png`, `04_web_home_ar_mobile.png` | `/` & `/en` (`1440`, `768`, `390`) | **عالق على شاشة التحميل `loading.tsx`** (`next/image` رفض `images.unsplash.com` في SSR) |
| 5–8 | `05_web_about_ar_desktop.png`, `06_web_teams_ar_desktop.png`, `07_web_ranking_ar_desktop.png`, `08_web_championships_ar_desktop.png` | `/about`, `/teams`, `/ranking`, `/championships` | `/teams` عالق (`42501 teams_public`)؛ `/ranking` يعرض `Aswan` + صفوف `#` بلا أرقام؛ و**عمود Footer أيسر فارغ** + رابط `"باقات الاشتراك"` |
| 9–13 | `09_web_privacy_ar_desktop.png`, `10_web_terms_ar_desktop.png`, `11_web_refund_ar_desktop.png`, `12_web_contact_ar_desktop.png`, `13_web_delete_account_ar_desktop.png` | `/privacy`, `/terms`, `/refund`, `/contact`, `/delete-account` | نصوص قانونية نظيفة ومتناسقة مع Paymob 100%؛ تعارض اتجاه أمثلة المدخلات وزر إرسال يساري في `/contact` و`/delete-account` |

---

## 3. لقطات لوحة الإدارة — `vsp-admin-panel` (`16` صورة)

| # | الملف | الصفحة / العرض | الحالة البصرية المرصودة |
|---|---|---|---|
| 1–2 | `01_admin_login_ar_desktop.png`, `02_admin_login_en_desktop.png` | تسجيل دخول المشرف (AR & EN) | تخطيط مركزي نظيف، حاشية حقوق إدارية صغيرة `10px/11px`، تبديل لغة واضح |
| 3–6 | `03_admin_dashboard_ar.png`, `04_admin_owner_audits_ar.png`, `05_admin_users_ar.png`, `06_admin_disputes_ar.png` | الرئيسية، مراجعة الملاك، المستخدمين، النزاعات | `03_`: حجم تداول `0 ج.م` رغم حجوزات `350/325/300`؛ `04_`: أفاتار `[` لـ `[DEMO]` + `Cairo`؛ `06_`: **قص الـ Sidebar اليميني** |
| 7–11 | `07_admin_payout_settlements_ar.png`, `08_admin_gamification_ar.png`, `09_admin_strongest_team_ar.png`, `10_admin_immortal_rewards_ar.png`, `11_admin_tournaments_ar.png` | التسويات، المواسم، أقوى فريق، جوائز Immortal، البطولات | `08_`: تواريخ إنجليزية + `active`؛ `09_`: **قص Sidebar** + شارات `draft/ongoing/cancelled`؛ `10_`: `()` فارغة + `eligible/pending` |
| 12–16 | `12_admin_support_tickets_ar.png`, `13_admin_audit_logs_ar.png`, `14_admin_payout_ledger_ar.png`, `15_admin_dashboard_mobile.png`, `16_admin_dashboard_en.png` | الدعم، سجل التدقيق، دفتر التسويات، موبايل `390px`, إنجليزي `1440px` | `12_`: **قص Sidebar**؛ `14_`: 11 عمودًا والتفاف `d98c39c6-#`؛ `16_`: **بنود Sidebar عربية داخل الإنجليزية** |

---

## 4. الأسطح والحالات غير المُحقَّق منها بصريًا بالصورة (`NOT VISUALLY VERIFIED`)

| النطاق | السبب الدقيق الموثق |
|---|---|
| **بوابة الدفع الفعلية المستضافة (`Paymob Iframe`)** | تم التوقف عمدًا عند شاشة التأكيد (`33_player_checkout_summary_ar.png`) لتفادي إطلاق عملية دفع حقيقية، فضلاً عن أن `create_paymob_intention` و`paymob_webhook` غير منشورين بعد على Staging. |
| **تطبيق iOS الأصلي (`iOS Native`)** | بيئة العمل الحالية هي Windows بدون macOS / Xcode / iOS Simulator. |
| **معاينة `Flutter Web` داخل المتصفح** | لم تُلتقط في المتصفح لأن الفحص الحي للتطبيق نُفذ على المحاكي الأصلي `Pixel_9` (طبقًا لسياسة التدقيق التي لا تعدّ Flutter Web بديلًا عن Android/iOS). |
| **4 صفحات إدارية ثانوية في `vsp-admin-panel`** | `BannersManagementPage`, `CRMSettingsPage`, `OwnerSubscriptionsPage` (متوقفة), `League1v1Page` (`NOT VISUALLY VERIFIED IN LIVE BROWSER` — فُحصت معماريًا فقط). |
| **شاشات ثانوية متفرقة داخل التطبيق** | معالج إضافة ملعب جديد خطوة بخطوة (`AddStadiumWizard`), شاشة المحادثة الحية (`ChatScreen`), ومستندات الطعن (`NoShowDispute`). |
