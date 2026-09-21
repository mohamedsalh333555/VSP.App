# VSP — Shorebird OTA Update Workflow

## هدف

VSP يستخدم Google Play لتوزيع الـBase Release والـFull Releases التي تحتاج تغييرات Native، بينما تستخدم Shorebird Code Push لتوزيع تغييرات Dart/Flutter عبر OTA.

## ما يدخل في OTA

- Flutter widgets وواجهات المستخدم.
- Dart business logic.
- Providers وstate management.
- Routing.
- نصوص وترجمات موجودة داخل الكود.
- إصلاحات Bugs في Dart.
- تغييرات منطق Copilot الموجود داخل Flutter.
- Pure-Dart dependency updates عندما لا تضيف Native code.

## ما يحتاج Full Release / Google Play

- Kotlin / Java.
- AndroidManifest.xml.
- build.gradle / build.gradle.kts.
- إضافة Runtime Permission.
- Native plugins أو Native binaries.
- تغيير Flutter Engine / Flutter version.
- إضافة أو حذف Assets مثل الصور والخطوط.

Shorebird يفحص تغييرات Native وAssets قبل إنشاء الـpatch. لا تستخدم --allow-native-diffs أو --allow-asset-diffs كحل اعتيادي.

## الإصدار الأساسي

الإصدار الحالي للمشروع:

- Flutter: 3.32.8
- Dart: 3.8.1
- Android applicationId: app.vsp.sports
- Version: 1.0.0+1

الإصدار الأساسي يجب أن يبنى باستخدام:

    shorebird release android

ثم يتم رفع الـAAB الناتج إلى Google Play.

## OTA Patch

بعد وجود Base Release على الأجهزة:

    shorebird patch android --release-version=1.0.0+1

للاختبار:

    shorebird patch android --release-version=1.0.0+1 --track=staging

ثم بعد الاختبار يتم نشره على stable.

## GitHub Actions

يوجد Workflowان:

- .github/workflows/shorebird-release.yml
- .github/workflows/shorebird-patch.yml

كلاهما يحتاج GitHub Actions secret باسم:

    SHOREBIRD_TOKEN

يجب إنشاء الـAPI key من Shorebird Console وحفظه فقط في GitHub Secrets.

## ملاحظة مهمة

Shorebird لا يعمل في Debug/Profile. اختبار OTA يجب أن يكون على Release build مبني بواسطة Shorebird.

التطبيق يتحقق من وجود Patch عند التشغيل، ينزله في الخلفية، ويطبقه عند التشغيل التالي افتراضيًا.

## السياسة التشغيلية لـVSP

Dart/Flutter change:
    -> Shorebird Patch

Supabase Edge Function change:
    -> Supabase Deploy

Native/Asset/Flutter Engine change:
    -> Shorebird Full Release -> Google Play

لا يتم استخدام Google Play لإصلاحات Dart/Flutter العادية.

## أول تهيئة محلية

بعد تثبيت Shorebird وتسجيل الدخول:

    shorebird login

من جذر المشروع:

    shorebird init

هذا ينشئ shorebird.yaml ويحتوي app_id الخاص بـVSP. app_id ليس Secret ويمكن إضافته إلى Git.

بعد إنشاء shorebird.yaml يجب عمل commit له.

## التحقق قبل أول Release

    shorebird doctor
    shorebird releases list

ثم:

    shorebird release android --flutter-version=3.32.8

ولا يتم نشر أي Patch قبل وجود Release أساسي ناجح.

## Rollback

إذا ظهر Bug في Patch منشور، استخدم Rollback من Shorebird Console أو CLI بدل إجبار المستخدمين على تنزيل Full Release.
