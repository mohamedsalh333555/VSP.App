import 'package:flutter/material.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
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
      backgroundColor: VSPColors.background,
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
      padding: const EdgeInsets.fromLTRB(VSPSpacing.md, 60, VSPSpacing.md, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: VSPSpacing.lg),
          _buildFilters(),
          const SizedBox(height: VSPSpacing.lg),
          _buildStatsGrid(),
          const SizedBox(height: VSPSpacing.xl),
          Text(
            'Booked Today',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: VSPSpacing.md),
          _buildBookedList(),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Show more',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: VSPColors.textSecondary.withValues(alpha: 0.7),
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
            Text(
              'Hi Sal Acd',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'You have 3 stadium',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: VSPColors.textSecondary.withValues(alpha: 0.8),
                  ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: VSPColors.surfaceAlt,
            borderRadius: BorderRadius.circular(VSPRadius.md),
          ),
          child: const Icon(
            Icons.notifications_none,
            color: VSPColors.accent,
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
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.md),
              border: Border.all(color: VSPColors.divider),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 Text('All Stadium', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textPrimary)),
                 const Icon(Icons.keyboard_arrow_down, color: VSPColors.textPrimary),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.md),
               border: Border.all(color: VSPColors.divider),
            ),
            child: Row(
              children: [
                 const Icon(Icons.calendar_today, size: 16, color: VSPColors.textPrimary),
                 const SizedBox(width: 8),
                 Text('Last 30 days', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textPrimary)),
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
          padding: const EdgeInsets.all(VSPSpacing.md),
          decoration: BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.circular(VSPRadius.lg),
          ),
          child: Row(
            children: [
              Container(
                 padding: const EdgeInsets.all(10),
                 decoration: BoxDecoration(
                   color: VSPColors.background,
                   shape: BoxShape.circle,
                   border: Border.all(color: VSPColors.divider),
                 ),
                 child: const Icon(Icons.attach_money, color: VSPColors.textPrimary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Revenue', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
                    Row(
                      children: [
                        Text('369K', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: VSPColors.textPrimary, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Text('↑ 34%', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.accent, fontWeight: FontWeight.bold)),
                      ],
                    )
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: VSPColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Details >', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textPrimary, fontSize: 10)),
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
                   children: List.generate(5, (index) => const Icon(Icons.star, color: VSPColors.warning, size: 16)),
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
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Icon(icon, color: VSPColors.textPrimary, size: 20),
           const SizedBox(height: 8),
           Text(title, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
           const SizedBox(height: 4),
           if (customContent != null)
             customContent
           else
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text(value!, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: VSPColors.textPrimary, fontWeight: FontWeight.bold)),
                 if (trend != null)
                   Text(trend, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.accent)),
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
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.lg),
          border: Border.all(color: VSPColors.accent.withValues(alpha: 0.2), width: 1),
        ),
        child: Row(
          children: [
            Text(
              booking['time']!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: VSPColors.textPrimary, fontWeight: FontWeight.bold),
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
                  Text(booking['name']!, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: VSPColors.textPrimary, fontWeight: FontWeight.bold)),
                  Text(booking['role']!, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(color: VSPColors.accent),
                borderRadius: BorderRadius.circular(VSPRadius.sm),
              ),
              child: const Icon(Icons.edit_outlined, color: VSPColors.accent, size: 20),
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
        color: VSPColors.background.withValues(alpha: 0.95),
         borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(VSPRadius.xl),
            topRight: Radius.circular(VSPRadius.xl),
         ),
        boxShadow: VSPShadow.subtle,
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
            color: isSelected ? VSPColors.accent : VSPColors.textSecondary,
            size: 26,
          ),
          const SizedBox(height: 6),
          if (isSelected)
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: VSPColors.accent,
                shape: BoxShape.circle,
              ),
            )
          else 
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: VSPColors.textSecondary,
                    fontSize: 10,
                  ),
            ),
        ],
      ),
    );
  }
}
