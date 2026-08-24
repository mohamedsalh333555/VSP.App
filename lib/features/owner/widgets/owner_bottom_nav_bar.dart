import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/vsp_bottom_nav_bar.dart';
import '../../../core/repositories/chat_repository.dart';
import '../../../core/providers/auth_provider.dart';

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
 final userId = context.read<AuthProvider>().currentUser?.uid ?? '';

 return StreamBuilder<int>(
 stream: ChatRepository().streamTotalUnreadCount(userId),
 builder: (context, snapshot) {
 final hasUnread = (snapshot.data ?? 0) > 0;
 return VspBottomNavBar(
 selectedIndex: currentIndex,
 onItemTapped: onTap,
 items: [
 VspNavItem(
 activeIcon: Iconsax.element_4_copy,
 inactiveIcon: Iconsax.element_4_copy,
 label: AppLocalizations.of(context)!.home,
 ),
 VspNavItem(
 activeIcon: Iconsax.cup_copy,
 inactiveIcon: Iconsax.cup_copy,
 label: AppLocalizations.of(context)!.tournamentsTab,
 ),
 VspNavItem(
 activeIcon: Iconsax.messages_3_copy,
 inactiveIcon: Iconsax.messages_3_copy,
 label: AppLocalizations.of(context)!.chat,
 hasNotification: hasUnread, // النقطة الحمراء
 ),
 VspNavItem(
 activeIcon: Iconsax.calendar_1_copy,
 inactiveIcon: Iconsax.calendar_1_copy,
 label: AppLocalizations.of(context)!.bookedTab,
 ),
 VspNavItem(
 activeIcon: Iconsax.user_copy,
 inactiveIcon: Iconsax.user_copy,
 label: AppLocalizations.of(context)!.profileTab,
 ),
 ],
 );
 },
 );
 }
}
