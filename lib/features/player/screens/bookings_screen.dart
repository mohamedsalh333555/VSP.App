import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import 'chat_screen.dart';
import '../../../core/widgets/shimmer_image.dart';
import '../../../shared/widgets/vsp_animated_button.dart';
import '../../../shared/widgets/vsp_empty_state.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';
import '../../../shared/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/auth_provider.dart' as app_auth;
import '../../../data/models.dart';
import '../widgets/match_result_modal.dart';
import '../../../core/services/database_service.dart';

class BookedScreen extends StatefulWidget {
  const BookedScreen({super.key});

  @override
  State<BookedScreen> createState() => _BookedScreenState();
}

class _BookedScreenState extends State<BookedScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String? _myTeamId;

  Future<void> _loadData() async {
    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    
    final userId = authProvider.currentUser?.uid;
    if (userId != null) {
      bookingProvider.loadUserBookings(userId);
      final team = await DatabaseService().getUserTeam(userId);
      if (mounted) {
        setState(() => _myTeamId = team?.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        centerTitle: true,
        leading: Navigator.canPop(context) 
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios, matchTextDirection: true, color: VSPColors.textPrimary, size: 20),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          l10n.bookedTitle,
          style: Theme.of(context).textTheme.displayMedium,
        ),
      ),
      body: SafeArea(
        top: true,
        bottom: false,
        child: Selector<BookingProvider, ({List<Booking> upcoming, List<Booking> history, bool loading})>(
          selector: (_, provider) => (
            upcoming: provider.upcomingBookings,
            history: provider.historyBookings,
            loading: provider.isLoading,
          ),
          builder: (context, data, child) {
            if (data.loading) {
              return const Center(
                child: CircularProgressIndicator(color: VSPColors.accent),
              );
            }
  
            if (data.upcoming.isEmpty && data.history.isEmpty) {
              return RefreshIndicator(
                onRefresh: () async {
                  final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
                  final userId = authProvider.currentUser?.uid;
                  if (userId != null) {
                    Provider.of<BookingProvider>(context, listen: false).loadUserBookings(userId);
                    await Future.delayed(const Duration(seconds: 1));
                  }
                },
                color: VSPColors.accent,
                backgroundColor: VSPColors.surface,
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.7,
                      child: _buildEmptyState(),
                    ),
                  ),
                ),
              );
            }
  
            return RefreshIndicator(
              onRefresh: () async {
                final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
                final userId = authProvider.currentUser?.uid;
                if (userId != null) {
                  Provider.of<BookingProvider>(context, listen: false).loadUserBookings(userId);
                  await Future.delayed(const Duration(seconds: 1));
                }
              },
              color: VSPColors.accent,
              backgroundColor: VSPColors.surface,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, VSPSpacing.md, 16, MediaQuery.of(context).padding.bottom + 110),
                children: [
                if (data.upcoming.isNotEmpty) ...[
                  Text(
                    l10n.upcoming,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: VSPSpacing.md),
                  ...data.upcoming.asMap().entries.map((entry) {
                    final index = entry.key;
                    final booking = entry.value;
                    return VSPFadeInItem(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: VSPSpacing.md),
                        child: _BookingCard(
                          booking: booking, 
                          isHistory: false,
                          myTeamId: _myTeamId,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: VSPSpacing.lg),
                ],

                if (data.history.isNotEmpty) ...[
                  Text(
                    l10n.history,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: VSPSpacing.md),
                  ...data.history.asMap().entries.map((entry) {
                    final index = entry.key;
                    final booking = entry.value;
                    return VSPFadeInItem(
                      index: index + data.upcoming.length,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: VSPSpacing.md),
                        child: _BookingCard(
                          booking: booking, 
                          isHistory: true,
                          myTeamId: _myTeamId,
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          );
        },
      ),
    ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return VSPEmptyState(
      icon: Icons.calendar_today_outlined,
      title: l10n.noBookings,
      subtitle: l10n.noBookingsSubtitle,
      buttonText: l10n.exploreStadiums,
      onButtonPressed: () {
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final bool isHistory;
  final String? myTeamId;

  const _BookingCard({
    required this.booking,
    required this.isHistory,
    this.myTeamId,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: isHistory 
            ? VSPColors.surface 
            : const Color(0xFF2D4B15),
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
                          child: const Icon(Icons.stadium, color: VSPColors.accent),
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
                        if (booking.isPrivate) ...[
                          const SizedBox(width: VSPSpacing.sm),
                          _buildTag(l10n.private, color: VSPColors.warning),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              if (!isHistory) ...[
                _buildStatusBadge(l10n.confirmed, VSPColors.accent),
              ] else ...[
                if (booking.endTime.isAfter(DateTime.now()))
                  _buildStatusBadge(l10n.inProgress, VSPColors.accent)
                else if (booking.bookingType == BookingType.challenge)
                  _buildChallengeStatusBadge(context)
                else if (booking.status == BookingStatus.completed && (booking.matchResultStatus == MatchResultStatus.noResult || booking.matchResultStatus == MatchResultStatus.waitingOpponent))
                  _buildStatusBadge(l10n.submitResult, VSPColors.warning)
                else
                  _buildStatusBadge(l10n.completed, VSPColors.textSecondary),
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
                _buildInfoColumn(context, l10n.price, '${booking.totalPrice.toInt()} ${l10n.egCurrency}'),
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
                  const Icon(Icons.sports_soccer, color: VSPColors.warning, size: 20),
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

          if (!isHistory) ...[
            const SizedBox(height: VSPSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final bool canCancel = DateTime.now().isBefore(booking.startTime);
                      return VSPAnimatedButton(
                        text: l10n.cancel,
                        color: canCancel ? VSPColors.surface : VSPColors.surface.withValues(alpha: 0.5),
                        textColor: canCancel ? VSPColors.error : VSPColors.textSecondary,
                        onPressed: canCancel ? () => _showCancelDialog(context) : null,
                      );
                    }
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
                          builder: (context) => ChatScreen(booking: booking),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],

          if (isHistory && booking.bookingType == BookingType.challenge && booking.opponentTeamId != null &&
             booking.endTime.isBefore(DateTime.now())) ...[
            const SizedBox(height: VSPSpacing.md),
            _buildChallengeResultAction(context),
          ],
        ],
      ),
    );
  }

  String _getLocalizedBookingType(BuildContext context, BookingType type) {
    final l10n = AppLocalizations.of(context)!;
    switch (type) {
      case BookingType.personal:
        return l10n.personalType.toUpperCase();
      case BookingType.team:
        return l10n.teamType.toUpperCase();
      case BookingType.challenge:
        return l10n.challengeType.toUpperCase();
      default:
        return type.name.toUpperCase();
    }
  }

  Widget _buildChallengeResultAction(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentTeamId = myTeamId ?? booking.playerTeamId; 
    if (currentTeamId == null) return const SizedBox.shrink();
    
    if (booking.matchResultStatus == MatchResultStatus.noResult) {
      return _buildAddResultButton(context, currentTeamId, isPrimaryPopping: true);
    } else if (booking.matchResultStatus == MatchResultStatus.waitingOpponent) {
      if (booking.resultSubmittedByTeamId == currentTeamId) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(
            l10n.waitingOpponent,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: VSPColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      } else {
        return _buildAddResultButton(context, currentTeamId, isPrimaryPopping: true);
      }
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildAddResultButton(BuildContext context, String currentTeamId, {bool isPrimaryPopping = false}) {
    final l10n = AppLocalizations.of(context)!;
    return VSPAnimatedButton(
      text: l10n.addResult,
      color: isPrimaryPopping ? VSPColors.warning : VSPColors.accent,
      textColor: isPrimaryPopping ? Colors.black : VSPColors.textPrimary,
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => MatchResultModal(
            booking: booking,
            submittingTeamId: currentTeamId,
            onConfirm: (outcome, rating, review) async {
              final provider = Provider.of<BookingProvider>(context, listen: false);
              
              final success = await provider.submitMatchResult(
                bookingId: booking.id,
                teamId: currentTeamId,
                outcome: outcome,
                rating: rating,
                review: review,
              );

              if (!context.mounted) return;
              
              if (success) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.resultSuccess),
                    backgroundColor: VSPColors.accent,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(provider.errorMessage ?? l10n.resultFailed),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildChallengeStatusBadge(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentTeamId = myTeamId ?? booking.playerTeamId;
    if (currentTeamId == null) return const SizedBox.shrink();

    final isHome = currentTeamId == booking.playerTeamId;
    final isAway = currentTeamId == booking.opponentTeamId;
    
    if (!isHome && !isAway) return const SizedBox.shrink();

    if (booking.matchResultStatus == MatchResultStatus.confirmed) {
      final outcome = booking.finalOutcome;
      if (outcome == MatchOutcome.draw) {
        return _buildStatusBadge(l10n.draw, Colors.blue);
      } else if (outcome == MatchOutcome.homeWin) {
        final isWon = isHome;
        return _buildStatusBadge(isWon ? l10n.win : l10n.loss, isWon ? Colors.amber : Colors.red);
      } else if (outcome == MatchOutcome.awayWin) {
        final isWon = isAway;
        return _buildStatusBadge(isWon ? l10n.win : l10n.loss, isWon ? Colors.amber : Colors.red);
      }
    } else if (booking.matchResultStatus == MatchResultStatus.disputed) {
      return _buildStatusBadge(l10n.disputed, VSPColors.warning);
    } else if (booking.endTime.isBefore(DateTime.now())) {
      return _buildStatusBadge(l10n.submitResult, VSPColors.warning);
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildTag(String text, {Color color = VSPColors.accent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.sm, vertical: VSPSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
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
      return '$start-$end';
    }
    return timeRange;
  }

  void _showCancelDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VSPColors.surface,
        title: Text(
          l10n.cancelBooking,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Text(
          l10n.cancelBookingConfirm,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
        actions: [
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  text: l10n.keepBooking,
                  height: 48,
                  color: VSPColors.surfaceAlt,
                  textColor: VSPColors.textPrimary,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: VSPSpacing.md),
              Expanded(
                child: PrimaryButton(
                  text: l10n.cancel,
                  height: 48,
                  color: VSPColors.error,
                  textColor: VSPColors.background,
                  onPressed: () async {
                    final provider = Provider.of<BookingProvider>(context, listen: false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.cancelling),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                    Navigator.pop(context);
                    final success = await provider.cancelBooking(booking.id);
                    if (!context.mounted) return;
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.cancelSuccess),
                          backgroundColor: VSPColors.warning,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(
                          content: Text(provider.errorMessage ?? l10n.cancelFailed),
                          backgroundColor: VSPColors.error,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
