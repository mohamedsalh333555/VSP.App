import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/notification_repository.dart';
import '../../../core/services/notification/notification_ui_helper.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/vsp_animated_button.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../../../shared/widgets/vsp_empty_state.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';

enum NotificationFilter { all, unread, bookings, chat, challenges }

class NotificationsCenterScreen extends StatefulWidget {
  const NotificationsCenterScreen({super.key});

  @override
  State<NotificationsCenterScreen> createState() => _NotificationsCenterScreenState();
}

class _NotificationsCenterScreenState extends State<NotificationsCenterScreen> {
  late final Stream<List<AppNotification>> _notificationsStream;
  late final String _userId;
  NotificationFilter _activeFilter = NotificationFilter.all;

  @override
  void initState() {
    super.initState();
    _userId = context.read<AuthProvider>().currentUser?.uid ?? '';
    _notificationsStream = NotificationRepository().getUserNotifications(_userId);
  }

  List<AppNotification> _filterNotifications(List<AppNotification> list) {
    switch (_activeFilter) {
      case NotificationFilter.unread:
        return list.where((n) => !n.isRead).toList();
      case NotificationFilter.bookings:
        return list.where((n) => n.type.startsWith('booking_')).toList();
      case NotificationFilter.chat:
        return list.where((n) => n.type == 'chat').toList();
      case NotificationFilter.challenges:
        return list
            .where((n) => n.type.startsWith('challenge') || n.type == 'result_confirmation')
            .toList();
      case NotificationFilter.all:
        return list;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        leading: const VSPBackButton(),
        centerTitle: true,
        title: Text(
          AppLocalizations.of(context)!.notifications,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 18),
        ),
        actions: [
          StreamBuilder<List<AppNotification>>(
            stream: _notificationsStream,
            builder: (context, snapshot) {
              final unreadCount = (snapshot.data ?? []).where((n) => !n.isRead).length;
              if (unreadCount == 0) return const SizedBox.shrink();

              return TextButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  NotificationRepository().markAllAsRead(_userId);
                },
                icon: const Icon(Iconsax.tick_circle_copy, size: 15, color: VSPColors.accent),
                label: Text(
                  AppLocalizations.of(context)!.markAll,
                  style: const TextStyle(color: VSPColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _notificationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
          }

          final allNotifications = snapshot.data ?? [];
          final unreadCount = allNotifications.where((n) => !n.isRead).length;
          final filtered = _filterNotifications(allNotifications);

          if (allNotifications.isEmpty) {
            return VSPEmptyState(
              icon: Iconsax.notification_copy,
              title: AppLocalizations.of(context)!.noNotificationsTitle,
              subtitle: AppLocalizations.of(context)!.noNotificationsSubtitle,
              buttonText: AppLocalizations.of(context)!.backToDashboard,
              onButtonPressed: () => Navigator.pop(context),
            );
          }

          return Column(
            children: [
              // 1. شريط الفلاتر الأفقي العصري (Filter Chips)
              _buildFilterBar(isAr, unreadCount),

              // 2. قائمة الإشعارات
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Iconsax.filter_search_copy, size: 40, color: Colors.white.withValues(alpha: 0.2)),
                            const SizedBox(height: 12),
                            Text(
                              isAr ? 'لا توجد إشعارات في هذا القسم' : 'No notifications in this category',
                              style: TextStyle(color: VSPColors.textSecondary.withValues(alpha: 0.6), fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          VSPSpacing.md,
                          VSPSpacing.sm,
                          VSPSpacing.md,
                          MediaQuery.of(context).padding.bottom + 24,
                        ),
                        physics: const BouncingScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: VSPSpacing.sm),
                        itemBuilder: (context, index) {
                          final notification = filtered[index];
                          return VSPFadeInItem(
                            index: index,
                            child: Dismissible(
                              key: ValueKey(notification.id),
                              direction: DismissDirection.endToStart,
                              // ✅ حل مشكلة اتجاه سلة المهملات في RTL عبر Directional Alignment
                              background: Container(
                                alignment: AlignmentDirectional.centerEnd,
                                padding: const EdgeInsetsDirectional.only(end: 20),
                                decoration: BoxDecoration(
                                  color: VSPColors.error.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(VSPRadius.lg),
                                  border: Border.all(color: VSPColors.error.withValues(alpha: 0.3)),
                                ),
                                child: const Icon(Iconsax.trash_copy, color: VSPColors.error, size: 22),
                              ),
                              onDismissed: (_) {
                                final deletedNotification = notification;
                                NotificationRepository().deleteNotification(_userId, deletedNotification.id);
                                ScaffoldMessenger.of(context).clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isAr ? 'تم حذف الإشعار' : 'Notification deleted',
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                    ),
                                    backgroundColor: VSPColors.surfaceAlt,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                                    action: SnackBarAction(
                                      label: isAr ? 'تراجع' : 'Undo',
                                      textColor: VSPColors.accent,
                                      onPressed: () {
                                        NotificationRepository().sendNotification(_userId, deletedNotification);
                                      },
                                    ),
                                  ),
                                );
                              },
                              child: _NotificationCard(
                                notification: notification,
                                userId: _userId,
                                isAr: isAr,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(bool isAr, int unreadCount) {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 8, top: 2),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        children: [
          _buildFilterChip(NotificationFilter.all, isAr ? 'الكل' : 'All'),
          _buildFilterChip(
            NotificationFilter.unread,
            isAr ? 'غير مقروء' : 'Unread',
            badgeCount: unreadCount,
          ),
          _buildFilterChip(NotificationFilter.bookings, isAr ? 'الحجوزات' : 'Bookings'),
          _buildFilterChip(NotificationFilter.chat, isAr ? 'المحادثات' : 'Chat'),
          _buildFilterChip(NotificationFilter.challenges, isAr ? 'التحديات' : 'Challenges'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(NotificationFilter filter, String title, {int badgeCount = 0}) {
    final isSelected = _activeFilter == filter;

    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _activeFilter = filter);
        },
        borderRadius: BorderRadius.circular(VSPRadius.full),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? VSPColors.accent : VSPColors.surfaceAlt,
            borderRadius: BorderRadius.circular(VSPRadius.full),
            border: Border.all(
              color: isSelected ? VSPColors.accent : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.black : VSPColors.textSecondary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.black : VSPColors.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeCount.toString(),
                    style: TextStyle(
                      color: isSelected ? VSPColors.accent : Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final String userId;
  final bool isAr;

  const _NotificationCard({
    required this.notification,
    required this.userId,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    final hasDeepLink = notification.bookingId != null && notification.bookingId!.trim().isNotEmpty;

    return InkWell(
      onTap: () async {
        HapticFeedback.lightImpact();
        // 1. تعليم الإشعار كمقروء فوراً
        if (!notification.isRead) {
          NotificationRepository().markNotificationAsRead(userId, notification.id);
        }

        // 2. التوجيه الذكي المباشر (Deep-link Navigation)
        if (hasDeepLink) {
          if (notification.type == 'chat') {
            NotificationUiHelper.navigateToChat(context, notification.bookingId!);
          } else {
            NotificationUiHelper.navigateToBooking(context, notification.bookingId!);
          }
        }
      },
      borderRadius: BorderRadius.circular(VSPRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(VSPSpacing.md),
        decoration: BoxDecoration(
          color: notification.isRead ? VSPColors.surface.withValues(alpha: 0.5) : VSPColors.surfaceAlt,
          borderRadius: BorderRadius.circular(VSPRadius.lg),
          border: Border.all(
            color: notification.isRead
                ? Colors.white.withValues(alpha: 0.05)
                : VSPColors.accent.withValues(alpha: 0.35),
            width: notification.isRead ? 1 : 1.2,
          ),
          boxShadow: notification.isRead
              ? null
              : [
                  BoxShadow(
                    color: VSPColors.accent.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // أيقونة نوع الإشعار
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getIconColor(notification.type).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIcon(notification.type),
                    color: _getIconColor(notification.type),
                    size: 20,
                  ),
                ),
                // ✅ نقطة التمييز غير المقروء (Glowing Unread Indicator Dot)
                if (!notification.isRead)
                  PositionedDirectional(
                    top: -2,
                    end: -2,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: VSPColors.accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: VSPColors.accent.withValues(alpha: 0.8),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: VSPSpacing.md),

            // محتوى الإشعار (العنوان، الجسم، التوقيت)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // عنوان الإشعار بسطرين لتفادي القطع المشوه
                      Expanded(
                        child: Text(
                          _localizeText(context, notification.title),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontSize: 13.5,
                                fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w800,
                                color: notification.isRead ? VSPColors.textSecondary : VSPColors.textPrimary,
                                height: 1.25,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // التوقيت الزمني الدقيق
                      Text(
                        _formatTime(context, notification.createdAt),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: notification.isRead
                                  ? VSPColors.textSecondary.withValues(alpha: 0.45)
                                  : VSPColors.accent.withValues(alpha: 0.85),
                              fontSize: 11,
                              fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // جسم الإشعار
                  Text(
                    _localizeText(context, notification.body),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: notification.isRead
                              ? VSPColors.textSecondary.withValues(alpha: 0.6)
                              : VSPColors.textSecondary.withValues(alpha: 0.9),
                          fontSize: 12,
                          height: 1.35,
                        ),
                  ),

                  // مؤشر إمكانية النقر لفتح التفاصيل
                  if (hasDeepLink) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          notification.type == 'chat'
                              ? (isAr ? 'فتح المحادثة' : 'Open chat')
                              : (isAr ? 'عرض تفاصيل الحجز' : 'View booking details'),
                          style: const TextStyle(
                            color: VSPColors.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          isAr ? Iconsax.arrow_left_2_copy : Iconsax.arrow_right_3_copy,
                          size: 11,
                          color: VSPColors.accent,
                        ),
                      ],
                    ),
                  ],

                  // أزرار التفاعل المباشر للتحديات
                  if (notification.type == 'challenge' && !notification.isRead && notification.bookingId != null) ...[
                    const SizedBox(height: VSPSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: VSPAnimatedButton(
                            text: AppLocalizations.of(context)!.accept,
                            height: 40,
                            onPressed: () => NotificationRepository().respondToChallenge(
                              userId,
                              notification.id,
                              notification.bookingId!,
                              true,
                            ),
                          ),
                        ),
                        const SizedBox(width: VSPSpacing.sm),
                        Expanded(
                          child: VSPAnimatedButton(
                            text: AppLocalizations.of(context)!.decline,
                            height: 40,
                            color: VSPColors.surfaceAlt,
                            textColor: VSPColors.textSecondary,
                            onPressed: () => NotificationRepository().respondToChallenge(
                              userId,
                              notification.id,
                              notification.bookingId!,
                              false,
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
      case 'result_confirmation':
        return Iconsax.cup_copy;
      case 'booking_confirmed':
        return Iconsax.tick_circle_copy;
      case 'booking_new':
        return Iconsax.calendar_1_copy;
      case 'booking_cancelled':
        return Iconsax.close_circle_copy;
      case 'account_blocked':
      case 'player_blocked':
        return Iconsax.user_remove_copy;
      case 'stadium_approved':
        return Iconsax.verify_copy;
      case 'public_match_joined':
        return Iconsax.user_add_copy;
      case 'match_full':
        return Iconsax.people_copy;
      case 'chat':
        return Iconsax.messages_3_copy;
      case 'info':
      default:
        return Iconsax.notification_bing_copy;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'challenge':
      case 'booking_confirmed':
      case 'stadium_approved':
      case 'public_match_joined':
      case 'match_full':
      case 'result_confirmation':
        return VSPColors.accent;
      case 'booking_cancelled':
      case 'account_blocked':
      case 'player_blocked':
        return VSPColors.error;
      case 'chat':
        return const Color(0xFF818CF8); // Indigo
      case 'booking_new':
        return VSPColors.success;
      case 'info':
      default:
        return const Color(0xFF38BDF8); // VSP Sky / Info Cyan
    }
  }

  String _formatTime(BuildContext context, DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    // ✅ حل مشكلة "منذ 0 دقيقة"
    if (diff.inSeconds < 60) {
      return isAr ? 'الآن' : 'Just now';
    }
    if (diff.inMinutes < 60) {
      return isAr ? 'منذ ${diff.inMinutes} د' : '${diff.inMinutes}m';
    }
    if (diff.inHours < 24) {
      return isAr ? 'منذ ${diff.inHours} س' : '${diff.inHours}h';
    }
    if (diff.inDays == 1) {
      return isAr ? 'أمس' : 'Yesterday';
    }
    if (diff.inDays < 7) {
      return isAr ? 'منذ ${diff.inDays} أ' : '${diff.inDays}d';
    }
    return DateFormat('d MMM', isAr ? 'ar' : 'en').format(dt);
  }

  String _localizeText(BuildContext context, String text) {
    if (isAr) return text;

    String result = text;
    final Map<String, String> replacements = {
      'يناير': 'Jan',
      'فبراير': 'Feb',
      'مارس': 'Mar',
      'أبريل': 'Apr',
      'مايو': 'May',
      'يونيو': 'Jun',
      'يوليو': 'Jul',
      'أغسطس': 'Aug',
      'سبتمبر': 'Sep',
      'أكتوبر': 'Oct',
      'نوفمبر': 'Nov',
      'ديسمبر': 'Dec',
      ' م': ' PM',
      ' ص': ' AM',
      'مـ': 'PM',
      'صـ': 'AM',
    };

    replacements.forEach((ar, en) {
      result = result.replaceAll(ar, en);
    });

    return result;
  }
}
