# امتثال الموقع العام ونموذج حذف الحساب وملفات الارتباط (`vsp_website`)

**المصدر المفحوص:** `vsp_website/src/app/layout.tsx`, `PrivacyClient.tsx`, `TermsClient.tsx`, `DeleteAccountClient.tsx`, `src/locales/ar.ts`, `src/locales/en.ts`.

## 1. ملفات الارتباط وأدوات التتبع (Cookies & Trackers)
- بفحص `src/app/layout.tsx` والمكونات المحيطة في `vsp_website`: **لا توجد أدوات تتبع إعلانية أو ملفات تعريف ارتباط خارجية (مثل Meta Pixel أو Google Analytics أو TikTok Pixel)** مدمجة حاليًا في الكود.
- يقتصر التخزين المحلي على تفضيل اللغة (`LanguageContext`) ولا يجمع بيانات سلوكية تسويقية. (في حال إضافة أدوات تحليل أو إعلانات مستقبلًا، يلزم شريط موافقة Cookies صريح قبل التحميل).

## 2. تدقيق نموذج حذف الحساب العام (`/delete-account`)
- **الوظيفة الحالية (`DeleteAccountClient.tsx:20`):** يرسل طلبًا إلى جدول `public.account_deletion_requests` عبر سياسة `anon_can_submit_account_deletion_request` (`INSERT` لـ `anon, authenticated`) مع ضوابط طول وتحقق مباشر في قاعدة البيانات:
  - `email`: 3–320 حرفًا، `phone`: 8–20 حرفًا، `details`: حد أقصى 2000 حرف، `status = 'pending'`.
- **حماية الخصوصية:** لا توجد سياسة `SELECT` للعامة على `account_deletion_requests`، مما يمنع تسرب قائمة الطلبات للغير.
- **الفجوة التشغيلية المطلوب استكمالها:**
  1. وجود مسار تحقق من الملكية (Verification OTP/تأكيد عبر الهاتف المسجل أو البريد) قبل تنفيذ الحذف الإداري لمنع إساءة الاستخدام.
  2. أتمتة تنبيه فريق الدعم/DPO عند وصول طلب `pending` جديد لضمان الإغلاق ضمن SLA (7 أيام عمل).
  3. توحيد ما تبقى من العبارات التسويقية القديمة التي تذكر "العربون/الكاش" خارج `terms_sec4_noshow_desc` (التي أُصلحت في `1922fc5`).
