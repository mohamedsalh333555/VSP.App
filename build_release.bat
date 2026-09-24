@echo off
chcp 65001 >nul
title VSP Release APK Builder

echo ========================================================
echo        VSP Application - Release APK Build
echo ========================================================
echo.

if not exist "%~dp0env.json" (
    echo [ERROR] env.json غير موجود في المسار الرئيسي.
    echo انسخ env.json.example إلى env.json واملأ القيم.
    pause
    exit /b 1
)

echo [1/3] التحقق من إعدادات Build...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$j=Get-Content '%~dp0env.json' -Raw | ConvertFrom-Json; $required='SUPABASE_URL','SUPABASE_ANON_KEY','PAYMOB_PUBLIC_KEY','GOOGLE_WEB_CLIENT_ID','GOOGLE_IOS_CLIENT_ID'; $missing=@($required | ? { -not $_ -or -not $j.$_ -or $j.$_ -match '^your-.*-here$' }); if($missing.Count){ Write-Host '[ERROR] قيم Build ناقصة:' ($missing -join ', '); exit 1 }"

if %ERRORLEVEL% neq 0 (
    pause
    exit /b 1
)

echo [2/3] جارٍ جلب الحزم...
call flutter pub get
if %ERRORLEVEL% neq 0 (
    echo [ERROR] flutter pub get فشل.
    pause
    exit /b 1
)

echo [3/3] جارٍ بناء Release APK بالإعدادات الموحدة...
call flutter build apk --release --dart-define-from-file=env.json

if %ERRORLEVEL% equ 0 (
    echo.
    echo ========================================================
    echo  تم بناء Release APK بنجاح.
    echo  buildappoutputslutter-apk    echo ========================================================
    explorer "%~dp0buildappoutputslutter-apk"
) else (
    echo.
    echo فشل البناء. راجع الخطأ بالأعلى.
)

pause
