import 'dart:ui';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/ui/tokens/vsp_tokens.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/language_provider.dart';
import 'core/providers/auth_provider.dart' as app_auth;
import 'core/providers/stadium_provider.dart';
import 'core/providers/booking_provider.dart';
import 'core/services/notification_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'core/services/logger_service.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/services/vsp_time_service.dart';
import 'core/navigation/app_router.dart';
import 'dart:async';

import 'package:flutter_web_plugins/url_strategy.dart';
import 'core/config/app_env.dart';
import 'core/utils/deep_link_helper.dart';
import 'core/services/secure_storage_service.dart';
import 'core/services/remote_config_service.dart';
import 'shared/widgets/vsp_network_banner.dart';

import 'package:flutter/foundation.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  VSPLogger.i('Handling a background FCM message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  bool supabaseInitialized = false;

  // CONCURRENT INITIALIZATION (Supabase & Firebase)
  await Future.wait([
    (() async {
      try {
        await Supabase.initialize(
          url: AppEnv.supabaseUrl,
          publishableKey: AppEnv.supabaseAnonKey,
        ).timeout(const Duration(seconds: 8));
        VSPLogger.i("Supabase initialized securely");
        supabaseInitialized = true;
        unawaited(VSPTimeService.syncWithServer());
      } catch (e) {
        VSPLogger.e("Supabase initialization error: $e");
        supabaseInitialized = false;
      }
    })(),
    (() async {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: 8));
        VSPLogger.i("Firebase initialized successfully");
        try {
          FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
        } catch (e) {
          VSPLogger.w("Firebase Messaging background handler notice: $e");
        }
      } catch (e) {
        VSPLogger.w("Firebase initialization notice: $e");
      }
    })(),
  ]);

  // Initialize Remote Config & App Feature Engine
  final configService = RemoteConfigService();
  await configService.initialize();

  // System UI Style
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  // Global Crash Boundary & Logging Handlers
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    final isFontError = details.exception.toString().contains('loadFont') ||
        details.exception.toString().contains('GoogleFonts');
    if (isFontError) {
      VSPLogger.w('Font loader non-fatal notice: ${details.exception}');
      try {
        FirebaseCrashlytics.instance.recordFlutterError(details, fatal: false);
      } catch (_) {}
      return;
    }
    VSPLogger.e('Uncaught Flutter Error: ${details.exception}', details.exception, details.stack);
    try {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    } catch (_) {}
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    VSPLogger.e('Uncaught Platform Error: $error', error, stack);
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {}
    return true;
  };

  // Custom Error Boundary Widget
  ErrorWidget.builder = (FlutterErrorDetails details) {
    final isArabic = (PlatformDispatcher.instance.locale.languageCode == 'ar');
    return Scaffold(
      backgroundColor: VSPColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(VSPSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(VSPSpacing.lg),
                  decoration: BoxDecoration(
                    color: VSPColors.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Iconsax.warning_2_copy, size: 56, color: VSPColors.error),
                ),
                const SizedBox(height: VSPSpacing.xl),
                Text(
                  isArabic ? 'حدث خطأ غير متوقع' : 'Something went wrong',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: VSPSpacing.sm),
                Text(
                  isArabic
                      ? 'تم تسجيل المشكلة وسيعمل فريقنا على معالجتها. يمكنك محاولة العودة للرئيسية.'
                      : 'An unexpected error occurred. Our team has been notified.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 14),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: VSPSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(VSPSpacing.sm),
                    decoration: BoxDecoration(
                      color: VSPColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: SingleChildScrollView(
                      child: Text(
                        details.exceptionAsString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: VSPColors.error,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: VSPSpacing.xl),
                ElevatedButton(
                  onPressed: () {
                    final ctx = navigatorKey.currentContext;
                    if (ctx != null) {
                      try {
                        ctx.go('/');
                      } catch (_) {}
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VSPColors.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isArabic ? 'العودة للرئيسية' : 'Return Home',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  if (!supabaseInitialized) {
    runApp(const VSPBootstrapFailureApp());
    return;
  }

  runApp(const VSPApplication());

  // Background non-critical services (Notifications & Crashlytics)
  unawaited(
    NotificationService().initialize(navigatorKey).catchError((e) {
      VSPLogger.w("⚠️ Warning: Notification service failed to initialize: $e");
    }),
  );
}

/// Fallback application when Supabase fails to initialize on cold start
class VSPBootstrapFailureApp extends StatefulWidget {
  final Object? error;
  const VSPBootstrapFailureApp({super.key, this.error});

  @override
  State<VSPBootstrapFailureApp> createState() => _VSPBootstrapFailureAppState();
}

class _VSPBootstrapFailureAppState extends State<VSPBootstrapFailureApp> {
  bool _isRetrying = false;

  Future<void> _retry() async {
    setState(() {
      _isRetrying = true;
    });

    try {
      await Supabase.initialize(
        url: AppEnv.supabaseUrl,
        publishableKey: AppEnv.supabaseAnonKey,
      ).timeout(const Duration(seconds: 10));

      VSPLogger.i("Supabase re-initialized successfully on retry");
      unawaited(VSPTimeService.syncWithServer());

      if (mounted) {
        runApp(const VSPApplication());
      }
    } catch (e) {
      VSPLogger.e("Supabase retry failed: $e");
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = (PlatformDispatcher.instance.locale.languageCode == 'ar');
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: Scaffold(
        backgroundColor: VSPColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: VSPColors.surface,
                      border: Border.all(
                        color: VSPColors.accent.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Iconsax.wifi_square_copy,
                        size: 40,
                        color: VSPColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isArabic ? 'تعذر الاتصال بالخادم' : 'Server Connection Failed',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isArabic
                        ? 'يرجى التأكد من اتصال الإنترنت ثم المحاولة مرة أخرى'
                        : 'Please check your internet connection and try again',
                    style: const TextStyle(
                      color: VSPColors.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isRetrying ? null : _retry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VSPColors.accent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isRetrying
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.black,
                              ),
                            )
                          : Text(
                              isArabic ? 'إعادة المحاولة' : 'Try Again',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VSPApplication extends StatelessWidget {
 const VSPApplication({super.key});

 @override
 Widget build(BuildContext context) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
      ChangeNotifierProvider(create: (_) => StadiumProvider()),
      ChangeNotifierProvider(create: (_) => BookingProvider()),
      ChangeNotifierProvider.value(value: RemoteConfigService()),
    ],
    child: const _MaterialAppWithRouter(),
  );
 }
}

class _MaterialAppWithRouter extends StatefulWidget {
 const _MaterialAppWithRouter();

 @override
 State<_MaterialAppWithRouter> createState() => _MaterialAppWithRouterState();
}

class _MaterialAppWithRouterState extends State<_MaterialAppWithRouter> {
 late final GoRouter _router;
 late final AppLinks _appLinks;
 StreamSubscription<Uri>? _linkSubscription;
 StreamSubscription<AuthState>? _authSub;

 @override
 void initState() {
 super.initState();
 final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
 _router = AppRouter.createRouter(authProvider, navigatorKey);
 _initDeepLinks();

    // Listen to Supabase Auth State changes for Password Recovery
    try {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.passwordRecovery) {
          debugPrint(' Password recovery event triggered! Routing to /set-new-password');
          _router.go('/set-new-password');
        }
      });
    } catch (e) {
      debugPrint(' Supabase auth listener warning: $e');
    }
 }

 void _initDeepLinks() {
 _appLinks = AppLinks();

 // Check for initial link when app starts
 _appLinks.getInitialLink().then((uri) {
 if (uri != null) _handleDeepLink(uri);
 });

 // Listen to incoming links while app is running
 _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
 _handleDeepLink(uri);
 });
 }

  void _handleDeepLink(Uri uri) {
    debugPrint('⚡ Handling deep link: scheme=${uri.scheme}, host=${uri.host}, path=${uri.path}');
    final auth = Provider.of<app_auth.AuthProvider>(context, listen: false);

 // 1. Supabase OAuth callback bypass
 if (DeepLinkHelper.isOAuthCallback(uri)) {
 debugPrint(' OAuth callback detected — forwarding to Supabase auth handler.');
 final role = uri.queryParameters['role'];
 if (role != null && (role == 'owner' || role == 'player')) {
 auth.setUserType(role);
 SharedPreferences.getInstance().then((prefs) => prefs.setString('pending_oauth_role', role));
 SecureStorageService.writeSecure('pending_oauth_role', role);
 }
 return;
 }

 // 2. Auth Guard: حفظ الرابط لوقت لاحق إن لم يكن مسجلاً
 if (!auth.isAuthenticated || auth.userModel?.isRegistrationComplete != true) {
 debugPrint(' Saving pending deep link for after login: $uri');
 SharedPreferences.getInstance().then((prefs) => prefs.setString('pending_deep_link', uri.toString()));
 return;
 }

 // 3. التحليل والتوجيه الآمن
 final parsed = DeepLinkHelper.parse(uri);
 if (parsed != null) {
 _router.push(parsed.routePath);
 } else {
 debugPrint(' Invalid or unrecognized deep link: $uri');
 _router.go('/');
 }
 }

 @override
 void dispose() {
 _linkSubscription?.cancel();
 _authSub?.cancel();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 final languageProvider = Provider.of<LanguageProvider>(context);
 return MaterialApp.router(
 routerConfig: _router,
 title: 'VSP',
 debugShowCheckedModeBanner: false,
 theme: AppTheme.darkTheme,
 builder: (context, child) => VSPNetworkBanner(child: child ?? const SizedBox()),
 localizationsDelegates: [
 AppLocalizations.delegate,
 GlobalMaterialLocalizations.delegate,
 GlobalWidgetsLocalizations.delegate,
 GlobalCupertinoLocalizations.delegate,
 ],
 supportedLocales: const [
 Locale('en'),
 Locale('ar'),
 ],
 locale: languageProvider.currentLocale,
 );
 }
}
