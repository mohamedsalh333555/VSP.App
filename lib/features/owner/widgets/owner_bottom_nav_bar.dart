import 'package:lucide_icons_flutter/lucide_icons.dart';
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
          activeIcon: LucideIcons.layoutDashboard,
          inactiveIcon: LucideIcons.layoutDashboard,
          label: AppLocalizations.of(context)!.home,
        ),
        VspNavItem(
          activeIcon: LucideIcons.trophy,
          inactiveIcon: LucideIcons.trophy,
          label: AppLocalizations.of(context)!.tournamentsTab,
        ),
        VspNavItem(
          activeIcon: LucideIcons.messageSquare,
          inactiveIcon: LucideIcons.messageSquare,
          label: AppLocalizations.of(context)!.chat,
        ),
        VspNavItem(
          activeIcon: LucideIcons.calendar,
          inactiveIcon: LucideIcons.calendar,
          label: AppLocalizations.of(context)!.bookedTab,
        ),
        VspNavItem(
          activeIcon: LucideIcons.user,
          inactiveIcon: LucideIcons.user,
          label: AppLocalizations.of(context)!.profileTab,
        ),
      ],
    );
  }
}




