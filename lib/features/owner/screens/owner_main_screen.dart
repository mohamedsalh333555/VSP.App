import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'owner_dashboard_screen.dart';
import 'owner_stadiums_screen.dart';
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

  final List<Widget> _screens = [
    const OwnerDashboardScreen(),
    const OwnerCupScreen(),
    const OwnerBookedScreen(), // Replaced Stadiums
    const OwnerProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: _screens[_currentIndex],

      // FAB positioned above Nav Bar (Scaffold usually handles this well with endFloat, but we might need padding if the nav bar is transparent/custom height)
      floatingActionButton: _currentIndex == 1 // Only for Cup Tab
          ? Padding(
              padding: const EdgeInsets.only(bottom: 20.0), // Extra padding to be safe above Nav Bar
              child: SizedBox(
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
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      bottomNavigationBar: SafeArea(
        top: false, // Ensure we don't push down significantly, just safe area bottom
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_filled, 'Home'),
              _buildNavItem(1, Icons.emoji_events_outlined, 'Cup'),
              _buildNavItem(2, Icons.work_outline, 'Booked'),
              _buildNavItem(3, Icons.person_outline, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        height: 60,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
             // Glow Dot - Centered top
            if (isSelected)
              Positioned(
                top: 8, 
                child: Container(
                  width: 5, 
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppTheme.neonGreen,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.neonGreen,
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            
            // Column for Icon + Text
            Positioned(
              top: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: isSelected ? AppTheme.neonGreen : Colors.grey[500],
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? AppTheme.neonGreen : Colors.grey[500],
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
