import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/notification_service.dart';

class BookingSuccessScreen extends StatefulWidget {
  final double totalPrice;
  final String paymentMethod;
  final DateTime bookingDate;
  final String timeRange;

  const BookingSuccessScreen({
    super.key,
    required this.totalPrice,
    required this.paymentMethod,
    required this.bookingDate,
    required this.timeRange,
  });

  @override
  State<BookingSuccessScreen> createState() => _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends State<BookingSuccessScreen>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _checkController;
  late Animation<double> _scaleAnimation;
  final String _shareLink = 'Www.Untitlededu.Com/Blog';

  @override
  void initState() {
    super.initState();

    // 1. Setup Confetti
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _confettiController.play();

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

    // 3. Trigger Notification
    _showBookingNotification();
  }

  Future<void> _showBookingNotification() async {
    await NotificationService.showBookingConfirmation(
      stadiumName: 'Santiago Bernabéu Stadium',
      bookingDate: widget.bookingDate,
      timeSlot: widget.timeRange,
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: _shareLink));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Link copied!'),
        backgroundColor: AppTheme.neonGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.85), // Dimmed background
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Main Content Centered
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(24),
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
                        border: Border.all(color: AppTheme.neonGreen, width: 4),
                        color: const Color(0xFF2C2C2E),
                      ),
                      child: const Icon(Icons.check, color: AppTheme.neonGreen, size: 60),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Title
                  const Text(
                    'Your reservation has been\ncompleted successfully',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Agency FB',
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Share Link
                  Align(
                    alignment: Alignment.centerLeft,
                    child: const Text('Share Link', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A3A3C),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(_shareLink, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14))),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _copyLink,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.neonGreen,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.content_copy, color: AppTheme.darkBackground, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Home Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        // Reset to the very first screen (Dashboard)
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.neonGreen,
                        foregroundColor: AppTheme.darkBackground,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Home', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Confetti Animation Overlay
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: pi / 2, // Down
            maxBlastForce: 5,
            minBlastForce: 2,
            emissionFrequency: 0.05,
            numberOfParticles: 20,
            gravity: 0.2,
            colors: const [
              AppTheme.neonGreen,
              Colors.yellow,
              Colors.white,
              Colors.blue,
            ],
          ),
        ],
      ),
    );
  }
}
