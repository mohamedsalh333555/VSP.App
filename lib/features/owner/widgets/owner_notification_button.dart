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
  late Stream<int> _unreadStream;

  @override
  void initState() {
    super.initState();
    _unreadStream = NotificationRepository().getUnreadNotificationCount(widget.userId);
  }

  @override
  void didUpdateWidget(covariant OwnerNotificationButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId && widget.userId.isNotEmpty) {
      setState(() {
        _unreadStream = NotificationRepository()
            .getUnreadNotificationCount(widget.userId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _unreadStream,
      builder: (context, snapshot) {
        final hasUnread = (snapshot.data ?? 0) > 0;
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Iconsax.notification_copy, color: Colors.white),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsCenterScreen()),
                );
              },
            ),
            if (hasUnread)
              PositionedDirectional(
                top: 8,
                end: 8,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.elasticOut,
                  builder: (ctx, val, _) => Transform.scale(
                    scale: val,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: VSPColors.error,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: VSPColors.error.withValues(alpha: 0.6),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
