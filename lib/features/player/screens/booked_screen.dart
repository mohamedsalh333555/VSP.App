import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/widgets/shimmer_image.dart';
import '../../../shared/widgets/vsp_animated_button.dart';
import '../../../shared/widgets/vsp_empty_state.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';
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
    // Load bookings when screen initializes
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
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        centerTitle: true,
        leading: Navigator.canPop(context) 
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: VSPColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          'Booked',
          style: Theme.of(context).textTheme.displayMedium,
        ),
      ),
      body: Selector<BookingProvider, ({List<Booking> upcoming, List<Booking> history, bool loading})>(
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
                  await Future.delayed(const Duration(seconds: 1)); // Give stream time to emit
                }
              },
              color: VSPColors.accent,
              backgroundColor: VSPColors.surface,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: _buildEmptyState(),
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
                await Future.delayed(const Duration(seconds: 1)); // Give stream time to emit
              }
            },
            color: VSPColors.accent,
            backgroundColor: VSPColors.surface,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(), // Ensures scrolling even if empty
              padding: EdgeInsets.fromLTRB(VSPSpacing.md, VSPSpacing.md, VSPSpacing.md, MediaQuery.of(context).padding.bottom + 110),
              children: [
                // Upcoming Section
                if (data.upcoming.isNotEmpty) ...[
                  Text(
                    'Upcoming',
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

                // History Section
                if (data.history.isNotEmpty) ...[
                  Text(
                    'History',
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
    );
  }

  Widget _buildEmptyState() {
    return VSPEmptyState(
      icon: Icons.calendar_today_outlined,
      title: 'No Bookings Yet',
      subtitle: 'Book a stadium or join a match to see your schedule here!',
      buttonText: 'Explore Stadiums',
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: isHistory 
            ? VSPColors.surface 
            : const Color(0xFF2D4B15), // Deep Forest Green
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        boxShadow: VSPShadow.subtle,
      ),
      child: Column(
        children: [
          // Header: Stadium Image + Info + Actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Stadium Image
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
              
              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.stadiumName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: VSPSpacing.xs),
                    Row(
                      children: [
                        _buildTag(booking.bookingType.name.toUpperCase()),
                        if (booking.isPrivate) ...[
                          const SizedBox(width: VSPSpacing.sm),
                          _buildTag('PRIVATE', color: VSPColors.warning),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Status or Actions
              if (!isHistory) ...[
                _buildStatusBadge('Confirmed', VSPColors.accent),
              ] else ...[
                if (booking.bookingType == BookingType.challenge)
                  _buildChallengeStatusBadge()
                else if (booking.status == BookingStatus.completed && (booking.matchResultStatus == MatchResultStatus.noResult || booking.matchResultStatus == MatchResultStatus.waitingOpponent))
                  _buildStatusBadge('Submit Result', VSPColors.warning)
                else
                  _buildStatusBadge('Completed', VSPColors.textSecondary),
              ],
            ],
          ),

          const SizedBox(height: VSPSpacing.md),
          
          // Info Grid
          Container(
            padding: const EdgeInsets.symmetric(vertical: VSPSpacing.sm, horizontal: VSPSpacing.md),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoColumn('Date', booking.formattedDate),
                Container(width: 1, height: 24, color: Colors.white.withValues(alpha: 0.1)),
                _buildInfoColumn('Time', _formatTimeShort(booking.formattedTimeRange)),
                Container(width: 1, height: 24, color: Colors.white.withValues(alpha: 0.1)),
                _buildInfoColumn('Price', '${booking.totalPrice.toInt()} ${booking.currency}'),
              ],
            ),
          ),

          // Challenge Info (if applicable)
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
                  const Icon(Icons.sports_soccer, color: Colors.orange, size: 20),
                  const SizedBox(width: VSPSpacing.sm),
                  Text(
                    'VS ${booking.opponentTeamName}',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Actions for upcoming bookings
          if (!isHistory) ...[
            const SizedBox(height: VSPSpacing.md),
            Row(
              children: [
                Expanded(
                  child: VSPAnimatedButton(
                    text: 'Cancel',
                    color: VSPColors.surface,
                    textColor: VSPColors.error,
                    onPressed: () {
                      _showCancelDialog(context);
                    },
                  ),
                ),
                const SizedBox(width: VSPSpacing.sm),
                Expanded(
                  child: VSPAnimatedButton(
                    text: 'Share',
                    onPressed: () {
                      // Share or view details
                    },
                  ),
                ),
              ],
            ),
          ],

          // Result button/status for history (challenge type ONLY and valid opponent)
          if (isHistory && booking.bookingType == BookingType.challenge && booking.opponentTeamId != null &&
             (booking.status == BookingStatus.completed || booking.endTime.isBefore(DateTime.now()))) ...[
            const SizedBox(height: VSPSpacing.md),
            _buildChallengeResultAction(context),
          ],
        ],
      ),
    );
  }

  Widget _buildChallengeResultAction(BuildContext context) {
    // Determine current user's team ID safely.
    final currentTeamId = myTeamId ?? booking.playerTeamId ?? 'team_1'; 
    
    if (booking.matchResultStatus == MatchResultStatus.noResult) {
      return _buildAddResultButton(context, currentTeamId);
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
            'Waiting for opponent result...',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: VSPColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      } else {
        return _buildAddResultButton(context, currentTeamId);
      }
    } else if (booking.matchResultStatus == MatchResultStatus.confirmed) {
      return const SizedBox.shrink(); // Badge already shown in header or skipped for confirmed
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildAddResultButton(BuildContext context, String currentTeamId) {
    return VSPAnimatedButton(
      text: 'Add Result',
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
                  const SnackBar(
                    content: Text('Result Submitted Successfully!'),
                    backgroundColor: VSPColors.accent,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(provider.errorMessage ?? 'Failed to submit result'),
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

  Widget _buildChallengeStatusBadge() {
    final currentTeamId = booking.playerTeamId ?? 'team_1';
    final isHome = currentTeamId == booking.playerTeamId;

    if (booking.matchResultStatus == MatchResultStatus.confirmed) {
      final outcome = booking.finalOutcome;
      if (outcome == MatchOutcome.draw) {
        return _buildStatusBadge('Draw', Colors.blue);
      } else if (outcome == MatchOutcome.homeWin) {
        return _buildStatusBadge(isHome ? 'Win' : 'Loss', isHome ? Colors.amber : Colors.red);
      } else if (outcome == MatchOutcome.awayWin) {
        return _buildStatusBadge(isHome ? 'Loss' : 'Win', isHome ? Colors.red : Colors.amber);
      }
    } else if (booking.matchResultStatus == MatchResultStatus.disputed) {
      return _buildStatusBadge('Disputed', VSPColors.warning);
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

  Widget _buildInfoColumn(String label, String value) {
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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatTimeShort(String timeRange) {
    // Shorten time range for display
    final parts = timeRange.split(' - ');
    if (parts.length == 2) {
      final start = parts[0].replaceAll(':00', '');
      final end = parts[1].replaceAll(':00', '');
      return '$start-$end';
    }
    return timeRange;
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VSPColors.surface,
        title: Text(
          'Cancel Booking?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Text(
          'Are you sure you want to cancel this booking? This action cannot be undone.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Keep Booking', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: VSPColors.textSecondary)),
          ),
          VSPAnimatedButton(
            text: 'Cancel Booking',
            color: Colors.red,
            textColor: Colors.white,
            onPressed: () async {
              // Cancel booking
              final provider = Provider.of<BookingProvider>(context, listen: false);
              
              // Show quick loading snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cancelling booking...'),
                  duration: Duration(seconds: 1),
                ),
              );
              
              Navigator.pop(context); // Close dialog

              final success = await provider.cancelBooking(booking.id);
              
              if (!context.mounted) return;
              
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Booking cancelled successfully'),
                    backgroundColor: VSPColors.warning,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(
                    content: Text(provider.errorMessage ?? 'Failed to cancel'),
                    backgroundColor: VSPColors.error,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
