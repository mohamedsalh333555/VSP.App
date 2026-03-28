import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'firebase_options.dart';
import 'core/ui/tokens/vsp_tokens.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/language_provider.dart';
import 'core/providers/auth_provider.dart' as app_auth;
import 'core/providers/stadium_provider.dart';
import 'core/providers/booking_provider.dart';
import 'core/services/notification_service.dart';
import 'core/utils/data_migration.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/welcome_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'core/navigation/root_screen.dart';
import 'core/config/app_config.dart' as app_config;
import 'core/services/logger_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // FIREBASE INITIALIZATION
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // RE-ENABLE PERSISTENCE FOR PRODUCTION
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );

    // CRASHLYTICS INITIALIZATION
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };
    // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    
    VSPLogger.i("✅ Firebase initialized with Crashlytics");
    
    // DATA MIGRATIONS & REPAIR
    // We always run repair to ensure stadium visibility for legacy data.
    // seedDatabase handles the full initial demo set if demoMode is active.
    if (app_config.AppConfig.demoMode) {
      await DataMigration().seedDatabase(); 
    } else {
      // ⚠️ DISABLED FOR PRODUCTION LAUNCH: Heavy DB scan on every startup.
      // Run this ONCE via a Cloud Function or admin panel instead.
      // await DataMigration().repairStadiumsData();
    }
  } catch (e) {
    VSPLogger.e("❌ FIREBASE INIT FAILED", e);
  }
  
  // Initialize Notifications
  try {
    await NotificationService().initialize(navigatorKey);
  } catch (e) {
    VSPLogger.w("⚠️ Warning: Notification service failed: $e");
  }
  
  // System UI Style
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  // TODO(iOS/Android): Implement Deep Linking (uni_links / firebase_dynamic_links).
  // This will handle social sharing intercepts and route the RootScreen directly to the shared Stadium/Team.

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
              const Icon(Icons.error_outline_rounded, size: 80, color: VSPColors.error),
              const SizedBox(height: VSPSpacing.xl),
              Text(
                'Something went wrong! 🎮',
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
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
                onPressed: () => navigatorKey.currentState?.pushReplacementNamed('/root'),
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
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
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
            home: const RootScreen(), // RootScreen manages splash/auth/home gating
            routes: {
              '/splash': (context) => const SplashScreen(),
              '/welcome': (context) => const WelcomeScreen(),
              '/root': (context) => const RootScreen(),
            },
          );
        },
      ),
    );
  }
}
