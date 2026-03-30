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
        BottomNavigationBarItem(
          icon: const Icon(Icons.dashboard_outlined),
          activeIcon: const Icon(Icons.dashboard),
          label: AppLocalizations.of(context)!.home,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.emoji_events_outlined),
          activeIcon: const Icon(Icons.emoji_events),
          label: AppLocalizations.of(context)!.tournamentsTab,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.calendar_today_outlined),
          activeIcon: const Icon(Icons.calendar_today),
          label: AppLocalizations.of(context)!.bookedTab,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.person_outline),
          activeIcon: const Icon(Icons.person),
          label: AppLocalizations.of(context)!.profileTab,
        ),
      ],
    );
  }
}
