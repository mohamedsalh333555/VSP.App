@echo off
chcp 65001 >nul
title VSP Release APK Builder

echo ========================================================
echo        🚀 VSP Application - Release APK Build
echo ========================================================
echo.

if not exist "%~dp0env.json" (
    echo [ERROR] ملف env.json غير موجود في المسار الرئيسي!
    echo يرجى نسخ env.json.example إلى env.json وملء المتغيرات.
    echo.
    pause
    exit /b 1
)

echo [1/2] جارٍ التحقق من بيئة Flutter وجلب الحزم...
call flutter pub get

echo.
echo [2/2] جارٍ بناء ملف الـ Release APK باستخدام env.json...
call flutter build apk --release --dart-define-from-file=env.json

if %ERRORLEVEL% equ 0 (
    echo.
    echo ========================================================
    echo  ✅ تم بناء الـ Release APK بنجاح!
    echo  📁 المسار: build\app\outputs\flutter-apk\
    echo ========================================================
    echo.
    explorer "%~dp0build\app\outputs\flutter-apk"
) else (
    echo.
    echo ❌ فشل البناء! يرجى مراجعة الأخطاء بالأعلى.
)

pause
