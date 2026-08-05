import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
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
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/navigation/app_router.dart';
import 'dart:async';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // SUPABASE & FIREBASE PARALLEL INITIALIZATION
  try {
    const supabaseUrl = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://mktqkddbcddrxjxabdua.supabase.co',
    );
    const supabaseAnonKey = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE',
    );

    await Future.wait([
      Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      ).then((_) => VSPLogger.i("✅ Supabase initialized successfully")),
      Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).then((_) => VSPLogger.i("✅ Firebase initialized successfully")),
    ]);
  } catch (e) {
    VSPLogger.e("⚠️ Backend initialization notice: $e");
  }
  
  // System UI Style
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  // Custom Error Boundary
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(VSPSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.alertCircle, size: 80, color: VSPColors.error),
              const SizedBox(height: VSPSpacing.xl),
              const Text(
                'Something went wrong! 🎮',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
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
      VSPLogger.w("⚠️ Warning: Notification service failed to initialize: $e");
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

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    _router = AppRouter.createRouter(authProvider, navigatorKey);
    _initDeepLinks();

    // Listen to Supabase Auth State changes for Password Recovery
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        debugPrint('🔑 Password recovery event triggered! Routing to /set-new-password');
        _router.go('/set-new-password');
      }
    });
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
    debugPrint('🔗 Handling deep link: $uri');
    final auth = Provider.of<app_auth.AuthProvider>(context, listen: false);

    // ✅ CRITICAL: Supabase OAuth callbacks (login-callback) MUST be forwarded
    // directly to Supabase — never blocked or saved as "pending". Supabase's own
    // internal listener (SupabaseAuth._handleIncomingLinks) handles these.
    final isOAuthCallback = uri.scheme == 'io.supabase.fluttervsp' &&
        uri.host == 'login-callback';
    if (isOAuthCallback) {
      debugPrint('🔐 OAuth callback detected — forwarding to Supabase auth handler.');
      // Supabase SDK handles this automatically via its own stream listener.
      // We must NOT intercept or block it here.
      return;
    }

    // 🛡️ AUTH GUARD: For app-level deep links (e.g. /match/ID), require auth.
    if (!auth.isAuthenticated || auth.userModel?.isRegistrationComplete != true) {
      debugPrint('💾 Saving pending deep link for after login: $uri');
      SharedPreferences.getInstance().then((prefs) => prefs.setString('pending_deep_link', uri.toString()));
      return;
    }

    try {
      String? type;
      String? id;

      if (uri.scheme == 'io.supabase.fluttervsp') {
        type = uri.host;
        if (uri.pathSegments.isNotEmpty) {
          id = uri.pathSegments.first;
        }
      } else {
        if (uri.pathSegments.length >= 2) {
          type = uri.pathSegments[0]; // match or team
          id = uri.pathSegments[1];
        }
      }

      if (type != null && id != null && id.isNotEmpty) {
        // Validate ID format (alphanumeric, dashes, underscores) to prevent path injection or invalid characters
        final bool isValidId = RegExp(r'^[a-zA-Z0-9\-_\s]+$').hasMatch(id);
        if (!isValidId) {
          debugPrint('⚠️ Malicious or garbage ID detected in deep link: $id. Redirecting to safe fallback.');
          _router.go('/');
          return;
        }

        if (type == 'match') {
          _router.push('/match/$id');
        } else if (type == 'team') {
          _router.push('/team/$id');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('🚨 Error processing deep link: $e\n$stackTrace');
      _router.go('/'); // Safe fallback on error
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
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
