import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/vsp_animated_button.dart';
import '../../../shared/widgets/vsp_empty_state.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';
import '../../../data/models.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/notification_repository.dart';
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
          AppLocalizations.of(context)!.notifications,
          style: Theme.of(context).textTheme.displaySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => NotificationRepository().markAllAsRead(userId),
            child: Text(AppLocalizations.of(context)!.markAll, style: const TextStyle(color: VSPColors.accent, fontSize: 13)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: NotificationRepository().getUserNotifications(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return VSPEmptyState(
              icon: Icons.notifications_off_outlined,
              title: AppLocalizations.of(context)!.noNotificationsTitle,
              subtitle: AppLocalizations.of(context)!.noNotificationsSubtitle,
              buttonText: AppLocalizations.of(context)!.backToDashboard,
              onButtonPressed: () => Navigator.pop(context),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.fromLTRB(VSPSpacing.md, VSPSpacing.md, VSPSpacing.md, MediaQuery.of(context).padding.bottom + 24),
            physics: const BouncingScrollPhysics(),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 0),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return VSPFadeInItem(
                index: index,
                child: Dismissible(
                  key: ValueKey(notification.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.only(bottom: VSPSpacing.sm),
                    decoration: BoxDecoration(
                      color: VSPColors.error.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(VSPRadius.lg),
                    ),
                    child: const Icon(Icons.delete_outline, color: VSPColors.error, size: 24),
                  ),
                  onDismissed: (_) {
                    NotificationRepository().deleteNotification(userId, notification.id);
                  },
                  child: _NotificationCard(notification: notification, userId: userId),
                ),
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
  final String userId;

  const _NotificationCard({required this.notification, required this.userId});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: notification.isRead ? null : () => NotificationRepository().markNotificationAsRead(userId, notification.id),
      borderRadius: BorderRadius.circular(VSPRadius.lg),
      child: Container(
        margin: const EdgeInsets.only(bottom: VSPSpacing.sm),
        padding: const EdgeInsets.all(VSPSpacing.md),
        decoration: BoxDecoration(
          color: notification.isRead ? VSPColors.surface.withValues(alpha: 0.5) : VSPColors.surfaceAlt,
          borderRadius: BorderRadius.circular(VSPRadius.lg),
          border: Border.all(
            color: notification.isRead ? VSPColors.divider.withValues(alpha: 0.1) : VSPColors.accent.withValues(alpha: 0.3),
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
                      Flexible(
                        child: Text(
                          notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(context, notification.createdAt),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: VSPSpacing.xs),
                  Text(
                    notification.body,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: notification.isRead ? VSPColors.textSecondary.withValues(alpha: 0.6) : VSPColors.textSecondary,
                    ),
                  ),
  
                  // BETA READY: Interactive actions for challenges
                  if (notification.type == 'challenge' && !notification.isRead && notification.bookingId != null) ...[
                    const SizedBox(height: VSPSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: VSPAnimatedButton(
                            text: AppLocalizations.of(context)!.accept,
                            height: 44,
                            onPressed: () => NotificationRepository().respondToChallenge(
                              userId,
                              notification.id, 
                              notification.bookingId!, 
                              true
                            ),
                          ),
                        ),
                        const SizedBox(width: VSPSpacing.sm),
                        Expanded(
                          child: VSPAnimatedButton(
                            text: AppLocalizations.of(context)!.decline,
                            height: 44,
                            color: VSPColors.surfaceAlt,
                            textColor: VSPColors.textSecondary,
                            onPressed: () => NotificationRepository().respondToChallenge(
                              userId,
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
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'challenge':
        return Icons.sports_soccer;
      case 'result_confirmation':
        return Icons.emoji_events_outlined;
      case 'booking_confirmed':
        return Icons.check_circle_outline;
      case 'booking_new':
        return Icons.calendar_today;
      case 'booking_cancelled':
        return Icons.cancel_outlined;
      case 'debt_warning':
        return Icons.warning_amber_rounded;
      case 'debt_grace':
        return Icons.timer_outlined;
      case 'account_blocked':
        return Icons.block;
      case 'player_blocked':
        return Icons.person_off_outlined;
      case 'stadium_approved':
        return Icons.verified_outlined;
      case 'public_match_joined':
        return Icons.person_add_alt_1;
      case 'match_full':
        return Icons.groups;
      case 'chat':
        return Icons.chat_bubble_outline;
      case 'info':
      default:
        return Icons.info_outline;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'challenge':
      case 'booking_confirmed':
      case 'stadium_approved':
      case 'public_match_joined':
      case 'match_full':
        return VSPColors.accent;
      case 'booking_cancelled':
      case 'debt_warning':
      case 'debt_grace':
      case 'account_blocked':
      case 'player_blocked':
        return VSPColors.error;
      case 'result_confirmation':
        return VSPColors.accent;
      case 'chat':
        return const Color(0xFF818CF8); // Indigo
      case 'booking_new':
        return VSPColors.success;
      case 'info':
      default:
        return Colors.blue;
    }
  }

  String _formatTime(BuildContext context, DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) return AppLocalizations.of(context)!.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return AppLocalizations.of(context)!.hoursAgo(diff.inHours);
    return DateFormat('MMM d', AppLocalizations.of(context)!.localeName).format(dt);
  }
}
