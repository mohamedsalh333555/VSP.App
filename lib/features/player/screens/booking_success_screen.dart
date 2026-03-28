import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../data/models.dart';
import 'booked_screen.dart';

import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/notification_handler.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/notification_service.dart';

class BookingSuccessScreen extends StatefulWidget {
  final Booking booking;

  const BookingSuccessScreen({
    super.key,
    required this.booking,
  });

  @override
  State<BookingSuccessScreen> createState() => _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends State<BookingSuccessScreen>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _checkController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Setup Confetti
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

    // 2. Setup Checkmark Animation
    _checkController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );
    _checkController.forward();

    // 3. Trigger Post-Write Effects with a small delay for better UX
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _confettiController.play();
        _showBookingNotification();
        HapticFeedback.heavyImpact();
      }
    });
  }

  Future<void> _showBookingNotification() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final playerName = authProvider.userModel?.name ?? 'A player';

    // 1. Notify Player (Local + Firestore)
    await NotificationHandler.notifyBookingConfirmed(
      userId: widget.booking.createdByUserId,
      stadiumName: widget.booking.stadiumName,
      bookingId: widget.booking.id,
      timeSlot: widget.booking.formattedTimeRange,
    );

    // 2. Notify Owner (Firestore)
    if (widget.booking.ownerId.isNotEmpty) {
      await NotificationHandler.notifyNewBookingReceived(
        ownerId: widget.booking.ownerId,
        stadiumName: widget.booking.stadiumName,
        playerName: playerName,
        bookingId: widget.booking.id,
        timeSlot: widget.booking.formattedTimeRange,
      );
    }

    // 3. Notify Opponent (if Challenge)
    if (widget.booking.bookingType == BookingType.challenge && widget.booking.opponentTeamId != null) {
      try {
        final opponentTeam = await DatabaseService().getTeam(widget.booking.opponentTeamId!);
        if (opponentTeam != null && opponentTeam.memberUids.isNotEmpty) {
          // The first member in memberUids is the captain
          final captainId = opponentTeam.memberUids.first;
          await NotificationHandler.notifyChallengeReceived(
            opponentCaptainId: captainId, 
            challengerTeamName: widget.booking.playerTeamName ?? 'A Team', 
            bookingId: widget.booking.id,
          );
        }
      } catch (e) {
        debugPrint('Error sending challenge notification: $e');
      }
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  void _copyLink() {
    final shareContent = AppLocalizations.of(context)!.shareBookingMessage(widget.booking.stadiumName, widget.booking.id);
    Clipboard.setData(ClipboardData(text: shareContent));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.bookingRefCopied),
        backgroundColor: VSPColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.sm)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.85),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Main Content Centered
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: VSPSpacing.lg),
              padding: const EdgeInsets.all(VSPSpacing.xl),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.xl),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated Icon
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: VSPColors.accent, width: 4),
                        color: VSPColors.surface,
                      ),
                      child: const Icon(Icons.check, color: VSPColors.accent, size: 60),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Title
                  Text(
                    AppLocalizations.of(context)!.bookingSuccess,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),

                  const SizedBox(height: 24),

                  // Booking Details Summary
                  Container(
                    padding: const EdgeInsets.all(VSPSpacing.md),
                    decoration: BoxDecoration(
                      color: VSPColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow(Icons.stadium, widget.booking.stadiumName),
                        const SizedBox(height: VSPSpacing.md),
                        _buildDetailRow(Icons.calendar_today, widget.booking.formattedDate),
                        const SizedBox(height: VSPSpacing.md),
                        _buildDetailRow(Icons.access_time, widget.booking.formattedTimeRange),
                        const SizedBox(height: VSPSpacing.md),
                        _buildDetailRow(
                          Icons.payment, 
                          '${widget.booking.totalPrice.toInt()} ${widget.booking.currency} - ${widget.booking.paymentMethod.toUpperCase()}'
                        ),
                        if (widget.booking.bookingType == BookingType.challenge) ...[
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            Icons.sports_soccer, 
                            AppLocalizations.of(context)!.vsOpponent(widget.booking.opponentTeamName ?? 'Opponent')
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: VSPSpacing.lg),

                  // Share Link
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(AppLocalizations.of(context)!.bookingReference, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
                  ),
                  const SizedBox(height: VSPSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.sm),
                    decoration: BoxDecoration(
                      color: VSPColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(VSPRadius.sm),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)!.refHash(widget.booking.id.toUpperCase()),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: VSPSpacing.sm),
                        InkWell(
                          onTap: _copyLink,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: VSPColors.accent,
                              borderRadius: BorderRadius.circular(VSPRadius.xs),
                            ),
                            child: const Icon(Icons.content_copy, color: VSPColors.background, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          text: AppLocalizations.of(context)!.myBookings,
                          color: VSPColors.surfaceAlt,
                          textColor: VSPColors.textPrimary,
                          onPressed: () {
                            // Navigate to bookings screen
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (context) => const BookedScreen()),
                              (route) => route.isFirst,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: VSPSpacing.md),
                      Expanded(
                        child: PrimaryButton(
                          text: AppLocalizations.of(context)!.home,
                          onPressed: () {
                            // Reset to the very first screen (Dashboard)
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Confetti Animation Overlay
          RepaintBoundary(
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2, // Down
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.2,
              colors: const [
                VSPColors.accent,
                Colors.yellow,
                Colors.white,
                Colors.blue,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: VSPColors.accent, size: 20),
        const SizedBox(width: VSPSpacing.md),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
