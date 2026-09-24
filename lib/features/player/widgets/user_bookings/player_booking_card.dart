import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_launcher_utils.dart';
import '../../../../core/services/sharing_service.dart';
import '../../../../core/widgets/shimmer_image.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/vsp_animated_button.dart';
import '../../screens/chat_screen.dart';
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

  const PlayerBookingCard({
    super.key,
    required this.booking,
    required this.isHistory,
    this.myTeamId,
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

  Widget _buildInfoColumn(BuildContext context, String label, String value) {
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
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: VSPColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  String _formatTimeShort(String timeRange) {
    final parts = timeRange.split(' - ');
    if (parts.length == 2) {
      final start = parts[0].replaceAll(':00', '');
      final end = parts[1].replaceAll(':00', '');
      return '$start - $end';
    }
    return timeRange;
  }

  void _showCancelDialog(BuildContext context) {
    PlayerBookingCancelDialog.show(context, booking);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
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
                  ],
                ),
              ),
              if (booking.status == BookingStatus.cancelled) ...[
                ChallengeResultActions.buildStatusBadge(isArabic ? 'ملغي' : 'Cancelled', VSPColors.error),
              ] else if (booking.status == BookingStatus.pending && !booking.isPaid) ...[
                ChallengeResultActions.buildStatusBadge(isArabic ? 'بانتظار السداد' : 'Pending Payment', VSPColors.warning),
              ] else if (!isHistory) ...[
                ChallengeResultActions.buildStatusBadge(l10n.confirmed, VSPColors.accent),
              ] else ...[
                if (booking.endTime.isAfter(DateTime.now()))
                  ChallengeResultActions.buildStatusBadge(l10n.inProgress, VSPColors.accent)
                else if (booking.bookingType == BookingType.challenge)
                  ChallengeResultActions.buildChallengeStatusBadge(context, booking: booking, myTeamId: myTeamId)
                else if (booking.status == BookingStatus.completed &&
                    (booking.matchResultStatus == MatchResultStatus.noResult ||
                        booking.matchResultStatus == MatchResultStatus.waitingOpponent))
                  ChallengeResultActions.buildStatusBadge(l10n.submitResult, VSPColors.warning)
                else
                  ChallengeResultActions.buildStatusBadge(l10n.completed, VSPColors.textSecondary),
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
                _buildInfoColumn(context, l10n.date, booking.formattedDate),
                Container(width: 1, height: 24, color: VSPColors.divider.withValues(alpha: 0.1)),
                _buildInfoColumn(context, l10n.time, _formatTimeShort(booking.formattedTimeRange)),
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
            final bool hasRealRefund = booking.status == BookingStatus.cancelled &&
                booking.paymentStatus == 'refunded' &&
                ((booking.refundTransactionId != null &&
                        booking.refundTransactionId!.isNotEmpty) ||
                    (booking.refundAmount != null &&
                        booking.refundAmount! > 0));

            final bool isRefundPending = booking.status == BookingStatus.cancelled &&
                !hasRealRefund &&
                booking.paymentStatus == 'refund_pending';

            final bool isUnconfirmedPayment = booking.status == BookingStatus.cancelled &&
                !hasRealRefund &&
                !isRefundPending &&
                (booking.paymentStatus == 'refund_failed' ||
                    booking.cancellationReason == 'Cancelled by user during payment checkout' ||
                    (booking.paymentMethod.toLowerCase() != 'cash' &&
                        (booking.depositPaid > 0 ||
                            booking.isDepositPaid ||
                            booking.isPaid ||
                            booking.paymentStatus == 'pending')));

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
                      date: booking.formattedDate + ' - ' + booking.formattedTimeRange,
                    ),
                  ),
                ),
                const SizedBox(width: VSPSpacing.sm),
              ],
              Expanded(
                child: VSPAnimatedButton(
                  text: l10n.chat,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(booking: booking),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
          if (isHistory &&
              booking.bookingType == BookingType.challenge &&
              booking.opponentTeamId != null &&
              booking.endTime.isBefore(DateTime.now())) ...[
            const SizedBox(height: VSPSpacing.md),
            ChallengeResultActions(booking: booking, myTeamId: myTeamId),
          ],
        ],
      ),
    );
  }

  Widget _buildContactSupportRefundBadge(BuildContext context, bool isArabic) {
    return GestureDetector(
      onTap: () {
        final cleanRef = booking.id.length >= 8
            ? booking.id.substring(0, 8).toUpperCase()
            : booking.id.toUpperCase();
        final msg = isArabic
            ? 'مرحباً فريق دعم VSP، قمت بسداد حجز رقم #$cleanRef في ${booking.stadiumName} وتم إلغاء الحجز، وأحتاج المساعدة للتحقق من استرداد المبلغ.'
            : 'Hello VSP Support, I paid for booking #$cleanRef at ${booking.stadiumName} and the booking was cancelled. Please help verify my refund.';
        VSPLauncherUtils.openWhatsApp(context, phone: '201100229462', message: msg);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: VSPColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(VSPRadius.full),
          border: Border.all(
            color: VSPColors.warning.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Iconsax.message_question_copy,
              size: 13,
              color: VSPColors.warning,
            ),
            const SizedBox(width: 5),
            Text(
              isArabic ? 'تواصل معنا لاسترداد مبلغك' : 'Contact us for refund',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: VSPColors.warning,
              ),
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
            isArabic ? 'جاري الاسترداد البنكي...' : 'Bank refund processing...',
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
