import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/owner_bottom_nav_bar.dart';
import 'owner_dashboard_screen.dart';
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
      backgroundColor: const Color(0xFF121212),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          OwnerDashboardScreen(),
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
                backgroundColor: AppTheme.neonGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                label: const Text(
                  'Create a tournament',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
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
