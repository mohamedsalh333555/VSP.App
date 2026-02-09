import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shimmer_image.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../data/models.dart';
import '../widgets/match_result_modal.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
      bookingProvider.loadUserBookings('demo_user'); // Use actual user ID in production
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        centerTitle: true,
        leading: Navigator.canPop(context) 
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          'Booked',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Consumer<BookingProvider>(
        builder: (context, bookingProvider, child) {
          if (bookingProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.neonGreen),
            );
          }

          final upcomingBookings = bookingProvider.upcomingBookings;
          final historyBookings = bookingProvider.historyBookings;

          if (upcomingBookings.isEmpty && historyBookings.isEmpty) {
            return _buildEmptyState();
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Upcoming Section
              if (upcomingBookings.isNotEmpty) ...[
                const Text(
                  'Upcoming',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...upcomingBookings.map((booking) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _BookingCard(booking: booking, isHistory: false),
                )),
                const SizedBox(height: 24),
              ],

              // History Section
              if (historyBookings.isNotEmpty) ...[
                const Text(
                  'History',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...historyBookings.map((booking) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _BookingCard(booking: booking, isHistory: true),
                )),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today,
            size: 80,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Bookings Yet',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Book a stadium to get started!',
            style: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.neonGreen,
              foregroundColor: AppTheme.darkBackground,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Explore Stadiums',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final bool isHistory;

  const _BookingCard({
    required this.booking,
    required this.isHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHistory 
            ? AppTheme.cardBackground 
            : const Color(0xFF2D4B15), // Premium Deep Green for upcoming
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3), 
            blurRadius: 10, 
            offset: const Offset(0, 4),
          ),
        ],
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
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: booking.stadiumImageUrl.isNotEmpty
                      ? ShimmerImage(
                          imageUrl: booking.stadiumImageUrl,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: AppTheme.cardBackground,
                          child: const Icon(Icons.stadium, color: AppTheme.neonGreen),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              
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
                        fontFamily: 'Agency FB',
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildTag(booking.bookingType.name.toUpperCase()),
                        if (booking.isPrivate) ...[
                          const SizedBox(width: 8),
                          _buildTag('PRIVATE', color: Colors.orange),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Status or Actions
              if (!isHistory) ...[
                _buildStatusBadge('Confirmed', AppTheme.neonGreen),
              ] else ...[
                if (booking.bookingType == BookingType.challenge)
                  _buildChallengeStatusBadge()
                else
                  _buildStatusBadge('Completed', Colors.grey),
              ],
            ],
          ),

          const SizedBox(height: 16),
          
          // Info Grid
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sports_soccer, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Cancel booking logic
                      _showCancelDialog(context);
                    },
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Share or view details
                    },
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.neonGreen,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Result button/status for history (challenge type)
          if (isHistory && booking.bookingType == BookingType.challenge) ...[
            const SizedBox(height: 16),
            _buildChallengeResultAction(context),
          ],
        ],
      ),
    );
  }

  Widget _buildChallengeResultAction(BuildContext context) {
    // Determine current user's team ID. 
    // In this context, we assume the user viewing is the one who created the booking (Team A)
    // or the opponent (Team B). 
    // For simplicity in demo, we check if current user is creator.
    final currentTeamId = booking.playerTeamId ?? 'team_1'; 
    
    if (booking.matchResultStatus == MatchResultStatus.noResult) {
      return _buildAddResultButton(context);
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
          child: const Text(
            'Waiting for opponent result...',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      } else {
        return _buildAddResultButton(context);
      }
    } else if (booking.matchResultStatus == MatchResultStatus.confirmed) {
      return const SizedBox.shrink(); // Badge already shown in header or skipped for confirmed
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildAddResultButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => MatchResultModal(
              booking: booking,
              onConfirm: (outcome) async {
                final provider = Provider.of<BookingProvider>(context, listen: false);
                final currentTeamId = booking.playerTeamId ?? 'team_1';
                
                final success = await provider.submitMatchResult(
                  bookingId: booking.id,
                  teamId: currentTeamId,
                  outcome: outcome,
                );

                if (!context.mounted) return;
                
                if (success) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Result Submitted Successfully!'),
                      backgroundColor: AppTheme.neonGreen,
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
        icon: const Icon(Icons.add, size: 18),
        label: const Text(
          'Add Result',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.neonGreen,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
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
      return _buildStatusBadge('Disputed', Colors.orange);
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildTag(String text, {Color color = AppTheme.neonGreen}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
        const SizedBox(height: 4),
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
        backgroundColor: AppTheme.cardBackground,
        title: const Text(
          'Cancel Booking?',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'Are you sure you want to cancel this booking? This action cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Booking'),
          ),
          ElevatedButton(
            onPressed: () {
              // Cancel booking
              Provider.of<BookingProvider>(context, listen: false)
                  .cancelBooking(booking.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Booking cancelled'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );
  }
}
