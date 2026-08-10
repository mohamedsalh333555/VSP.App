import 'package:iconsax_flutter/iconsax_flutter.dart';
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
          activeIcon: Iconsax.element_4,
          inactiveIcon: Iconsax.element_4,
          label: AppLocalizations.of(context)!.home,
        ),
        VspNavItem(
          activeIcon: Iconsax.cup,
          inactiveIcon: Iconsax.cup,
          label: AppLocalizations.of(context)!.tournamentsTab,
        ),
        VspNavItem(
          activeIcon: Iconsax.messages_3,
          inactiveIcon: Iconsax.messages_3,
          label: AppLocalizations.of(context)!.chat,
        ),
        VspNavItem(
          activeIcon: Iconsax.calendar_1,
          inactiveIcon: Iconsax.calendar_1,
          label: AppLocalizations.of(context)!.bookedTab,
        ),
        VspNavItem(
          activeIcon: Iconsax.user,
          inactiveIcon: Iconsax.user,
          label: AppLocalizations.of(context)!.profileTab,
        ),
      ],
    );
  }
}





