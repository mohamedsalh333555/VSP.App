# VSP — تنفيذ متابعة متعدد المستودعات (18 نوفمبر 2026)

**حالة التقرير:** تحديثات مصدر محفوظة على فروع `uxlp-44-implementation` فقط، وليست نشرًا ولا قبولًا شاملًا للمنتج.

## نقطة البداية والعداد

- العداد الرسمي الوحيد الموجود في `docs/VSP_CURRENT_TASK_COUNTER.md`: **640 مهمة نشطة، 328 مقبولة، 312 مفتوحة**. لا تغيّر في المقبول بسبب التحديثات الواردة هنا؛ الإصلاحات الجزئية لا تساوي قبول بند مستقل.
- لا دمج في `main`، لا إنتاج، لا تعديلات بيانات عملاء، لا Paymob، لا إصدار APK، ولا تغيير للصفحة الرئيسية.

## تطبيق Flutter — إصلاحات مصدرية

| التغيير | GitHub | الدليل |
|---|---|---|
| ربط تحديثَي Team Skills برقمَي نسخة حقيقيين في vsp-staging وتوسيع فحص أسماء التحديثات المقيدة | [7bd59e](https://github.com/mohamedsalh333555/VSP.App/commit/7bd59eefeefc604d8170ebf873be3e90547722c4) | [Account SQL run 44361498095 PASS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44361498095)، [Issue #45 resolved](https://github.com/mohamedsalh333555/VSP.App/issues/45) |
| تصحيح بانر 1v1 في صفحة فريقي إلى تاريخي؛ عرض الألقاب الخام على أنها مسجلة لا معتمدة؛ تصحيح نص النقاط | [4018e7](https://github.com/mohamedsalh333555/VSP.App/commit/4018e7e0b421ac3668f19c208df57988d1848393) | اختبار مصدر + وظائف نصية |
| إيقاف عرض `rankTitle` المحسوب كنسبة ترتيب رسمية في صفحة الفريق، وعرض النقاط المسجلة عند وجود مواجهات | [c1f606](https://github.com/mohamedsalh333555/VSP.App/commit/c1f6064d8fcf370fcbbe968ed07989a49ffc42b4) | اختبار إظهار/إخفاء عربي وإنجليزي |
| منع عدد الأعضاء المخبأ من التحول إلى عدد موثّق عند فشل جلب العضوية؛ عرض — إلى حين التحقق | [bd6216](https://github.com/mohamedsalh333555/VSP.App/commit/bd621602602c54ff45845e144e003a7815cee781) | اختبار حالات مجهولة/صفر/رقم |
| اختبارات CI موجهة لشاشة الفريق (النتائج، الترتيب، العضوية، 1v1 التاريخي) | [cb9f84](https://github.com/mohamedsalh333555/VSP.App/commit/cb9f8466cad41f3225ef4560cb043cdcb43e5eda) | [Team Profile UX CI](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44364141213) |
| ترجمة اسم اللاعب غير المحدد في قائمة الفريق، وعدم افتراض اسم حقيقي | [4520f3](https://github.com/mohamedsalh333555/VSP.App/commit/4520f3a6d565f6e4e7ba02262b651f02d787e7aa) | اختبار ترجمة |
| إدخال اختبار الترجمة في فحص الفريق المخصص | [7c4e09](https://github.com/mohamedsalh333555/VSP.App/commit/7c4e0947c8f5a5c4296ecb662acfc5a7dbf1fce4) | انتظر نتيجة CI على آخر SHA |

## لوحة الإدارة — إصلاحات مصدرية

| التغيير | GitHub |
|---|---|
| عدم تمثيل القيم المالية الناقصة أو السلبية كصفر؛ تسمية العدد وفق طلبات الملاك وليس الملاعب | [973f5b](https://github.com/mohamedsalh333555/vsp-admin-panel/commit/973f5b5f2be94db1c6e286f0cf9f124f53344cc1) |
| تصحيح قارئ الأرقام المالية النصية الموثوقة واختباره | [e87c2d](https://github.com/mohamedsalh333555/vsp-admin-panel/commit/e87c2dccf43584fe68e41f0e0dd2ef1f1f54b108) |
| تغطية فحص الإحصائيات بعملية CI | [bc0a59](https://github.com/mohamedsalh333555/vsp-admin-panel/commit/bc0a59c5aaaad0b20b37f3408c17b1440e03a50d) |
| فشل مغلق لطلبات الوثائق والملاعب الناقصة عند مراجعة ملاك الملاعب/اشتراكاتهم | [95364e](https://github.com/mohamedsalh333555/vsp-admin-panel/commit/95364e6a65d92a6df2bb2d0056dc59be76f08739) |
| رفض أكواد تعديل شروط البحث التي قد تغيّر استعلام بحث المالك | [95ed77](https://github.com/mohamedsalh333555/vsp-admin-panel/commit/95ed7737266e8c97379d361d290de676b731de13) |
| إعادة ربط سجل جوائز المهارات بالمستخدم الحالي؛ عدم عرض سجل حساب سابق أثناء تبديل حساب المسؤول | [8db56c](https://github.com/mohamedsalh333555/vsp-admin-panel/commit/8db56c734e4d4b81a4a3c940b8d9a9f9094098d1) |

[Admin Panel CI #44364905899: tests/build passed](https://github.com/mohamedsalh333555/vsp-admin-panel/actions/runs/44364905899).

## الموقع — إصلاحات مصدرية

| التغيير | GitHub |
|---|---|
| تنقية التقييمات غير الصالحة أو المكررة وعدم تسريب أعمدة جديدة من رد الخادم؛ عدم اختراع سعر أو جائزة أو سعة بطولات | [bdb8aa](https://github.com/mohamedsalh333555/vsp_website/commit/bdb8aa9b1dc7e667888541d1f6dd26c8b6ad2691) |
| السماح ببطولة غير موجودة في تعريف النوع الموثوق بعد مراجعة TypeScript CI | [9a2b69](https://github.com/mohamedsalh333555/vsp_website/commit/9a2b69f7e386f6fd3649586546ec0adafeb73e16) |
| عدم تعطل الواجهة إذا كانت حالة البطولة غير معروفة من المصدر | [2e9967](https://github.com/mohamedsalh333555/vsp_website/commit/2e9967496b29d3a1f297b0d5c72a4f47bca32829) |

[Website CI #44362417081: tests/typecheck passed](https://github.com/mohamedsalh333555/vsp_website/actions/runs/44362417081) في SHA السابق للتصحيح الأخير؛ لا يُستنتج منه نجاح أحدث SHA.

## ما لم يُحسم

- لم تُجرَ اختبارات صلاحيات فعلية بحسابين من واجهة عميل على Staging أو مقارنة كاملة للإنتاج؛ إغلاق #45 يعني حل تعارض **جرد نسخ التحديثات** فقط.
- بعض مسارات الموافقة الثنائية للتحديات، تصاريح الملعب ونشر الجوائز ما زالت تحتاج تحققًا حقيقيًا ولا يجوز تنشيطها لعموم اللاعبين بهذا الدليل فقط.
- لا استنتاجات من مقاييس الاحتفاظ أو تأثير تجربة المستخدم قبل بيانات الاستخدام الحقيقية.
- لا يُقبل أي رقم جديد في العداد الرسمي اعتمادًا على source commits وحدها. نتائج CI النهائية على أحدث SHA مطلوبة.
