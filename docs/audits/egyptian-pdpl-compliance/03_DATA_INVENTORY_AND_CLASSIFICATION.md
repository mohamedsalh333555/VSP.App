# جرد وتصنيف البيانات الشخصية — مشروع VSP

**المصدر الفعلي للجرد:** فحص مخطط `public` (104 جداول) ومخطط `storage` (10 جداول و3 حاويات) في قاعدة بيانات Staging (`vtwgqyxglevcsxwdmhop`) بتاريخ 2026-11-28.

## 1. حاويات التخزين السحابي (Supabase Storage Buckets)

| الحاوية (`id`) | الرؤية (`public`) | حد الحجم | الأنواع المسموحة | التصنيف القانوني | الملاحظات الأمنية |
|---|---|---|---|---|---|
| `owner_documents` | `false` (خاصة) | 10 MB | `image/jpeg`, `image/png`, `application/pdf` | **بيانات حساسة ومالية/تحقق هوية** | تحوي صور وجهي البطاقة الشخصية، عقود/تراخيص الملعب، وصور سيلفي طعون التغيب (`disputes/`). |
| `profile-pictures` | `true` (عامة) | 10 MB | `image/jpeg`, `image/png`, `image/webp` | **بيانات شخصية عادية (اختيارية الظهور)** | صور حسابات اللاعبين والملاك. |
| `stadium-images` | `true` (عامة) | 10 MB | `image/jpeg`, `image/png`, `image/webp` | **بيانات منشآت عامة** | صور الملاعب والمرافق. |

## 2. تصنيف جداول قاعدة البيانات (`public` — 104 جداول مجمعة حسب الحساسية)

### أ. فئة 1: بيانات الهوية والوثائق الحساسة (High Sensitivity / KYC & Auth PII)
- **`users` (37 عمودًا):** `id`, `email`, `name`, `phone`, `date_of_birth`, `governorate`, `position`, `profile_image_url`, `p2p_instapay`, `p2p_vodafone`, `p2p_bank`, `fcm_token`, `additional_data`, `terms_accepted_at`, `verification_status`.
- **`owner_documents` (10 أعمدة):** `owner_id`, `document_type`, `file_url`, `storage_path`, `status`, `rejection_reason`, `metadata` (تشمل الرقم القومي ومستندات الملكية).
- **`user_device_tokens` (5 أعمدة):** معرّفات أجهزة الدفع الإشعاري FCM المرتبطة بالمستخدم.
- **`account_deletion_requests` (7 أعمدة):** `email`, `phone`, `details`, `status`, `created_at`, `processed_at`.

### ب. فئة 2: البيانات المالية والمدفوعات والتسويات (Financial & Statutory Records)
- **`transactions` (24 عمودًا)**، **`payment_attempts` (17)**، **`payout_settlements` (9)**، **`financial_audit_logs` (11)**.
- **`bookings` (111 عمودًا)**، **`cancellation_refund_queue` (15)**، **`paymob_refund_dispatch_claims` (7)**.
- **`owner_subscription_orders` (20)**، **`owner_trial_ledger` (7)**، **`platform_fee_config` (20)**.
- **`tournament_orders` (21)**، **`team_league_payments` (14)**، **`team_league_cancellation_refund_queue` (16)**، **`vsp_1v1_tournament_orders` (15)**، **`vsp_1v1_cancellation_refund_queue` (15)**، **`strongest_team_orders` (13)**.
- *ملاحظة:* لا يتم تخزين أرقام بطاقات الائتمان أو رموز CVC/CVV في أي من هذه الجداول؛ تُسجل مراجع Paymob فقط (`paymob_order_id`, `paymob_transaction_id`).

### ج. فئة 3: بيانات الموقع الجغرافي والاتصالات والمراقبة (Location, Comms & Audit Logs)
- **`stadiums` (36 عمودًا):** إحداثيات ومواقع المنشآت الرياضية وبيانات أصحابها.
- **`conversations` (13)** و**`chat_messages` (10):** محادثات اللاعبين وأصحاب الملاعب المرتبطة بالحجوزات.
- **`support_tickets` (16)** و**`support_ticket_messages` (6)** و**`reports` (12)** و**`reviews` (8)** و**`ranking_disputes` (13)**.
- **`system_audit_logs` (10)**، **`webhook_logs` (11)**، **`rate_limit_logs` (4)**، **`ai_copilot_audit_events` (17)**، **`copilot_conversations` (7)**، **`copilot_messages` (9)**.

### د. فئة 4: بيانات الفرق والتحديات والتنافس (Gameplay & Team Roster Data)
- **`teams` (46)**، **`team_members` (3)**، **`team_membership_invitations` (8)**، **`team_challenge_codes` (8)**، **`booking_players` (3)**.
- **`championships` (59)**، **`championship_registrations` (13)**، **`championship_rosters` (9)**، **`championship_roster_players` (3)**، **`championship_roster_guests` (3)**، **`tournament_matches` (38)**.
- **`vsp_1v1_tournaments` (21)**، **`vsp_1v1_registrations` (4)**، **`vsp_1v1_tournament_players` (16)**، **`vsp_1vs1_players` (12)**.
- جداول الترتيب والمواسم والإنجازات: `competition_seasons`, `team_season_progress`, `team_monthly_rankings`, `team_xp_ledger`, `monthly_champion_awards`, `immortal_reward_entitlements`, `immortal_reward_player_snapshots` (تتضمن بيانات قمصان ومقاسات الفائزين!), `strongest_team_*`, `team_skills_*` وغيرها.

### هـ. فئة 5: إعدادات المنصة العامة غير الشخصية (System & Public Reference Data)
- `app_config`, `app_settings`, `banners`, `promotions`, `subscription_plans`, `platform_business_rules`, `league_settings`, `internal_function_secrets` (مقيد بالكامل لطبقة الخادم)، `user_public_profiles`, `booking_public_feed`.
