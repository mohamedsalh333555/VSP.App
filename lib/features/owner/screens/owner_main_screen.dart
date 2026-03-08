import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../widgets/owner_bottom_nav_bar.dart';
import 'owner_dashboard_tab.dart';
import 'owner_profile_screen.dart';
import 'owner_cup_screen.dart';
import 'create_tournament_screen.dart';
import 'owner_booked_screen.dart';

class OwnerMainScreen extends StatefulWidget {
  const OwnerMainScreen({super.key});

  @override
  State<OwnerMainScreen> createState() => _OwnerMainScreenState();
}

class _OwnerMainScreenState extends State<OwnerMainScreen> {
  int _currentIndex = 0;
  StreamSubscription? _stadiumListener;
  final Map<String, bool> _lastVerifiedStatus = {};

  @override
  void initState() {
    super.initState();
    _startVerificationListener();
  }

  @override
  void dispose() {
    _stadiumListener?.cancel();
    super.dispose();
  }

  void _startVerificationListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _stadiumListener = FirebaseFirestore.instance
        .collection('stadiums')
        .where('ownerId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final String stadiumId = doc.id;
        final String stadiumName = doc['name'] ?? 'Your stadium';
        final bool isVerified = doc['isVerified'] ?? false;

        // Check if status changed from false (or unknown) to true
        if (_lastVerifiedStatus.containsKey(stadiumId)) {
          final bool wasVerified = _lastVerifiedStatus[stadiumId]!;
          if (!wasVerified && isVerified) {
            _showApprovalNotification(stadiumName);
          }
        }
        
        // Update local state for next comparison
        _lastVerifiedStatus[stadiumId] = isVerified;
      }
    });
  }

  void _showApprovalNotification(String name) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.verified, color: Colors.black, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    'Stadium Approved!',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Congratulations! "$name" is now live.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: VSPColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
        margin: const EdgeInsets.fromLTRB(VSPSpacing.md, 0, VSPSpacing.md, VSPSpacing.xl),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.black.withValues(alpha: 0.5),
          onPressed: () {},
        ),
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
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          OwnerDashboardTab(),
          OwnerCupScreen(),
          OwnerBookedScreen(),
          OwnerProfileScreen(),
        ],
      ),

      floatingActionButton: AnimatedScale(
        scale: _currentIndex == 1 ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: _currentIndex == 1 
          ? SizedBox(
              width: 200,
              height: 50,
              child: FloatingActionButton.extended(
                onPressed: () {
                   Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateTournamentScreen()));
                },
                backgroundColor: VSPColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
                label: Text(
                  'Create a tournament',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.black),
                ),
                icon: const Icon(Icons.add, color: Colors.black),
                elevation: 4,
              ),
            )
          : const SizedBox.shrink(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      bottomNavigationBar: OwnerBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
