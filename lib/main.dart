import 'dart:ui';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/ui/tokens/vsp_tokens.dart';
import 'core/utils/device_performance.dart';
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

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: Scaffold(
        backgroundColor: VSPColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(VSPSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Iconsax.warning_2_copy, size: 72, color: VSPColors.error),
                const SizedBox(height: VSPSpacing.lg),
                const Text('VSP cannot connect to its backend.',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
                const SizedBox(height: VSPSpacing.sm),
                Text('Please check your connection and try again.\\n$message',
                  style: const TextStyle(color: VSPColors.textSecondary),
                  textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  VSPLogger.i('Handling a background FCM message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DevicePerformance.init();
  usePathUrlStrategy();
 
  try {
    await Supabase.initialize(
      url: AppEnv.supabaseUrl,
      publishableKey: AppEnv.supabaseAnonKey,
    ).timeout(const Duration(seconds: 8));
    VSPLogger.i("Supabase initialized securely");
    unawaited(VSPTimeService.syncWithServer());
  } catch (e, stack) {
    VSPLogger.e("Supabase initialization failed: $e", e, stack);
    runApp(_StartupFailureApp(message: e.toString()));
    return;
  }

  // Firebase is auxiliary only (FCM, Analytics, Crashlytics).
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 8));
    VSPLogger.i("Firebase initialized successfully");
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (e) {
      VSPLogger.w("Firebase Messaging handler notice: $e");
    }
  } catch (e) {
    VSPLogger.w("Firebase auxiliary initialization notice: $e");
  }
  
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
 return Scaffold(
 backgroundColor: VSPColors.background,
 body: Center(
 child: Padding(
 padding: const EdgeInsets.all(VSPSpacing.xl),
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 const Icon(Iconsax.warning_2_copy, size: 80, color: VSPColors.error),
 const SizedBox(height: VSPSpacing.xl),
 const Text(
 'Something went wrong! ',
 style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
 textAlign: TextAlign.center,
 ),
 Text(
 details.exceptionAsString(),
 textAlign: TextAlign.center,
 style: const TextStyle(color: VSPColors.error, fontSize: 13, fontFamily: 'monospace'),
 ),
 const SizedBox(height: VSPSpacing.md),
 const Text(
 'We encountered an unexpected error. Our team has been notified and we are working on it.',
 textAlign: TextAlign.center,
 style: TextStyle(color: VSPColors.textSecondary),
 ),
 const SizedBox(height: VSPSpacing.xl),
 ElevatedButton(
 onPressed: () {
 final ctx = navigatorKey.currentContext;
 if (ctx != null) {
 ctx.go('/');
 }
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: VSPColors.accent,
 foregroundColor: Colors.black,
 padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
 ),
 child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
 ),
 ],
 ),
 ),
 ),
 );
 };

 runApp(const VSPApplication());

 // Background non-critical services (Notifications & Crashlytics)
 unawaited(
 NotificationService().initialize(navigatorKey).catchError((e) {
 VSPLogger.w(" Warning: Notification service failed to initialize: $e");
 }),
 );
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
