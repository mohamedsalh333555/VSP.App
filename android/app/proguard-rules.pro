# ─── Flutter ───────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# ─── Supabase / Realtime ───────────────────────────────────────────────────────
-keep class io.supabase.** { *; }
-keep class com.supabase.** { *; }
-dontwarn io.supabase.**

# ─── OkHttp / Retrofit (used internally by Supabase) ──────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# ─── Firebase / Google Services ───────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ─── Google Mobile Ads ────────────────────────────────────────────────────────
-keep class com.google.android.gms.ads.** { *; }

# ─── WebView / Chromium (for Paymob WebView) ──────────────────────────────────
-keep class android.webkit.** { *; }
-keep class com.android.webview.** { *; }
-dontwarn com.android.webview.**

# ─── Kotlin Coroutines ────────────────────────────────────────────────────────
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# ─── JSON / Serialization ─────────────────────────────────────────────────────
-keep class org.json.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# ─── Safe Device (Jailbreak/Mock Location Detection) ─────────────────────────
-keep class com.aheaditec.frida_detector.** { *; }
-dontwarn com.aheaditec.**

# ─── Geolocator ───────────────────────────────────────────────────────────────
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# ─── Shared Preferences ───────────────────────────────────────────────────────
-keep class androidx.preference.** { *; }

# ─── General Android ──────────────────────────────────────────────────────────
-keepattributes SourceFile,LineNumberTable
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
