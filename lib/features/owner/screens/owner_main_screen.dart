import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../widgets/owner_bottom_nav_bar.dart';
import 'owner_dashboard_screen.dart';
import 'owner_profile_screen.dart';
import 'owner_cup_screen.dart';
import 'owner_bookings_screen.dart';
import 'owner_inbox_screen.dart';

class OwnerMainScreen extends StatefulWidget {
  const OwnerMainScreen({super.key});

  @override
  State<OwnerMainScreen> createState() => _OwnerMainScreenState();
}

class _OwnerMainScreenState extends State<OwnerMainScreen> {
  int _currentIndex = 0;
  late final ConfettiController _confettiController;
  StreamSubscription? _celebrationSubscription;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 5));
    _startCelebrationListener();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _celebrationSubscription?.cancel();
    super.dispose();
  }

  void _startCelebrationListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      _celebrationSubscription = authProvider.celebrationEvents.listen((_) {
        _triggerCelebration();
      });
    });
  }

  void _triggerCelebration() {
    if (!mounted) return;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    _confettiController.play();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VSPRadius.lg),
        ),
        title: Row(
          children: [
            const Icon(Iconsax.verify_copy, color: VSPColors.accent, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isAr ? "تم توثيق الحساب! 🎉" : "Account Verified! 🎉",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        titlePadding: const EdgeInsets.all(VSPSpacing.md),
        content: Text(
          isAr 
              ? "تهانينا! تم توثيق حسابك بنجاح، وملاعبك أصبحت الآن معروضة ومتاحة لجميع اللاعبين!" 
              : "Your account has been verified! 🎉 Your stadiums are now live and visible to all players!",
          style: const TextStyle(color: VSPColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _confettiController.stop();
              Navigator.of(ctx).pop();
            },
            child: Text(isAr ? 'رائع!' : 'Great!', style: const TextStyle(color: VSPColors.accent)),
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: VSPColors.background,
      body: Stack(
        alignment: Alignment.center,
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              const OwnerDashboardScreen(),
              const OwnerCupScreen(),
              const OwnerInboxScreen(), // New Chat tab
              const OwnerBookingsScreen(),
              const OwnerProfileScreen(),
            ],
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                VSPColors.accent,
                Colors.yellow,
                Colors.white,
                Colors.blue,
              ],
            ),
          ),
        ],
      ),


      bottomNavigationBar: OwnerBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
