import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/utils/app_date_formatter.dart';
import '../../../../core/services/support_service.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../core/repositories/chat_repository.dart';
import '../../../../core/services/sharing_service.dart';
import '../../../../core/widgets/shimmer_image.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/vsp_animated_button.dart';
import '../../screens/chat_screen.dart';
import '../../screens/match_details_screen.dart';
import '../../screens/player_booking_details_screen.dart';
import '../../screens/matchup_live_dashboard_screen.dart';
import 'challenge_result_actions.dart';
import 'player_booking_cancel_dialog.dart';
import 'refund_badge_widget.dart';
import 'reschedule_action_banner.dart';

/// Comprehensive individual booking card for upcoming and history bookings in player bookings screen.
class PlayerBookingCard extends StatelessWidget {
  final Booking booking;
  final bool isHistory;
  final String? myTeamId;
  final String? myCaptainTeamId;

  const PlayerBookingCard({
    super.key,
    required this.booking,
    required this.isHistory,
    this.myTeamId,
    this.myCaptainTeamId,
  });

  String _getLocalizedBookingType(BuildContext context, BookingType type) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    switch (type) {
      case BookingType.personal:
        return isArabic ? 'حجز عادي' : 'SOLO';
      case BookingType.openJoin:
        return isArabic ? 'تجميعي' : 'OPEN JOIN';
      case BookingType.team:
        return isArabic ? 'فريق' : 'TEAM';
      case BookingType.challenge:
        return isArabic ? 'تحدي' : 'CHALLENGE';
      case BookingType.matchup:
        return isArabic ? 'مواجهات' : 'MATCHUP';
      case BookingType.maintenance:
        return isArabic ? 'صيانة' : 'MAINTENANCE';
    }
  }

  Widget _buildTag(String text, {Color? color}) {
    return Text(
      text,
      style: TextStyle(
        color: color ?? Colors.white.withValues(alpha: 0.9),
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildInfoColumn(BuildContext context, String label, String value, {bool isTime = false}) {
    final isArabic = Localizations.localeOf(context).languageCode.startsWith('ar');
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: VSPSpacing.xs),
        Directionality(
          textDirection: isTime
              ? (isArabic ? TextDirection.rtl : TextDirection.ltr)
              : Directionality.of(context),
          child: Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: VSPColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ],
    );
  }

  String _formatDate(BuildContext context, DateTime dt) {
    final locale = Localizations.localeOf(context).languageCode;
    return AppDateFormatter.formatDayMonth(dt, locale);
  }

  String _formatTimeRange(BuildContext context, DateTime startDt, DateTime endDt) {
    final isArabic = Localizations.localeOf(context).languageCode.startsWith('ar');
    final start = startDt.toLocal();
    final end = endDt.toLocal();

    String formatSingle(DateTime dt) {
      final h = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final period = isArabic ? (dt.hour >= 12 ? 'م' : 'ص') : (dt.hour >= 12 ? 'PM' : 'AM');
      if (dt.minute == 0) {
        return '$h $period';
      }
      return '$h:${dt.minute.toString().padLeft(2, '0')} $period';
    }

    return '${formatSingle(start)} - ${formatSingle(end)}';
  }

  void _showCancelDialog(BuildContext context) {
    PlayerBookingCancelDialog.show(context, booking);
  }

  Future<void> _openDetails(BuildContext context) async {
    if (booking.bookingType == BookingType.openJoin) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MatchDetailsScreen(bookingId: booking.id)),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerBookingDetailsScreen(booking: booking)),
    );
  }

  Future<void> _openChat(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final me = auth.currentUser?.id;
    if (me == null) return;
    final other = <String>[booking.ownerId, booking.createdByUserId, ...booking.joinedUserIds]
        .firstWhere((id) => id.isNotEmpty && id != me, orElse: () => '');
    if (other.isEmpty) {
      final ar = Localizations.localeOf(context).languageCode == 'ar';
      VSPFeedback.showError(context, ar ? 'لا يوجد طرف مؤهل للمحادثة.' : 'No eligible chat participant.');
      return;
    }
    try {
      final type = booking.bookingType == BookingType.challenge ? 'challenge' : 'booking';
      final chat = await ChatRepository().getOrCreateDirectChat(
        otherUserId: other,
        isArabic: Localizations.localeOf(context).languageCode == 'ar',
        contextType: type,
        contextId: booking.id,
      );
      final chatId = chat['id']?.toString();
      if (chatId == null || !context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(booking: booking, conversationId: chatId, otherUserId: other)),
      );
    } catch (_) {
      if (context.mounted) {
        final ar = Localizations.localeOf(context).languageCode == 'ar';
        VSPFeedback.showError(context, ar ? 'تعذر فتح المحادثة.' : 'Could not open the chat.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(VSPRadius.card),
        onTap: () => _openDetails(context),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(VSPSpacing.md),
          decoration: BoxDecoration(
            color: isHistory ? VSPColors.surface : VSPColors.surfaceAlt,
            borderRadius: BorderRadius.circular(VSPRadius.card),
            border: Border.all(
              color: isHistory ? VSPColors.divider : VSPColors.accent.withValues(alpha: 0.25),
              width: 1.0,
            ),
            boxShadow: const [VSPShadow.subtle],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      border: Border.all(color: VSPColors.textPrimary.withValues(alpha: 0.15), width: 1.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(VSPRadius.md - 1),
                      child: booking.stadiumImageUrl.isNotEmpty
                          ? ShimmerImage(
                              imageUrl: booking.stadiumImageUrl,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: VSPColors.surface,
                              child: const Icon(Iconsax.location_copy, color: VSPColors.accent),
                            ),
                    ),
                  ),
                  const SizedBox(width: VSPSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.stadiumName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: VSPColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: VSPSpacing.xs),
                        Row(
                          children: [
                            _buildTag(_getLocalizedBookingType(context, booking.bookingType)),
                            if (booking.bookingType == BookingType.openJoin && booking.isPrivate) ...[
                              const SizedBox(width: VSPSpacing.sm),
                              _buildTag(l10n.private, color: VSPColors.warning),
                            ],
                          ],
                        ),
                        if (booking.isChallenge &&
                            ((booking.playerTeamName != null && booking.playerTeamName!.isNotEmpty) ||
                             (booking.opponentTeamName != null && booking.opponentTeamName!.isNotEmpty))) ...[
                          const SizedBox(height: 6),
                          Text(
                            '${booking.playerTeamName ?? (isArabic ? "فريقنا" : "Our Team")} VS ${booking.opponentTeamName ?? (isArabic ? "الخصم" : "Opponent")}',
                            style: const TextStyle(
                              color: VSPColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (booking.status == BookingStatus.cancelled) ...[
                    ChallengeResultActions.buildStatusBadge(
                      isArabic ? 'ملغي' : 'Cancelled',
                      VSPColors.error,
                    ),
                  ] else if (booking.status == BookingStatus.expired) ...[
                    ChallengeResultActions.buildStatusBadge(
                      isArabic ? 'انتهت مهلة الدفع' : 'Payment expired',
                      VSPColors.error,
                    ),
                  ] else if (booking.status == BookingStatus.pending) ...[
                    ChallengeResultActions.buildStatusBadge(
                      booking.isPaid
                          ? (isArabic ? 'قيد تأكيد الدفع' : 'Payment verification')
                          : (isArabic ? 'بانتظار السداد' : 'Pending payment'),
                      VSPColors.warning,
                    ),
                  ] else if (!isHistory &&
                      (booking.status == BookingStatus.confirmed ||
                          booking.status == BookingStatus.upcoming)) ...[
                    ChallengeResultActions.buildStatusBadge(
                      l10n.confirmed,
                      VSPColors.accent,
                    ),
                  ] else if (booking.status == BookingStatus.noShow) ...[
                    ChallengeResultActions.buildStatusBadge(
                      isArabic ? 'عدم حضور' : 'No-show',
                      VSPColors.error,
                    ),
                  ] else if (booking.endTime.isAfter(DateTime.now())) ...[
                    ChallengeResultActions.buildStatusBadge(
                      l10n.inProgress,
                      VSPColors.accent,
                    ),
                  ] else if (booking.bookingType == BookingType.challenge) ...[
                    Builder(
                      builder: (ctx) {
                        if (myTeamId == null) return const SizedBox.shrink();
                        return ChallengeResultActions.buildChallengeStatusBadge(
                          context,
                          booking: booking,
                          myTeamId: myTeamId,
                        );
                      },
                    ),
                  ] else ...[
                    ChallengeResultActions.buildStatusBadge(
                      l10n.completed,
                      VSPColors.textSecondary,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: VSPSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(vertical: VSPSpacing.sm, horizontal: VSPSpacing.md),
                decoration: BoxDecoration(
                  color: VSPColors.background.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoColumn(context, l10n.date, _formatDate(context, booking.startTime)),
                    Container(width: 1, height: 24, color: VSPColors.divider.withValues(alpha: 0.1)),
                    _buildInfoColumn(context, l10n.time, _formatTimeRange(context, booking.startTime, booking.endTime), isTime: true),
                    Container(width: 1, height: 24, color: VSPColors.divider.withValues(alpha: 0.1)),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: _buildInfoColumn(context, l10n.price, '${booking.totalPrice.toInt()} ${l10n.egCurrency}'),
                    ),
                  ],
                ),
              ),
          // 🔒 REFUND BADGE LOGIC: Strictly verify real refund vs unconfirmed payment
          Builder(builder: (context) {
            // First check if the user actually paid any money at all.
            // If the user cancelled during checkout or paid nothing (0 EGP, unpaid, cash, etc.),
            // NEVER show any refund badge!
            final bool hasPaidMoney = (booking.depositPaid > 0) ||
                (booking.refundAmount != null && booking.refundAmount! > 0) ||
                booking.isDepositPaid ||
                booking.isPaid ||
                booking.paymentStatus == 'paid' ||
                booking.paymentStatus == 'refunded' ||
                booking.paymentStatus == 'refund_pending';

            if (!hasPaidMoney || booking.status != BookingStatus.cancelled) {
              return const SizedBox.shrink();
            }

            final bool isCashMethod = booking.paymentMethod.toLowerCase() == 'cash';
            if (isCashMethod && (booking.depositPaid <= 0 && !booking.isDepositPaid)) {
              return const SizedBox.shrink();
            }

            final bool hasRealRefund = booking.paymentStatus == 'refunded' &&
                ((booking.refundTransactionId != null &&
                        booking.refundTransactionId!.isNotEmpty) ||
                    (booking.refundAmount != null &&
                        booking.refundAmount! > 0));

            final bool isRefundPending = !hasRealRefund &&
                booking.paymentStatus == 'refund_pending';

            // Only show contact support if money was ACTUALLY paid, and payment failed or needs manual refund handling.
            // Exclude abandoned checkouts where no money was paid AND pure-cash bookings with no online deposit!
            final bool isUnconfirmedPayment = !hasRealRefund &&
                !isRefundPending &&
                (booking.depositPaid > 0 || booking.isPaid || booking.isDepositPaid) &&
                (booking.paymentStatus == 'refund_failed' ||
                    (booking.paymentMethod.toLowerCase() != 'cash' &&
                        (booking.depositPaid > 0 || booking.isPaid || booking.isDepositPaid)));

            if (hasRealRefund) {
              return Padding(
                padding: const EdgeInsets.only(top: VSPSpacing.sm),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: RefundBadgeWidget(
                    refundInfo: RefundInfo.fromBookingRow({
                      'refund_channel': booking.refundChannel,
                      'refund_eta': booking.refundEta,
                      'display_refund_ref': booking.displayRefundRef ??
                          booking.refundTransactionId ??
                          booking.paymentTransactionId,
                      'refunded_at': booking.refundedAt?.toIso8601String(),
                      'refund_payment_method':
                          booking.refundPaymentMethod ?? booking.paymentMethod,
                      'payment_method': booking.paymentMethod,
                      'refund_amount': booking.refundAmount ??
                          (booking.depositPaid > 0
                              ? booking.depositPaid
                              : booking.totalPrice),
                    }),
                  ),
                ),
              );
            } else if (isRefundPending) {
              return Padding(
                padding: const EdgeInsets.only(top: VSPSpacing.sm),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _buildProcessingRefundBadge(context, isArabic),
                ),
              );
            } else if (isUnconfirmedPayment) {
              return Padding(
                padding: const EdgeInsets.only(top: VSPSpacing.sm),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _buildContactSupportRefundBadge(context, isArabic),
                ),
              );
            }
            return const SizedBox.shrink();
          }),
          if (booking.bookingType == BookingType.challenge && booking.opponentTeamName != null) ...[
            const SizedBox(height: VSPSpacing.sm),
            Container(
              padding: const EdgeInsets.all(VSPSpacing.sm),
              decoration: BoxDecoration(
                color: VSPColors.warning.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(VSPRadius.sm),
                border: Border.all(color: VSPColors.warning.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.cup_copy, color: VSPColors.warning, size: 20),
                  const SizedBox(width: VSPSpacing.sm),
                  Text(
                    l10n.vsOpponent(booking.opponentTeamName ?? ""),
                    style: const TextStyle(
                      color: VSPColors.warning,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (booking.rescheduleStatus == 'pending' && booking.proposedStartTime != null) ...[
            const SizedBox(height: VSPSpacing.sm),
            RescheduleActionBanner(booking: booking),
          ],
          if (booking.bookingType == BookingType.matchup) ...[
            const SizedBox(height: VSPSpacing.md),
            VSPAnimatedButton(
              text: isArabic ? 'لوحة المواجهة والنتائج الحية' : 'Live Matchup Dashboard',
              color: VSPColors.accent,
              textColor: Colors.black,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MatchupLiveDashboardScreen(bookingId: booking.id),
                  ),
                );
              },
            ),
          ],
          if (!isHistory) ...[
            const SizedBox(height: VSPSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Builder(
                    builder: (btnCtx) {
                      final now = DateTime.now();
                      final deadline = booking.startTime.subtract(const Duration(hours: 6));
                      final isWithinGrace = now.difference(booking.createdAt).inMinutes <= 20 && !now.isAfter(booking.startTime);
                      final bool canCancel = now.isBefore(deadline) || isWithinGrace;
                      final bool bookingStarted = now.isAfter(booking.startTime);
                      final String lockedLabel = bookingStarted
                          ? (isArabic ? 'بدأ الحجز' : 'Booking started')
                          : (isArabic ? 'لا يمكن الإلغاء (أقل من 6 ساعات)' : 'Cannot cancel (< 6 hrs left)');
                      return Tooltip(
                        message: canCancel ? '' : lockedLabel,
                        child: VSPAnimatedButton(
                          text: l10n.cancel,
                          color: canCancel ? VSPColors.surface : VSPColors.surface.withValues(alpha: 0.4),
                          textColor: canCancel ? VSPColors.error : VSPColors.textSecondary.withValues(alpha: 0.5),
                          onPressed: canCancel ? () => _showCancelDialog(context) : null,
                        ),
                      );
                    },
                  ),
                ),
                if (booking.bookingType == BookingType.openJoin && booking.isPrivate) ...[
                Expanded(
                  child: VSPAnimatedButton(
                    text: isArabic ? 'مشاركة' : 'Share',
                    color: VSPColors.accent,
                    textColor: Colors.black,
                    onPressed: () => SharingService.shareMatch(
                      bookingId: booking.id,
                      teamName: booking.playerTeamName ?? (isArabic ? 'فريقي' : 'My Team'),
                      stadiumName: booking.stadiumName,
                      date: '${_formatDate(context, booking.startTime)} - ${_formatTimeRange(context, booking.startTime, booking.endTime)}',
                    ),
                  ),
                ),
                const SizedBox(width: VSPSpacing.sm),
              ],
              Expanded(
                child: VSPAnimatedButton(
                  text: l10n.chat,
                    onPressed: () => _openChat(context),
                  ),
                ),
              ],
            ),
          ],
          if (isHistory &&
              booking.bookingType == BookingType.challenge &&
              booking.opponentTeamId != null &&
              myCaptainTeamId != null &&
              booking.endTime.isBefore(DateTime.now())) ...[
            const SizedBox(height: VSPSpacing.md),
            ChallengeResultActions(booking: booking, myTeamId: myCaptainTeamId),
          ],
        ],
      ),
    ),
  ),
);
  }

  Widget _buildContactSupportRefundBadge(BuildContext context, bool isArabic) {
    return GestureDetector(
      onTap: () => SupportService().openSupport(context, category: 'refund', booking: booking),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: VSPColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(VSPRadius.full),
          border: Border.all(color: VSPColors.warning.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Iconsax.message_question_copy, size: 13, color: VSPColors.warning),
            const SizedBox(width: 5),
            Text(
              isArabic ? 'فتح تذكرة لاسترداد المبلغ' : 'Open refund support ticket',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: VSPColors.warning),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingRefundBadge(BuildContext context, bool isArabic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: VSPColors.info.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(VSPRadius.full),
        border: Border.all(
          color: VSPColors.info.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 11,
            height: 11,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(VSPColors.info),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isArabic ? 'جاري معالجة الاسترداد...' : 'Refund processing...',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: VSPColors.info,
            ),
          ),
        ],
      ),
    );
  }
}
