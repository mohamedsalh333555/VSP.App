import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/widgets/shimmer_image.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/vsp_animated_button.dart';
import '../../screens/chat_screen.dart';
import '../../screens/matchup_live_dashboard_screen.dart';
import 'challenge_result_actions.dart';
import 'player_booking_cancel_dialog.dart';
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
        color: isHistory ? VSPColors.surface : const Color(0xFF2D4B15),
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        boxShadow: VSPShadow.subtle,
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
                ChallengeResultActions.buildStatusBadge(isArabic ? 'ملغي' : 'Cancelled', Colors.red),
              ] else if (booking.status == BookingStatus.pending && !booking.isPaid) ...[
                ChallengeResultActions.buildStatusBadge(isArabic ? 'بانتظار السداد ⏳' : 'Pending Payment ⏳', Colors.amber),
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
                      final deadline = booking.startTime.subtract(const Duration(hours: 2));
                      final bool canCancel = DateTime.now().isBefore(deadline);
                      final bool bookingStarted = DateTime.now().isAfter(booking.startTime);
                      final String lockedLabel = bookingStarted
                          ? (isArabic ? 'بدأ الحجز' : 'Booking started')
                          : (isArabic ? 'لا يمكن الإلغاء (أقل من ساعتين)' : 'Cannot cancel (< 2 hrs left)');
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
                const SizedBox(width: VSPSpacing.sm),
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
}
