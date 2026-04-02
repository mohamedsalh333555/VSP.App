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
          activeIcon: Icons.dashboard,
          inactiveIcon: Icons.dashboard_outlined,
          label: AppLocalizations.of(context)!.home,
        ),
        VspNavItem(
          activeIcon: Icons.emoji_events,
          inactiveIcon: Icons.emoji_events_outlined,
          label: AppLocalizations.of(context)!.tournamentsTab,
        ),
        VspNavItem(
          activeIcon: Icons.calendar_today,
          inactiveIcon: Icons.calendar_today_outlined,
          label: AppLocalizations.of(context)!.bookedTab,
        ),
        VspNavItem(
          activeIcon: Icons.person,
          inactiveIcon: Icons.person_outline,
          label: AppLocalizations.of(context)!.profileTab,
        ),
      ],
    );
  }
}
