import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'features/owner/screens/owner_main_screen.dart';
import 'features/player/screens/player_home_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // FIREBASE INITIALIZATION
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("✅✅✅ FIREBASE INITIALIZED SUCCESSFULLY ✅✅✅");
    
    // ONE-TIME DATABASE SEEDING
    try {
        await DataMigration().seedDatabase();
        debugPrint("✅ Database seeding attempt complete");
    } catch (e) {
        debugPrint("⚠️ Database seeding failed: $e");
    }
  } catch (e) {
    debugPrint("❌❌❌ FIREBASE INIT FAILED: $e");
  }
  
  // Initialize Notifications
  try {
    await NotificationService().initialize();
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
            initialRoute: '/splash',
            routes: {
              '/splash': (context) => const SplashScreen(),
              '/auth': (context) => const AuthWrapper(),
              '/welcome': (context) => const WelcomeScreen(),
            },
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. Waiting for Auth State
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppTheme.darkBackground,
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.neonGreen),
            ),
          );
        }

        // 2. User is Logged In
        if (snapshot.hasData && snapshot.data != null) {
          return _RoleCheck(uid: snapshot.data!.uid);
        }

        // 3. User is Logged Out
        return const WelcomeScreen();
      },
    );
  }
}

class _RoleCheck extends StatefulWidget {
  final String uid;
  const _RoleCheck({required this.uid});

  @override
  State<_RoleCheck> createState() => _RoleCheckState();
}

class _RoleCheckState extends State<_RoleCheck> {
  @override
  void initState() {
    super.initState();
    _navigateBasedOnRole();
  }

  Future<void> _navigateBasedOnRole() async {
    try {
      // Get fresh user document
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
      
      if (!mounted) return;

      if (doc.exists) {
        final role = doc.data()?['role'] ?? 'player';
        // Note: We are replacing the entire navigation stack here
        // We use a micro-delay to ensure build context is ready if needed, usually safe in initState async
        if (role == 'owner') {
             Navigator.of(context).pushReplacement(
                 MaterialPageRoute(builder: (_) => const OwnerMainScreen())
             );
        } else {
             Navigator.of(context).pushReplacement(
                 MaterialPageRoute(builder: (_) => const PlayerHomeScreen())
             );
        }
      } else {
        // Fallback if no user doc (shouldn't happen in live system but safe in dev)
        // Assume Player or go to setup? Let's go to Player Home as safe default
        Navigator.of(context).pushReplacement(
             MaterialPageRoute(builder: (_) => const PlayerHomeScreen())
         );
      }
    } catch (e) {
      debugPrint("Auth Navigation Error: $e");
      if (mounted) {
        Navigator.of(context).pushReplacement(
             MaterialPageRoute(builder: (_) => const WelcomeScreen())
         );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Center(
        child: CircularProgressIndicator(color: AppTheme.neonGreen),
      ),
    );
  }
}
