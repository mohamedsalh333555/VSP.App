import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/vsp_ui.dart';
import '../../../shared/widgets/vsp_animated_button.dart';
import '../../../shared/widgets/vsp_empty_state.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import 'package:go_router/go_router.dart';
import '../../owner/screens/subscription_plans_screen.dart';
import '../../owner/screens/owner_ledger_screen.dart';
import '../../../core/services/notification/notification_ui_helper.dart';
import '../../../data/models.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/notification_repository.dart';
import '../../../core/utils/app_date_formatter.dart';
import 'package:provider/provider.dart';

class NotificationsCenterScreen extends StatefulWidget {
  const NotificationsCenterScreen({super.key});

  @override
  State<NotificationsCenterScreen> createState() => _NotificationsCenterScreenState();
}

class _NotificationsCenterScreenState extends State<NotificationsCenterScreen> {
  late Stream<List<AppNotification>> _notificationsStream;
  late String _userId;

  @override
  void initState() {
    super.initState();
    _userId = context.read<AuthProvider>().currentUser?.id ?? '';
    _notificationsStream = NotificationRepository().getUserNotifications(_userId);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentUserId = context.watch<AuthProvider>().currentUser?.id ?? '';
    if (currentUserId != _userId) {
      _userId = currentUserId;
      _notificationsStream = NotificationRepository().getUserNotifications(_userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return VSPScaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        leading: const VSPBackButton(),
        centerTitle: true,
        title: Text(
          AppLocalizations.of(context)!.notifications,
          style: Theme.of(context).textTheme.displaySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => NotificationRepository().markAllAsRead(_userId),
            child: Text(AppLocalizations.of(context)!.markAll, style: const TextStyle(color: VSPColors.accent, fontSize: 13)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: StreamBuilder<List<AppNotification>>(
          key: ValueKey(_userId),
          stream: _notificationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            final isArabic = Localizations.localeOf(context).languageCode == 'ar';
            return VSPStateView(
              state: VSPUiState.loading,
              title: isArabic ? 'جاري تحميل الإشعارات' : 'Loading notifications',
              message: isArabic ? 'بنجهّز آخر التنبيهات والإجراءات المطلوبة.' : 'Refreshing your latest alerts and required actions.',
            );
          }

          if (snapshot.hasError &&
              (snapshot.data == null || snapshot.data!.isEmpty)) {
            final isArabic = Localizations.localeOf(context).languageCode == 'ar';
            return VSPStateView(
              state: VSPUiState.error,
              title: isArabic ? 'تعذر تحميل الإشعارات' : 'Could not load notifications',
              message: isArabic
                  ? 'تحقق من اتصالك بالإنترنت ثم أعد المحاولة.'
                  : 'Check your internet connection and try again.',
              onRetry: () {
                setState(() {
                  _notificationsStream =
                      NotificationRepository().getUserNotifications(_userId);
                });
              },
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            final auth = Provider.of<AuthProvider>(context, listen: false);
            final isArabic = Localizations.localeOf(context).languageCode == 'ar';
            return VSPEmptyState(
              icon: Iconsax.notification_copy,
              title: AppLocalizations.of(context)!.noNotificationsTitle,
              subtitle: AppLocalizations.of(context)!.noNotificationsSubtitle,
              buttonText: auth.isOwner
                  ? (isArabic ? 'العودة للوحة التحكم' : 'Back to Dashboard')
                  : AppLocalizations.of(context)!.backToDashboard,
              onButtonPressed: () => Navigator.pop(context),
            );
          }

          return Column(
            children: [
              if (snapshot.hasError)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(
                    VSPSpacing.md,
                    VSPSpacing.sm,
                    VSPSpacing.md,
                    0,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: VSPSpacing.md,
                    vertical: VSPSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: VSPColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(color: VSPColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Iconsax.warning_2_copy, color: VSPColors.warning, size: 17),
                      const SizedBox(width: VSPSpacing.sm),
                      Expanded(
                        child: Text(
                          Localizations.localeOf(context).languageCode == 'ar'
                              ? 'تعذر تحديث الإشعارات. نعرض آخر قائمة تم تحميلها.'
                              : 'Could not refresh notifications. Showing the last loaded list.',
                          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11.5),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _notificationsStream = NotificationRepository().getUserNotifications(_userId);
                        }),
                        child: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'إعادة المحاولة' : 'Retry'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.separated(
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
                    child: const Icon(Iconsax.trash_copy, color: VSPColors.error, size: 24),
                  ),
                  onDismissed: (_) async {
                    final deletedItem = notification;
                    // Bind the delete/Undo operation to the account that owned this row.
                    // The screen may remain mounted while AuthProvider switches accounts.
                    final deletingUserId = _userId;
                    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
                    final repository = NotificationRepository();
                    final deleted = await repository.deleteNotification(deletingUserId, deletedItem.id);

                    if (!context.mounted || _userId != deletingUserId) return;
                    if (!deleted) {
                      setState(() {
                        _notificationsStream = repository.getUserNotifications(_userId);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isArabic ? 'تعذر حذف الإشعار. حاول مرة أخرى.' : 'Could not delete the notification. Please try again.',
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: VSPColors.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isArabic ? 'تم حذف الإشعار' : 'Notification deleted',
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: VSPColors.surface,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                        action: SnackBarAction(
                          label: isArabic ? 'تراجع' : 'Undo',
                          textColor: VSPColors.accent,
                          onPressed: () async {
                            // Never restore an old account's notification into a newly
                            // signed-in account if the user changed while the SnackBar was visible.
                            if (!context.mounted || _userId != deletingUserId) return;
                            final restored = await repository.restoreNotification(deletingUserId, deletedItem);
                            if (!restored && context.mounted && _userId == deletingUserId) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isArabic ? 'تعذرت استعادة الإشعار.' : 'Could not restore the notification.',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  backgroundColor: VSPColors.error,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                        ),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  },
                  child: _NotificationCard(notification: notification, userId: _userId),
                ),
              );
            },
          ),
              ),
            ],
          );
          },
        ),
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
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return InkWell(
      onTap: () => _onNotificationTap(context),
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
                color: _getIconColor(notification.type).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _getIconColor(notification.type).withValues(alpha: 0.3),
                  width: 1,
                ),
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
                          _localizeText(context, notification.title),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(context, notification.createdAt),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: VSPSpacing.xs),
                  Text(
                    _localizeText(context, notification.body),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: notification.isRead ? VSPColors.textSecondary.withValues(alpha: 0.6) : VSPColors.textSecondary,
                    ),
                  ),
  
                  // Secure interactive action for challenges
                  if ((notification.type == 'challenge' || notification.type == 'challenge_confirmed') && notification.bookingId != null) ...[
                    const SizedBox(height: VSPSpacing.md),
                    VSPAnimatedButton(
                      text: isArabic ? 'عرض تفاصيل التحدي' : 'View Challenge Details',
                      height: 44,
                      onPressed: () {
                        NotificationRepository().markNotificationAsRead(userId, notification.id);
                        NotificationUiHelper.navigateToBooking(context, notification.bookingId!);
                      },
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

  void _onNotificationTap(BuildContext context) {
    if (!notification.isRead) {
      NotificationRepository().markNotificationAsRead(userId, notification.id);
    }

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final type = notification.type.toLowerCase();
    final bookingId = notification.bookingId;
    final metadata = notification.metadata ?? {};

    if (bookingId != null && bookingId.isNotEmpty) {
      if (type == 'chat') {
        NotificationUiHelper.navigateToChat(context, bookingId);
        return;
      }
      NotificationUiHelper.navigateToBooking(context, bookingId);
      return;
    }

    if (type == 'subscription') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SubscriptionPlansScreen()),
      );
      return;
    }

    if (type == 'payout' || type == 'debt_warning' || type == 'debt_grace' || type == 'account_blocked') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const OwnerLedgerScreen()),
      );
      return;
    }

    final tournamentId = (metadata['tournament_id'] ?? metadata['championship_id'])?.toString();
    if (tournamentId != null && tournamentId.isNotEmpty) {
      try {
        GoRouter.of(context).push('/championship/$tournamentId');
        return;
      } catch (_) {}
    }

    // Default announcement dialog for system / informational notifications
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.card)),
        title: Row(
          children: [
            Icon(_getIcon(notification.type), color: _getIconColor(notification.type), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _localizeText(context, notification.title),
                style: const TextStyle(color: VSPColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          _localizeText(context, notification.body),
          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isArabic ? 'حسناً' : 'OK', style: const TextStyle(color: VSPColors.accent)),
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type.toLowerCase()) {
      case 'system':
      case 'announcement':
        return Iconsax.shield_tick_copy;
      case 'subscription':
        return Iconsax.crown_copy;
      case 'refund':
      case 'tournament_refund':
      case 'tournament_refund_manual':
      case 'payout':
        return Iconsax.wallet_3_copy;
      case 'challenge':
      case 'result_confirmation':
        return Iconsax.cup_copy;
      case 'booking_confirmed':
        return Iconsax.tick_circle_copy;
      case 'booking_new':
        return Iconsax.calendar_1_copy;
      case 'booking_cancelled':
        return Iconsax.close_circle_copy;
      case 'debt_warning':
        return Iconsax.warning_2_copy;
      case 'debt_grace':
        return Iconsax.clock_copy;
      case 'account_blocked':
        return Iconsax.close_circle_copy;
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
        return Iconsax.info_circle_copy;
    }
  }

  Color _getIconColor(String type) {
    switch (type.toLowerCase()) {
      case 'system':
      case 'announcement':
        return VSPColors.warning; // Amber / Gold for system alerts
      case 'subscription':
        return VSPColors.proAccent;
      case 'refund':
      case 'tournament_refund':
      case 'tournament_refund_manual':
        return VSPColors.success;
      case 'payout':
        return VSPColors.accent;
      case 'challenge':
      case 'booking_confirmed':
      case 'stadium_approved':
      case 'public_match_joined':
      case 'match_full':
      case 'result_confirmation':
        return VSPColors.accent;
      case 'booking_cancelled':
      case 'debt_warning':
      case 'debt_grace':
      case 'account_blocked':
      case 'player_blocked':
        return VSPColors.error;
      case 'chat':
        return VSPColors.info;
      case 'booking_new':
        return VSPColors.success;
      case 'info':
      default:
        return VSPColors.info;
    }
  }

  String _formatTime(BuildContext context, DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (diff.inMinutes < 60) return AppLocalizations.of(context)!.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return AppLocalizations.of(context)!.hoursAgo(diff.inHours);
    return AppDateFormatter.formatDayMonth(dt, isArabic ? 'ar' : 'en');
  }

  String _localizeText(BuildContext context, String text) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    if (isArabic) return text;

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

