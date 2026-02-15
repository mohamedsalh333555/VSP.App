import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/owner/screens/owner_main_screen.dart';
import '../../features/player/screens/player_home_screen.dart';
import '../../core/theme/app_theme.dart';

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // We use watch to rebuild whenever the auth state changes
    final auth = context.watch<AuthProvider>();

    // 1. Show Loading while fetching user data or auth state
    // We consider loading if we have a firebase user but haven't fetched the userModel yet
    // unless the userModel is null and it's intended (logged out)
    if (auth.isLoading || (auth.isAuthenticated && auth.userModel == null)) {
      return const Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.neonGreen),
        ),
      );
    }

    // 2. User is not authenticated
    if (!auth.isAuthenticated) {
      return const WelcomeScreen();
    }

    // 3. Authenticated but somehow userModel is still null (fallback)
    if (auth.userModel == null) {
        return const WelcomeScreen(); 
    }

    // 4. Navigate based on role
    if (auth.isOwner) {
      return const OwnerMainScreen();
    }

    return const PlayerHomeScreen();
  }
}
