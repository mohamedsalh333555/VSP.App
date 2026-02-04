import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shimmer_image.dart';
import 'owner_profile_screen.dart';
import 'owner_booked_screen.dart';
import 'owner_cup_screen.dart';

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,

      body: Stack(
        children: [
          // Content
          _buildBody(),
          
          // Bottom Navigation (Positioned at bottom)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomNavBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return const OwnerCupScreen();
      case 2:
         return const OwnerBookedScreen();
      case 3:
        return const OwnerProfileScreen();
      default:
        return _buildHomeContent();
    }
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 60, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildFilters(),
          const SizedBox(height: 24),
          _buildStatsGrid(),
          const SizedBox(height: 32),
          const Text(
            'Booked Today',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildBookedList(),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Show more',
              style: TextStyle(
                color: AppTheme.textSecondary.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }


  // --- Header ---
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hi Sal Acd',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You have 3 stadium',
              style: TextStyle(
                color: AppTheme.textSecondary.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.notifications_none,
            color: AppTheme.neonGreen,
            size: 28,
          ),
        ),
      ],
    );
  }

  // --- Filters ---
  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: transparentDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                 Text('All Stadium', style: TextStyle(color: Colors.white)),
                 Icon(Icons.keyboard_arrow_down, color: Colors.white),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: transparentDark,
              borderRadius: BorderRadius.circular(12),
               border: Border.all(color: Colors.grey[800]!),
            ),
            child: Row(
              children: const [
                 Icon(Icons.calendar_today, size: 16, color: Colors.white),
                 SizedBox(width: 8),
                 Text('Last 30 days', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Stats Grid ---
  Widget _buildStatsGrid() {
    return Column(
      children: [
        // Revenue Card (Full Width)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: transparentDark,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                 padding: const EdgeInsets.all(10),
                 decoration: BoxDecoration(
                   color: Colors.grey[800],
                   shape: BoxShape.circle,
                 ),
                 child: const Icon(Icons.attach_money, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Revenue', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    Row(
                      children: const [
                        Text('369K', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        SizedBox(width: 8),
                         Text('↑ 34%', style: TextStyle(color: AppTheme.neonGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    )
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Details >', style: TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        
        // 2x2 Grid
        Row(
          children: [
            Expanded(child: _buildStatCard('Booked', '110', '↑ 22%', Icons.check_circle_outline)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('Total Time Booked', '2K', '↑ 10%', Icons.access_time)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
             Expanded(
               child: _buildStatCard(
                 'Rate', 
                 null, 
                 null, 
                 Icons.star_border,
                 customContent: Row(
                   children: List.generate(5, (index) => const Icon(Icons.star, color: Colors.amber, size: 16)),
                 )
               )
             ),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('Visitors', '36K', '↑ 9%', Icons.visibility_outlined)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String? value, String? trend, IconData icon, {Widget? customContent}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: transparentDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Icon(icon, color: Colors.white, size: 20),
           const SizedBox(height: 8),
           Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
           const SizedBox(height: 4),
           if (customContent != null)
             customContent
           else
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text(value!, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                 if (trend != null)
                   Text(trend, style: const TextStyle(color: AppTheme.neonGreen, fontSize: 12)),
               ],
             ),
        ],
      ),
    );
  }

  // --- Booked List ---
  Widget _buildBookedList() {
    final bookings = [
      {'time': '1PM', 'name': 'Ahmed Salah', 'role': 'GK', 'img': 'https://images.unsplash.com/photo-1543351611-58f69d7c1781?w=150&h=150&fit=crop&q=80'},
      {'time': '2PM', 'name': 'Mahomed Saleh', 'role': 'Midfielder', 'img': 'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?w=150&h=150&fit=crop&q=80'},
      {'time': '3PM', 'name': 'Mohamed Salah', 'role': 'Forward', 'img': 'https://images.unsplash.com/photo-1551958219-acbc608c6377?w=150&h=150&fit=crop&q=80'},
    ];

    return Column(
      children: bookings.map((booking) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E3A1E), // Dark Greenish tint
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.neonGreen.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            Text(
              booking['time']!,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 16),
            ShimmerImage(
              imageUrl: booking['img']!,
              width: 45,
              height: 45,
              borderRadius: 22.5,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(booking['name']!, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(booking['role']!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(color: AppTheme.neonGreen),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit_outlined, color: AppTheme.neonGreen, size: 20),
            ),
          ],
        ),
      )).toList(),
    );
  }

  // --- Bottom Nav ---
  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkBackground.withOpacity(0.95),
         borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
         ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_filled, 'Home', 0),
              _buildNavItem(Icons.emoji_events_outlined, 'Cup', 1),
              _buildNavItem(Icons.calendar_today_outlined, 'Booked', 2),
              _buildNavItem(Icons.person_outline, 'Profile', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? AppTheme.neonGreen : Colors.grey,
            size: 26,
          ),
          const SizedBox(height: 6),
          if (isSelected)
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: AppTheme.neonGreen,
                shape: BoxShape.circle,
              ),
            )
          else 
            Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }
}

// Helper Constant
const Color transparentDark = Color(0xFF2C2C2E);
