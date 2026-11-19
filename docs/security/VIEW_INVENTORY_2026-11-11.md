# 76.01 — جرد عروض البيانات وصلاحياتها الحالية
تاريخ القراءة: 2026-11-11. تنفيذ للجزء الجردي من B02 / SEC-02؛ لا نشر إنتاج ولا قراءة صفوف مستخدمين.
الحالة: **76.01 VERIFIED (جرد فقط)**. العدد القديم «أربعة» في اسم المهمة ليس الواقع الحالي: جرى حصر جميع عروض public التسعة في كل بيئة، ومن ثم حصر مجموعة SECURITY DEFINER كاملة دون الاقتصار على أسماء قديمة.

| العرض | نمط الإنتاج | صلاحية SELECT المباشرة بالإنتاج | نمط staging | صلاحية SELECT المباشرة بـstaging |
|---|---|---|---|---|
| admin_pending_refunds | invoker | anon=true; authenticated=true | definer | anon=false; authenticated=false |
| admin_stadium_settlements | invoker | anon=false; authenticated=false | definer | anon=false; authenticated=false |
| courts | invoker | anon=false; authenticated=false | invoker | anon=true; authenticated=true |
| owner_subscription_status | invoker | anon=false; authenticated=true | invoker | anon=false; authenticated=true |
| public_subscription_plans | invoker | anon=true; authenticated=true | invoker | anon=true; authenticated=true |
| teams_public | invoker | anon=false; authenticated=true | invoker | anon=false; authenticated=true |
| tournament_clean_sheets | invoker | anon=true; authenticated=true | invoker | anon=true; authenticated=true |
| v_bookings_with_refund | invoker | anon=false; authenticated=true | invoker | anon=true; authenticated=true |
| v_financial_reconciliation | invoker | anon=true; authenticated=true | definer | anon=false; authenticated=false |

نتيجة الجرد: الإنتاج 9 invoker و0 definer. staging بها 6 invoker و3 definer؛ الثلاثة definer مسحوبة SELECT من anon وauthenticated. اختلافان آخران في المنح: courts وv_bookings_with_refund. لا يعد أي GRANT وحده دليلاً على السماح بصفوف حساسة، ولا invoker وحده دليلاً على اكتمال سياسات الجداول الأساسية.

## الدليل القابل للإعادة
الملف VIEW_INVENTORY_2026-11-11.json يحفظ نتائج metadata وتعريفات العروض من البيئتين؛ لا يحتوى نتائج SELECT لبيانات العملاء.
استعلام القراءة:
```sql
select c.relname,c.reloptions,pg_get_viewdef(c.oid,true) as definition,
  has_table_privilege('anon',c.oid,'SELECT') as anon_select,
  has_table_privilege('authenticated',c.oid,'SELECT') as authenticated_select
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relkind='v' order by c.relname;
```

## ما لم يغلق
76.02 تحديد الصلاحيات المطلوبة حسب أدوار المنتج، 76.03 الإصلاح عند ثبوت الحاجة، 76.04/05/07 اختبارات الوصول الإيجابية والسلبية بين مستخدمين، و76.06 توثيق نتيجة الحماية النهائية تظل غير مغلقة. لم تنفذ استعلامات بيانات حساسة أو اختبارات مستخدمين على الإنتاج.
الجرد يعالج غموض الأعداد التاريخية والتحذير المسجل في Phase 8؛ لا يثبت وحده غياب تسريب.
العداد بعد قبول الجرد وحده: **77 / 620 مقبول، 543 لم يقبل بالكامل**؛ منها 76 علامة تاريخية + مهمة جرد جديدة واحدة.
