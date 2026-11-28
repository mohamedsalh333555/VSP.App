# حوكمة صلاحيات الإدارة وسجلات التدقيق (Admin Access Governance & Audit Logging)

## 1. ضوابط صلاحيات لوحة الإدارة (`vsp-admin-panel`)
- تعتمد اللوحة على المصادقة الرسمية عبر Supabase Auth والتحقق في الدوال المحمية من أدوار محددة (`admin`, `co_founder`, `cofounder`, `super_admin`) عبر دوال مثل `is_admin_or_cofounder(auth.uid())`.
- **تعديل أمني حرج مُنفذ (`660f1aee`):** تم إغلاق ثغرة في دالة المطابقة المالية `public.import_paymob_reconciliation_row(text, numeric, text)` حيث كانت تسمح بتجاوز فحص `auth.uid()` عندما يكون `auth.uid() IS NULL`، مع حصر الصلاحية على الأدمن الموثّق أو `service_role`.
- **قواعد حماية الحسابات الحساسة داخل `delete_user_permanently`:** يمنع النظام حذف المؤسسين أو حذف الأدمن لنفسه (`PROTECTED_ACCOUNT`, `CANNOT_DELETE_SELF`)، ويوثق أي حذف إداري لمستخدم في `public.system_audit_logs` (`action = 'admin_permanent_delete_user'`).

## 2. سجلات التدقيق المفعّلة (Audit Trail)
- **`system_audit_logs`:** محمي بسياسة RLS `"Admins can view audit logs"` لـ `authenticated` فقط (لا صلاحية للعامة `anon`).
- **`financial_audit_logs`:** محمي بسياسات `financial_logs_admin_all` و`financial_logs_owner_select` و`financial_logs_user_select` بحيث يرى كل طرف قيوده المالية فقط ويرى الأدمن السجل الكامل للتسوية.
- **`owner_documents`:** خاضعة لسياسات `owner_documents_owner_select`, `owner_documents_owner_insert`, `owner_documents_admin_update`, `owner_documents_admin_delete`، وتخزن في حاوية `owner_documents` الخاصة (`public: false`).

## 3. توصيات حوكمة الإدارة قبل الإطلاق `[FOUNDER_ACTION]` / `[LEGAL_REVIEW_REQUIRED]`
1. تفعيل المصادقة الثنائية (MFA / 2FA) لكل حسابات `admin` و`co_founder` و`super_admin` في Supabase Auth.
2. مراجعة قائمة الموظفين أصحاب صلاحيات الإدارة شهريًا وسحب الصلاحية فورًا عند انتهاء الخدمة.
3. توقيع تعهدات السرية وعدم إفشاء البيانات (NDA) لكل من لديه وصول لوثائق `owner_documents` أو بيانات المستخدمين.
4. التأكد في لوحة الإدارة من أن عرض أي ملف داخل `owner_documents` يتم دائمًا عبر `createSignedUrl` قصير المدة (مثلاً 60–300 ثانية) وعدم حفظ روابط موقعة طويلة الأمد.
