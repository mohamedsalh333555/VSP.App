import 'package:flutter/material.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/vsp_animated_button.dart';
import '../../../shared/widgets/vsp_empty_state.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';
import '../../../data/models.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/database_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class NotificationsCenterScreen extends StatelessWidget {
  const NotificationsCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: VSPColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Notifications',
          style: Theme.of(context).textTheme.displaySmall,
        ),
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: DatabaseService().getUserNotifications(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return VSPEmptyState(
              icon: Icons.notifications_off_outlined,
              title: 'No Notifications Yet',
              subtitle: 'We will notify you about your matches and challenges.',
              buttonText: 'Back to Dashboard',
              onButtonPressed: () => Navigator.pop(context),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.fromLTRB(VSPSpacing.md, VSPSpacing.md, VSPSpacing.md, MediaQuery.of(context).padding.bottom + 24),
            physics: const BouncingScrollPhysics(),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return VSPFadeInItem(
                index: index,
                child: _NotificationCard(notification: notification),
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;

  const _NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: VSPSpacing.sm),
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: notification.isRead ? VSPColors.surface : VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(
          color: notification.isRead ? Colors.transparent : VSPColors.accent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getIconColor(notification.type).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getIcon(notification.type),
              color: _getIconColor(notification.type),
              size: 20,
            ),
          ),
          const SizedBox(width: VSPSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      notification.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      _formatTime(notification.createdAt),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: VSPSpacing.xs),
                Text(
                  notification.body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary.withValues(alpha: 0.8)),
                ),

                // BETA READY: Interactive actions for challenges
                if (notification.type == 'challenge' && !notification.isRead && notification.bookingId != null) ...[
                  const SizedBox(height: VSPSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: VSPAnimatedButton(
                          text: 'Accept',
                          height: 44,
                          onPressed: () => DatabaseService().respondToChallenge(
                            notification.id, 
                            notification.bookingId!, 
                            true
                          ),
                        ),
                      ),
                      const SizedBox(width: VSPSpacing.sm),
                      Expanded(
                        child: VSPAnimatedButton(
                          text: 'Decline',
                          height: 44,
                          color: VSPColors.surfaceAlt,
                          textColor: VSPColors.textSecondary,
                          onPressed: () => DatabaseService().respondToChallenge(
                            notification.id, 
                            notification.bookingId!, 
                            false
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'challenge':
        return Icons.sports_soccer;
      case 'result_confirmation':
        return Icons.emoji_events_outlined;
      case 'info':
      default:
        return Icons.info_outline;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'challenge':
        return VSPColors.accent;
      case 'result_confirmation':
        return VSPColors.accent;
      case 'info':
      default:
        return Colors.blue;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d').format(dt);
  }
}
