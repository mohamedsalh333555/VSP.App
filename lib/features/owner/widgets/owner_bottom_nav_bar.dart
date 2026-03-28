import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../../shared/widgets/vsp_bottom_nav_bar.dart';

class OwnerBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const OwnerBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return VspBottomNavBar(
      selectedIndex: currentIndex,
      onItemTapped: onTap,
      items: [
        VspNavItem(
          activeIcon: Icons.home_filled,
          inactiveIcon: Icons.home_outlined,
          label: 'Home',
        ),
        VspNavItem(
          activeIcon: Icons.emoji_events,
          inactiveIcon: Icons.emoji_events_outlined,
          label: 'Tournaments',
        ),
        VspNavItem(
          activeIcon: Icons.work,
          inactiveIcon: Icons.work_outline,
          label: 'Booked',
        ),
        VspNavItem(
          activeIcon: Icons.person,
          inactiveIcon: Icons.person_outline,
          label: 'Profile',
        ),
      ],
    );
  }
}
