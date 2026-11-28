# تدقيق أذونات تطبيق الهاتف والحزم البرمجية (Mobile Permissions & SDK Privacy Audit)

**المصدر المفحوص:** `android/app/src/main/AndroidManifest.xml` + خدمات `lib/core/services/`.

## 1. جدول الأذونات المعلنة في أندرويد والغرض المباشر

| الإذن (`AndroidManifest.xml`) | الغرض التقني الفعلي في VSP | تقييم الضرورة (Data Minimization) | ملاحظات الخصوصية |
|---|---|---|---|
| `INTERNET` | الاتصال بخدمات Supabase وPaymob وFCM | ضروري | مشفر عبر HTTPS/TLS |
| `ACCESS_FINE_LOCATION` & `ACCESS_COARSE_LOCATION` | عرض الملاعب القريبة من اللاعب والتحقق الجغرافي لطعن التغيب (نطاق 150م بدقة < 50م) | ضروري أثناء الاستخدام فقط | **ممتاز:** لا يوجد إذن `ACCESS_BACKGROUND_LOCATION` لتتبع الخلفية. |
| `CAMERA` | التقاط صور الملاعب، مسح/التقاط وثائق المالك، أو سيلفي طعن التغيب | ضروري عند الطلب فقط | يُطلب عند تفعيل الميزة مباشرة من المستخدم |
| `READ_EXTERNAL_STORAGE` (`maxSdkVersion="32"`) | اختيار الصور من المعرض للأجهزة الأقدم من Android 13 | ضروري ومقيد بإصدار SDK 32 | متوافق مع معايير Scoped Storage الحديثة |
| `POST_NOTIFICATIONS` | إشعارات حالة الحجز والدفع والتحديات عبر FCM | اختياري (وقت التشغيل) | يعتمد على إذن صريح من المستخدم في Android 13+ |

## 2. الحزم السحابية الخارجية (Third-Party SDKs) ودورة التوكن
- **Firebase Cloud Messaging (`fcm_push`, `fcm_queue_worker`, `notification_service.dart`):**
  - يتم تحديث `users.fcm_token` و`user_device_tokens` عند الدخول.
  - تم التحقق في `lib/core/providers/auth/auth_sign_out_handler.dart:23` أن تسجيل الخروج يقوم بمسح `{'fcm_token': null}`، وتقوم `delete_user_permanently` بحذف صفوف `user_device_tokens`.
- **Google Sign-In / OAuth:**
  - يستخدم مصادقة Supabase OAuth ويستكمل البيانات الناقصة (مثل تاريخ الميلاد والموافقة) عبر `player_onboarding_screen.dart` / `owner_onboarding_screen.dart`.
- **حوكمة الإفصاح في المتاجر (Google Play Data Safety / Apple Privacy Nutrition Labels):**
  - يجب تطابق الإفصاح المنشور على Google Play وApp Store مع الجدول أعلاه (خاصة جمع الموقع الدقيق عند البحث/الطعون والصور/الوثائق للملاك)، وربط صفحة حذف الحساب العامة `https://www.vspapp.online/delete-account` في Google Play Console `[FOUNDER_ACTION]`.
