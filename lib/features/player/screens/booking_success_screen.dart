import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../data/models.dart';

import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/notification_handler.dart';
import '../../../core/repositories/team_repository.dart';
import 'chat_screen.dart';
import 'player_home_screen.dart';
import 'bookings_screen.dart';

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
        final opponentTeam = await TeamRepository().getTeam(widget.booking.opponentTeamId!);
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
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final shortRef = widget.booking.id.length >= 8 
        ? widget.booking.id.substring(0, 8).toUpperCase() 
        : widget.booking.id.toUpperCase();

    final paymentMethodText = widget.booking.paymentMethod.toLowerCase() == 'cash'
        ? (isArabic ? 'دفع نقداً' : 'Cash')
        : (isArabic ? 'دفع إلكتروني' : 'Online Payment');

    final formattedPriceAndPayment = isArabic
        ? '${widget.booking.totalPrice.toInt()} ج.م • $paymentMethodText'
        : '${widget.booking.totalPrice.toInt()} EGP • $paymentMethodText';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.85),
        body: Stack(
          alignment: Alignment.topCenter,
          children: [
            // Main Content Centered
            Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: VSPSpacing.xl),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: VSPSpacing.lg),
                  padding: const EdgeInsets.all(VSPSpacing.xl),
                  decoration: BoxDecoration(
                    color: VSPColors.surface,
                    borderRadius: BorderRadius.circular(VSPRadius.xl),
                    border: Border.all(color: VSPColors.divider, width: 0.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated Icon
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: VSPColors.accent, width: 3.5),
                            color: VSPColors.accent.withValues(alpha: 0.1),
                          ),
                          child: const Icon(Iconsax.tick_circle_copy, color: VSPColors.accent, size: 48),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Title
                      Text(
                        l10n.bookingSuccess,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 22),
                      ),
    
                      const SizedBox(height: 20),
    
                      // Booking Details Summary (Receipt Summary Card)
                      Container(
                        padding: const EdgeInsets.all(VSPSpacing.md),
                        decoration: BoxDecoration(
                          color: VSPColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(VSPRadius.md),
                          border: Border.all(color: VSPColors.divider.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow(
                              Iconsax.building_copy, 
                              isArabic ? 'الملعب' : 'Stadium', 
                              widget.booking.stadiumName,
                            ),
                            const Divider(color: VSPColors.divider, height: 16),
                            _buildDetailRow(
                              Iconsax.calendar_1_copy, 
                              isArabic ? 'التاريخ' : 'Date', 
                              widget.booking.formattedDate,
                            ),
                            const Divider(color: VSPColors.divider, height: 16),
                            _buildDetailRow(
                              Iconsax.clock_copy, 
                              isArabic ? 'التوقيت' : 'Time Slot', 
                              widget.booking.formattedTimeRange,
                              isDirectionalText: true,
                            ),
                            const Divider(color: VSPColors.divider, height: 16),
                            _buildDetailRow(
                              Iconsax.wallet_1_copy, 
                              isArabic ? 'طريقة الدفع' : 'Payment', 
                              formattedPriceAndPayment,
                            ),
                            if (widget.booking.bookingType == BookingType.challenge) ...[
                              const Divider(color: VSPColors.divider, height: 16),
                              _buildDetailRow(
                                Iconsax.cup_copy, 
                                isArabic ? 'التحدي ضد' : 'VS Opponent', 
                                widget.booking.opponentTeamName ?? (isArabic ? 'فريق المنافس' : 'Opponent Team'),
                              ),
                            ],
                          ],
                        ),
                      ),
    
                      const SizedBox(height: VSPSpacing.lg),
    
                      // Booking Reference Box (Cleaned & Shortened)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.sm),
                        decoration: BoxDecoration(
                          color: VSPColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(VSPRadius.md),
                          border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Iconsax.tag_copy, color: VSPColors.accent, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  isArabic ? 'مرجع الحجز: ' : 'Ref #: ',
                                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                                ),
                                Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    shortRef,
                                    style: const TextStyle(
                                      color: VSPColors.accent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: _copyLink,
                              borderRadius: BorderRadius.circular(VSPRadius.xs),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: VSPColors.accent,
                                  borderRadius: BorderRadius.circular(VSPRadius.xs),
                                ),
                                child: const Icon(Iconsax.copy_copy, color: VSPColors.background, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
    
                      const SizedBox(height: 24),

                      // Chat with Stadium Owner Button (Available Post-Booking)
                      PrimaryButton(
                        text: isArabic ? 'شات مع المالك 💬' : 'Chat with Owner 💬',
                        height: 50,
                        color: VSPColors.accent.withValues(alpha: 0.15),
                        textColor: VSPColors.accent,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(booking: widget.booking),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Action Buttons (Equal Heights: 52px)
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryButton(
                              text: l10n.myBookings,
                              height: 52,
                              color: VSPColors.surfaceAlt,
                              textColor: VSPColors.textPrimary,
                              onPressed: () {
                                if (playerHomeScreenKey.currentState != null) {
                                  Navigator.of(context).popUntil((route) => route.isFirst);
                                  playerHomeScreenKey.currentState?.switchToTab(3);
                                } else {
                                  Navigator.of(context).popUntil((route) => route.isFirst);
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const BookingsScreen()));
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: VSPSpacing.md),
                          Expanded(
                            child: PrimaryButton(
                              text: l10n.home,
                              height: 52,
                              onPressed: () {
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
            ),
    
            // Confetti Animation Overlay (Optimized UX)
            RepaintBoundary(
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: pi / 2, // Down
                maxBlastForce: 10,
                minBlastForce: 3,
                emissionFrequency: 0.03,
                numberOfParticles: 15,
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
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {bool isDirectionalText = false}) {
    return Row(
      children: [
        Icon(icon, color: VSPColors.accent, size: 18),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
        ),
        Expanded(
          child: isDirectionalText
              ? Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                )
              : Text(
                  value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      ],
    );
  }
}


