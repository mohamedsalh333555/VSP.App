
import 'package:cached_network_image/cached_network_image.dart';
// ignore_for_file: unnecessary_brace_in_string_interps

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/auth_provider.dart' as app_auth;
import '../../../../core/repositories/match_repository.dart';
import '../../../../core/services/sharing_service.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../core/widgets/shimmer_image.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/match_card/manage_participants_modal.dart';
import '../../../../shared/widgets/vsp_animated_button.dart';
import '../../screens/chat_screen.dart';
import '../../screens/match_details_screen.dart';
import 'player_booking_cancel_dialog.dart';
import 'reschedule_action_banner.dart';

/// Dedicated My Bookings presentation for Open Join matches.
/// PublicMatchCard remains the discovery/manage surface for public match feeds.
class OpenJoinBookingCard extends StatefulWidget {
  final Booking booking;
  final bool isHistory;

  const OpenJoinBookingCard({
    super.key,
    required this.booking,
    required this.isHistory,
  });

  @override
  State<OpenJoinBookingCard> createState() => _OpenJoinBookingCardState();
}

class _OpenJoinBookingCardState extends State<OpenJoinBookingCard> {
  bool _isProcessing = false;

  bool get _isEnded => widget.booking.endTime.isBefore(DateTime.now());

  Future<void> _leaveMatch(String userId) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final success = await MatchRepository().leavePublicMatch(widget.booking.id, userId);
      if (!mounted) return;
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      if (success) {
        VSPFeedback.showSuccess(context, isArabic ? 'تم خروجك من المباراة بنجاح.' : 'You left the match successfully.');
      } else {
        VSPFeedback.showError(context, AppLocalizations.of(context)!.leaveFailed);
      }
    } catch (e) {
      if (mounted) VSPFeedback.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _cancelJoinRequest(String userId) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final success = await MatchRepository().rejectJoinRequest(widget.booking.id, userId);
      if (!mounted) return;
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      if (success) {
        VSPFeedback.showSuccess(context, isArabic ? 'تم إلغاء طلب الانضمام.' : 'Join request cancelled.');
      } else {
        VSPFeedback.showError(context, AppLocalizations.of(context)!.leaveFailed);
      }
    } catch (e) {
      if (mounted) VSPFeedback.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _openDetails() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => MatchDetailsScreen(bookingId: widget.booking.id),
    ));
  }

  void _openChat() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChatScreen(booking: widget.booking),
    ));
  }

  void _shareMatch() {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    SharingService.shareMatch(
      bookingId: widget.booking.id,
      teamName: widget.booking.playerTeamName ??
          widget.booking.hostName ??
          (isArabic ? 'مباراة تجميعية' : 'Open Join Match'),
      stadiumName: widget.booking.stadiumName,
      date: '${widget.booking.formattedDate} - ${widget.booking.formattedTimeRange}',
    );
  }

  bool _canHostCancel() {
    final now = DateTime.now();
    final deadline = widget.booking.startTime.subtract(const Duration(hours: 6));
    final grace = now.difference(widget.booking.createdAt).inMinutes <= 20 &&
        !now.isAfter(widget.booking.startTime);
    return !now.isAfter(widget.booking.startTime) &&
        (now.isBefore(deadline) || grace);
  }

  Widget _statusPill(String text, Color color) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(VSPRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Flexible(child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
          )),
        ],
      ),
    );
  }

  Widget _infoCell(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: VSPColors.accent),
          const SizedBox(height: 4),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 9, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              style: const TextStyle(color: VSPColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final currentUser = context.select((app_auth.AuthProvider a) => a.currentUser);
    final userId = currentUser?.uid;
    final isHost = userId != null && booking.createdByUserId == userId;
    final hasJoined = userId != null && booking.joinedUserIds.contains(userId);
    final isPending = userId != null && booking.pendingUserIds.contains(userId);

    final totalCapacity = booking.totalFieldCapacity > 0 ? booking.totalFieldCapacity : 1;
    final currentPlayers = booking.currentPlayers.clamp(0, totalCapacity);
    final remaining = (totalCapacity - currentPlayers).clamp(0, totalCapacity);
    final progress = (currentPlayers / totalCapacity).clamp(0.0, 1.0);
    final entryFee = (booking.totalPrice / totalCapacity).round();

    Color statusColor;
    String statusText;
    if (booking.status == BookingStatus.cancelled) {
      statusColor = VSPColors.error;
      statusText = isArabic ? 'المباراة ملغاة' : 'Match cancelled';
    } else if (_isEnded || widget.isHistory) {
      statusColor = VSPColors.textSecondary;
      statusText = isArabic ? 'انتهت المباراة' : 'Match ended';
    } else if (isHost) {
      statusColor = VSPColors.accent;
      statusText = isArabic ? 'أنت المنظّم' : 'You are the host';
    } else if (hasJoined) {
      statusColor = VSPColors.info;
      statusText = isArabic ? 'أنت منضم للمباراة' : 'You joined';
    } else if (isPending) {
      statusColor = VSPColors.warning;
      statusText = isArabic ? 'طلبك قيد المراجعة' : 'Join request pending';
    } else {
      statusColor = VSPColors.success;
      statusText = isArabic ? 'مفتوحة للانضمام' : 'Open to join';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(VSPRadius.card),
        onTap: _openDetails,
        child: Ink(
          padding: const EdgeInsets.all(VSPSpacing.md),
          decoration: BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.circular(VSPRadius.card),
            border: Border.all(
              color: booking.status == BookingStatus.cancelled
                  ? VSPColors.error.withValues(alpha: 0.25)
                  : VSPColors.accent.withValues(alpha: 0.18),
            ),
            boxShadow: const [VSPShadow.subtle],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.sm, vertical: 6),
                    decoration: BoxDecoration(
                      color: VSPColors.accent.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(VSPRadius.full),
                      border: Border.all(color: VSPColors.accent.withValues(alpha: 0.30)),
                    ),
                    child: Text(
                      isArabic ? 'تجميعي' : 'OPEN JOIN',
                      style: const TextStyle(color: VSPColors.accent, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: VSPSpacing.sm),
                  if (booking.isPrivate)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.sm, vertical: 6),
                      decoration: BoxDecoration(
                        color: VSPColors.warning.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(VSPRadius.full),
                        border: Border.all(color: VSPColors.warning.withValues(alpha: 0.28)),
                      ),
                      child: Text(l10n.private,
                          style: const TextStyle(color: VSPColors.warning, fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                  const Spacer(),
                  _statusPill(statusText, statusColor),
                ],
              ),
              const SizedBox(height: VSPSpacing.md),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    child: SizedBox(
                      width: 62,
                      height: 62,
                      child: booking.stadiumImageUrl.isNotEmpty
                          ? ShimmerImage(imageUrl: booking.stadiumImageUrl, width: 62, height: 62, fit: BoxFit.cover)
                          : Container(
                              color: VSPColors.surfaceAlt,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: VSPColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isArabic
                              ? 'مباراة تجميعية • ${booking.hostName ?? 'المنظّم'}'
                              : 'Open Join • ${booking.hostName ?? 'Host'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  if (booking.hostAvatarUrl?.isNotEmpty == true)
                    ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: booking.hostAvatarUrl!,
                        width: 34,
                        height: 34,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const CircleAvatar(
                          radius: 17,
                          backgroundColor: VSPColors.surfaceAlt,
                          child: Icon(Iconsax.user_copy, size: 17, color: VSPColors.accent),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: VSPSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.sm, vertical: VSPSpacing.md),
                decoration: BoxDecoration(
                  color: VSPColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                ),
                child: Row(
                  children: [
                    _infoCell(isArabic ? 'التاريخ' : 'DATE', booking.formattedDate, Iconsax.calendar_1_copy),
                    Container(width: 1, height: 34, color: VSPColors.divider),
                    _infoCell(isArabic ? 'الوقت' : 'TIME', booking.formattedTimeRange, Iconsax.clock_copy),
                    Container(width: 1, height: 34, color: VSPColors.divider),
                    _infoCell(isArabic ? 'رسوم الفرد' : 'PER PLAYER',
                        '${entryFee} ${l10n.egCurrency}', Iconsax.wallet_1_copy),
                  ],
                ),
              ),
              const SizedBox(height: VSPSpacing.md),
              Row(
                children: [
                  const Icon(Iconsax.profile_2user_copy, size: 16, color: VSPColors.accent),
                  const SizedBox(width: VSPSpacing.sm),
                  Expanded(
                    child: Text(
                      isArabic
                          ? '${currentPlayers} من ${totalCapacity} لاعب • ${remaining > 0 ? 'متبقي ${remaining} أماكن' : 'اكتمل العدد'}'
                          : '${currentPlayers} of ${totalCapacity} players • ${remaining} spots left',
                      style: const TextStyle(color: VSPColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text('${(progress * 100).round()}%',
                      style: const TextStyle(color: VSPColors.accent, fontSize: 11, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: VSPSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(VSPRadius.full),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: VSPColors.divider.withValues(alpha: 0.35),
                  valueColor: const AlwaysStoppedAnimation<Color>(VSPColors.accent),
                ),
              ),
              if (booking.rescheduleStatus == 'pending' && booking.proposedStartTime != null) ...[
                const SizedBox(height: VSPSpacing.md),
                RescheduleActionBanner(booking: booking),
              ],
              const SizedBox(height: VSPSpacing.md),
              if (widget.isHistory || _isEnded || booking.status == BookingStatus.cancelled) ...[
                Row(
                  children: [
                    Expanded(
                      child: VSPAnimatedButton(
                        text: isArabic ? 'تفاصيل المباراة' : 'Match details',
                        color: VSPColors.accent,
                        textColor: Colors.black,
                        onPressed: _openDetails,
                      ),
                    ),
                    if (booking.status != BookingStatus.cancelled) ...[
                      const SizedBox(width: VSPSpacing.sm),
                      Expanded(
                        child: VSPAnimatedButton(
                          text: isArabic ? 'مشاركة' : 'Share',
                          color: VSPColors.surfaceAlt,
                          textColor: VSPColors.textPrimary,
                          onPressed: _shareMatch,
                        ),
                      ),
                    ],
                  ],
                ),
              ] else if (isHost) ...[
                Row(
                  children: [
                    Expanded(
                      child: VSPAnimatedButton(
                        text: isArabic ? 'إدارة اللاعبين' : 'Manage players',
                        color: VSPColors.accent,
                        textColor: Colors.black,
                        onPressed: () => ManageParticipantsModal.show(context, booking: booking),
                      ),
                    ),
                    const SizedBox(width: VSPSpacing.sm),
                    Expanded(
                      child: VSPAnimatedButton(
                        text: l10n.chat,
                        color: VSPColors.surfaceAlt,
                        textColor: VSPColors.textPrimary,
                        onPressed: _openChat,
                      ),
                    ),
                  ],
                ),
                if (_canHostCancel()) ...[
                  const SizedBox(height: VSPSpacing.sm),
                  VSPAnimatedButton(
                    text: isArabic ? 'إلغاء المباراة' : 'Cancel match',
                    color: VSPColors.error.withValues(alpha: 0.12),
                    textColor: VSPColors.error,
                    onPressed: _isProcessing ? null : () => PlayerBookingCancelDialog.show(context, booking),
                  ),
                ],
              ] else if (hasJoined) ...[
                Row(
                  children: [
                    Expanded(
                      child: VSPAnimatedButton(
                        text: l10n.chat,
                        color: VSPColors.surfaceAlt,
                        textColor: VSPColors.textPrimary,
                        onPressed: _openChat,
                      ),
                    ),
                    const SizedBox(width: VSPSpacing.sm),
                    Expanded(
                      child: VSPAnimatedButton(
                        text: l10n.leave,
                        color: VSPColors.error.withValues(alpha: 0.12),
                        textColor: VSPColors.error,
                        onPressed: _isProcessing ? null : () => _leaveMatch(userId),
                      ),
                    ),
                  ],
                ),
              ] else if (isPending) ...[
                Row(
                  children: [
                    Expanded(
                      child: VSPAnimatedButton(
                        text: isArabic ? 'إلغاء الطلب' : 'Cancel request',
                        color: VSPColors.error.withValues(alpha: 0.12),
                        textColor: VSPColors.error,
                        onPressed: _isProcessing ? null : () => _cancelJoinRequest(userId),
                      ),
                    ),
                    const SizedBox(width: VSPSpacing.sm),
                    Expanded(
                      child: VSPAnimatedButton(
                        text: l10n.chat,
                        color: VSPColors.surfaceAlt,
                        textColor: VSPColors.textPrimary,
                        onPressed: _openChat,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                VSPAnimatedButton(
                  text: isArabic ? 'تفاصيل المباراة' : 'Match details',
                  color: VSPColors.accent,
                  textColor: Colors.black,
                  onPressed: _openDetails,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
