import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
import 'create_tournament_wizard.dart';
import 'owner_bookings_screen.dart';
import 'owner_inbox_screen.dart';

class OwnerMainScreen extends StatefulWidget {
  const OwnerMainScreen({super.key});

  @override
  State<OwnerMainScreen> createState() => _OwnerMainScreenState();
}

class _OwnerMainScreenState extends State<OwnerMainScreen> {
  int _currentIndex = 0;
  final ValueNotifier<bool> _showTournamentFAB = ValueNotifier<bool>(false);
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
    _confettiController.play();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VSPRadius.lg),
        ),
        title: const Row(
          children: [
            Icon(LucideIcons.badgeCheck, color: VSPColors.accent, size: 28),
            SizedBox(width: 12),
            Text(
              "Account Verified! 🎉",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          "Your account has been verified! 🎉 Your stadiums are now live and visible to all players!",
          style: TextStyle(color: VSPColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _confettiController.stop();
              Navigator.of(ctx).pop();
            },
            child: const Text('Great!', style: TextStyle(color: VSPColors.accent)),
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
    final l10n = AppLocalizations.of(context)!;
    final auth = Provider.of<AuthProvider>(context);
    final isBlocked = auth.userModel?.isBlocked ?? false;
    
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
              OwnerCupScreen(onTournamentListChanged: (isEmpty) {
                _showTournamentFAB.value = !isEmpty;
              }),
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

      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: _showTournamentFAB,
        builder: (context, showTournamentFAB, child) {
          final bool isVisible = _currentIndex == 1 && showTournamentFAB && !isBlocked;
          
          return AnimatedScale(
            scale: isVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: isVisible 
              ? SizedBox(
                  width: 200,
                  height: 50,
                  child: FloatingActionButton.extended(
                    onPressed: () {
                       Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateTournamentWizard()));
                    },
                    backgroundColor: VSPColors.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
                    label: Text(
                      l10n.createTournament,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.black),
                    ),
                    icon: Icon(LucideIcons.plus, color: Colors.black),
                    elevation: 4,
                  ),
                )
              : const SizedBox.shrink(),
          );
        }
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      bottomNavigationBar: OwnerBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
