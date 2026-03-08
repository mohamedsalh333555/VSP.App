import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
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
import 'core/navigation/root_screen.dart';
import 'core/config/app_config.dart' as app_config;

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
    
    debugPrint("✅✅✅ FIREBASE INITIALIZED SUCCESSFULLY ✅✅✅");
    
    // SEEDING (Disabled for production-readiness, enabled only in Demo Mode)
    if (app_config.AppConfig.demoMode) {
      await DataMigration().seedDatabase(); 
    }
  } catch (e) {
    debugPrint("❌❌❌ FIREBASE INIT FAILED: $e");
  }
  
  // Initialize Notifications
  try {
    await NotificationService().initialize(navigatorKey);
  } catch (e) {
    debugPrint("⚠️ Warning: Notification service failed: $e");
  }
  
  // System UI Style
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

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
            localizationsDelegates: const [
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
