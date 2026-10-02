import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart' as app_auth;
import '../../../../core/providers/booking_provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/ui/vsp_ui.dart';
import '../../../../core/utils/app_date_formatter.dart';
import '../../../../core/widgets/shimmer_image.dart';
import '../../../../data/models.dart';
import '../../screens/match_details_screen.dart';

/// Dedicated presentation for Open Join matches inside My Bookings.
/// It treats the booking as a match: participation and capacity come first.
class OpenJoinBookingCard extends StatelessWidget {
  final Booking booking;
  final bool isHistory;

  const OpenJoinBookingCard({
    super.key,
    required this.booking,
    required this.isHistory,
  });

  int get _capacity => booking.totalFieldCapacity > 0
      ? booking.totalFieldCapacity
      : booking.maxPlayers;

  int get _currentPlayers {
    final joined = booking.joinedUserIds.length;
    return joined > 0 ? joined : booking.currentPlayers.clamp(0, _capacity);
  }

  double get _perPlayerFee =>
      _capacity > 0 ? booking.totalPrice / _capacity : 0;

  String _date(BuildContext context) => AppDateFormatter.formatDayMonth(
        booking.startTime,
        Localizations.localeOf(context).languageCode,
      );

  String _time(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final start = booking.startTime.toLocal();
    final end = booking.endTime.toLocal();

    String one(DateTime value) {
      final h = value.hour == 0 ? 12 : (value.hour > 12 ? value.hour - 12 : value.hour);
      final suffix = ar ? (value.hour >= 12 ? 'م' : 'ص') : (value.hour >= 12 ? 'PM' : 'AM');
      return value.minute == 0
          ? '\$h \$suffix'
          : '\$h:\${value.minute.toString().padLeft(2, '0')} \$suffix';
    }

    return '\${one(start)} - \${one(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final auth = context.watch<app_auth.AuthProvider>();
    final userId = auth.currentUser?.uid;
    final joined = userId != null && booking.joinedUserIds.contains(userId);
    final isHost = userId != null && booking.createdByUserId == userId;
    final current = _currentPlayers;
    final remaining = (_capacity - current).clamp(0, _capacity);
    final isCancelled = booking.status == BookingStatus.cancelled;
    final isEnded = isHistory || booking.endTime.isBefore(DateTime.now());
    final isFull = current >= _capacity;

    final Color stateColor = isCancelled
        ? VSPColors.error
        : isEnded
            ? VSPColors.textSecondary
            : joined || isHost
                ? VSPColors.accent
                : isFull
                    ? VSPColors.textSecondary
                    : VSPColors.success;

    final String stateLabel = isCancelled
        ? (ar ? 'ملغاة' : 'Cancelled')
        : isEnded
            ? (ar ? 'انتهت' : 'Completed')
            : isHost
                ? (ar ? 'أنت المضيف' : 'You host')
                : joined
                    ? (ar ? 'أنت مشارك' : 'You joined')
                    : isFull
                        ? (ar ? 'مكتملة' : 'Full')
                        : (ar ? 'مفتوحة للانضمام' : 'Open to join');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(VSPRadius.card),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MatchDetailsScreen(bookingId: booking.id),
          ),
        ),
        child: Ink(
          padding: const EdgeInsets.all(VSPSpacing.md),
          decoration: BoxDecoration(
            color: isHistory ? VSPColors.surface : VSPColors.surfaceAlt,
            borderRadius: BorderRadius.circular(VSPRadius.card),
            border: Border.all(color: stateColor.withValues(alpha: 0.30)),
            boxShadow: const [VSPShadow.subtle],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: VSPColors.surface,
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      border: Border.all(color: VSPColors.divider),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      child: booking.stadiumImageUrl.isNotEmpty
                          ? ShimmerImage(
                              imageUrl: booking.stadiumImageUrl,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            )
                          : const Center(
                              child: Icon(Icons.groups_rounded, color: VSPColors.accent),
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
                                color: VSPColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: VSPSpacing.xs),
                        Row(
                          children: [
                            const Icon(Icons.groups_rounded, size: 16, color: VSPColors.accent),
                            const SizedBox(width: VSPSpacing.xs),
                            Text(
                              ar ? 'مباراة تجميعية' : 'Open Join Match',
                              style: const TextStyle(
                                color: VSPColors.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  VSPStatusPill(label: stateLabel, color: stateColor),
                ],
              ),
              const SizedBox(height: VSPSpacing.md),
              Container(
                padding: const EdgeInsets.all(VSPSpacing.md),
                decoration: BoxDecoration(
                  color: VSPColors.background.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(VSPRadius.input),
                  border: Border.all(color: VSPColors.divider.withValues(alpha: 0.45)),
                ),
                child: Row(
                  children: [
                    Expanded(child: _InfoItem(icon: Icons.calendar_today_rounded, label: ar ? 'التاريخ' : 'DATE', value: _date(context))),
                    const _InfoDivider(),
                    Expanded(child: _InfoItem(icon: Icons.schedule_rounded, label: ar ? 'الوقت' : 'TIME', value: _time(context))),
                    const _InfoDivider(),
                    Expanded(child: _InfoItem(icon: Icons.payments_outlined, label: ar ? 'للفرد' : 'PER PLAYER', value: '\${_perPlayerFee.toStringAsFixed(0)} \${ar ? 'ج.م' : 'EGP'}')),
                  ],
                ),
              ),
              const SizedBox(height: VSPSpacing.md),
              Row(
                children: [
                  const Icon(Icons.people_alt_outlined, size: 18, color: VSPColors.accent),
                  const SizedBox(width: VSPSpacing.xs),
                  Text(
                    ar ? 'المشاركون' : 'Players',
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(
                    '\$current / \$_capacity',
                    style: const TextStyle(color: VSPColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: VSPSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(VSPRadius.full),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value: _capacity > 0 ? (current / _capacity).clamp(0.0, 1.0) : 0,
                  backgroundColor: VSPColors.divider.withValues(alpha: 0.30),
                  color: stateColor,
                ),
              ),
              const SizedBox(height: VSPSpacing.xs),
              Text(
                remaining > 0 && !isEnded && !isCancelled
                    ? (ar ? 'متبقي \$remaining مكان' : '\$remaining spots left')
                    : (ar ? 'المباراة مكتملة' : 'Match is full'),
                style: TextStyle(color: stateColor, fontSize: 11, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: VSPSpacing.md),
              _Action(
                label: isEnded || isCancelled
                    ? (ar ? 'انتهت المباراة' : 'Match ended')
                    : joined
                        ? (ar ? 'خروج' : 'Leave')
                        : (ar ? 'انضمام' : 'Join'),
                destructive: joined && !isEnded && !isCancelled,
                enabled: !isEnded && !isCancelled && (joined || (!isFull && userId != null)) && !isHost,
                onPressed: userId == null || isHost || isEnded || isCancelled
                    ? null
                    : () async {
                        final provider = context.read<BookingProvider>();
                        if (joined) {
                          await provider.leavePublicMatch(booking.id, userId);
                        } else {
                          await provider.joinPublicMatch(booking.id, userId);
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, size: 16, color: VSPColors.accent),
          const SizedBox(height: VSPSpacing.xs),
          Text(label, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
          const SizedBox(height: VSPSpacing.xs),
          Text(value, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: VSPColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      );
}

class _InfoDivider extends StatelessWidget {
  const _InfoDivider();

  @override
  Widget build(BuildContext context) => Container(width: 1, height: 42, color: VSPColors.divider.withValues(alpha: 0.45));
}

class _Action extends StatelessWidget {
  final String label;
  final bool destructive;
  final bool enabled;
  final VoidCallback? onPressed;

  const _Action({required this.label, required this.destructive, required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: enabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(VSPSize.buttonHeight),
            foregroundColor: destructive ? VSPColors.error : VSPColors.accent,
            side: BorderSide(color: (destructive ? VSPColors.error : VSPColors.accent).withValues(alpha: 0.65)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.full)),
          ),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      );
}