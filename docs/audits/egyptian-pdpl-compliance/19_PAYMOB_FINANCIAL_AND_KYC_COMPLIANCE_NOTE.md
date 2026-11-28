# الحدود التقنية والمالية لبوابة Paymob وبيانات KYC للملاك

**المصدر المفحوص:** `supabase/functions/create_paymob_intention/index.ts`, `paymob_webhook/index.ts`, `process_paymob_refund/index.ts`, `process_tournament_refund/index.ts`, والهجرة `20261128080000`.

## 1. حدود بيانات البطاقات (PCI-DSS Boundary)
- لا تقوم خوادم VSP أو تطبيق Flutter أو قاعدة البيانات بتخزين أرقام البطاقات البنكية أو رموز CVV/CVC أو أرقام التعريف السرية.
- عند إنشاء نية الدفع (`create_paymob_intention/index.ts:353-365`)، يُرسل للخادم فقط الحد الأدنى اللازم لـ Paymob (`phone_number`, `email`, اسم العميل، المبلغ المحسوب عبر `calculate_booking_pricing_v2`).
- يتم التحقق من إشعارات الدفع الواردة عبر التوقيع الرقمي `HMAC` في `paymob_webhook`.

## 2. حماية مسارات المطابقة المالية والـ KYC
- **إصلاح P0 في المرحلة الأولى (`660f1aee`):** إغلاق ثغرة الوصول المجهول (`anon`) لدالة `public.import_paymob_reconciliation_row(text, numeric, text)` ومنع تجاوز `auth.uid() IS NULL` إلا لـ `service_role`.
- **مستحقات الملاك وبيانات P2P (`p2p_instapay`, `p2p_vodafone`, `p2p_bank`):**
  - محفوظة في `public.users` ومحمية بـ RLS للمالك نفسه والإدارة فقط.
  - لا يُسمح بحذف الحساب عند وجود مستحقات/طلبات استرداد معلقة (`delete_user_permanently`), ويجب الحفاظ على سجلات `transactions` و`payout_settlements` المحاسبية للالتزام الضريبي المصري `[LEGAL_REVIEW_REQUIRED]`.
