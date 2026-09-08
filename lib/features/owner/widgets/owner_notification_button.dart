import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/repositories/notification_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../player/screens/notifications_center_screen.dart';

class OwnerNotificationButton extends StatefulWidget {
  final String userId;
  const OwnerNotificationButton({super.key, required this.userId});

  @override
  State<OwnerNotificationButton> createState() => _OwnerNotificationButtonState();
}

class _OwnerNotificationButtonState extends State<OwnerNotificationButton> {
  late final Stream<int> _unreadStream;

  @override
  void initState() {
    super.initState();
    _unreadStream = NotificationRepository().getUnreadNotificationCount(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _unreadStream,
      builder: (context, snapshot) {
        final unread = snapshot.data ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: IconButton(
                icon: const Icon(Iconsax.notification_copy, color: VSPColors.textPrimary, size: 20),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationsCenterScreen()),
                  );
                },
              ),
            ),
            if (unread > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: VSPColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
