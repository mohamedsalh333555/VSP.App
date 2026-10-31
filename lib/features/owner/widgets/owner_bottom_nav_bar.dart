import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/vsp_bottom_nav_bar.dart';
import '../../../core/repositories/chat_repository.dart';
import '../../../core/providers/auth_provider.dart';

class OwnerBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const OwnerBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<OwnerBottomNavBar> createState() => _OwnerBottomNavBarState();
}

class _OwnerBottomNavBarState extends State<OwnerBottomNavBar> {
  Stream<int>? _unreadStream;
  String? _lastUserId;

  Stream<int> _getUnreadStream(String userId) {
    if (_unreadStream != null && _lastUserId == userId) {
      return _unreadStream!;
    }
    _lastUserId = userId;
    _unreadStream = ChatRepository().streamTotalUnreadCount(userId);
    return _unreadStream!;
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().currentUser?.id ?? '';

    return StreamBuilder<int>(
      key: ValueKey(userId),
      stream: _getUnreadStream(userId),
      builder: (context, snapshot) {
        final hasUnread = (snapshot.data ?? 0) > 0;
        return VspBottomNavBar(
          selectedIndex: widget.currentIndex,
          onItemTapped: widget.onTap,
          items: [
            VspNavItem(
              inactiveIcon: Iconsax.element_4,
            activeIcon: Iconsax.element_4_copy,
              label: AppLocalizations.of(context)!.home,
            ),
            VspNavItem(
              inactiveIcon: Iconsax.cup,
            activeIcon: Iconsax.cup_copy,
              label: AppLocalizations.of(context)!.tournamentsTab,
            ),
            VspNavItem(
              inactiveIcon: Iconsax.messages_3,
            activeIcon: Iconsax.messages_3_copy,
              label: AppLocalizations.of(context)!.chat,
              hasNotification: hasUnread, // النقطة الحمراء
            ),
            VspNavItem(
              inactiveIcon: Iconsax.calendar_1,
            activeIcon: Iconsax.calendar_1_copy,
              label: AppLocalizations.of(context)!.bookedTab,
            ),
            VspNavItem(
              inactiveIcon: Iconsax.user,
            activeIcon: Iconsax.user_copy,
              label: AppLocalizations.of(context)!.profileTab,
            ),
          ],
        );
      },
    );
  }
}
