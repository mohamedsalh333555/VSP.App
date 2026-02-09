import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models.dart';
import '../screens/payment_gateway_screen.dart';

/// Legacy modal - now redirects to new BookingDraft flow
/// This modal is kept for backwards compatibility but should be phased out
class PaymentSelectionModal extends StatelessWidget {
  final double totalPrice;
  final String bookingType;
  final DateTime selectedDate;
  final List<String> selectedTimeSlots;
  final String stadiumName;
  final Stadium? stadium;

  const PaymentSelectionModal({
    super.key,
    required this.totalPrice,
    required this.bookingType,
    required this.selectedDate,
    required this.selectedTimeSlots,
    this.stadiumName = 'Santiago Bernabéu Stadium',
    this.stadium,
  });

  @override
  Widget build(BuildContext context) {
    final bool isChallengeMode = bookingType == 'Challenge';
    final String timeRange = selectedTimeSlots.isNotEmpty
        ? '${selectedTimeSlots.first} To ${selectedTimeSlots.last}'
        : '';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close Button
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textPrimary, size: 24),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),

            // Check Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.neonGreen.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: AppTheme.neonGreen,
                size: 40,
              ),
            ),

            const SizedBox(height: 20),

            // Title
            const Text(
              'Confirm Your Booking',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Agency FB',
              ),
            ),

            const SizedBox(height: 24),

            // Booking Details
            _buildDetailRow('Date', DateFormat('yyyy/MM/dd').format(selectedDate)),
            const SizedBox(height: 12),
            _buildDetailRow('Time', timeRange),
            const SizedBox(height: 12),
            _buildDetailRow('Price', '${totalPrice.toInt()} EGP'),

            const SizedBox(height: 32),

            // Pay Upon Arrival Button (for non-challenge mode)
            if (!isChallengeMode)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    _navigateToPayment(context, 'cash');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    foregroundColor: AppTheme.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Pay Upon Arrival',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            if (!isChallengeMode) const SizedBox(height: 12),

            // Pay Now Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  _navigateToPayment(context, 'card');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.neonGreen,
                  foregroundColor: AppTheme.darkBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Pay Now',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToPayment(BuildContext context, String method) {
    // Parse time slots to DateTime
    DateTime startTime = selectedDate;
    DateTime endTime = selectedDate.add(const Duration(hours: 2));

    if (selectedTimeSlots.isNotEmpty) {
      // Try to parse the first slot for start time
      final firstSlot = selectedTimeSlots.first;
      final lastSlot = selectedTimeSlots.last;
      
      int parseHour(String time) {
        final parts = time.split(':');
        int hour = int.parse(parts[0]);
        if (time.toLowerCase().contains('pm') && hour != 12) hour += 12;
        return hour;
      }
      
      int parseMinute(String time) {
        final parts = time.split(':');
        final minutePart = parts[1].replaceAll(RegExp(r'[^0-9]'), '');
        return int.parse(minutePart.substring(0, minutePart.length >= 2 ? 2 : minutePart.length));
      }

      try {
        startTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          parseHour(firstSlot),
          parseMinute(firstSlot),
        );
        
        final endMinute = parseMinute(lastSlot) + 30;
        endTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          endMinute >= 60 ? parseHour(lastSlot) + 1 : parseHour(lastSlot),
          endMinute >= 60 ? endMinute - 60 : endMinute,
        );
      } catch (_) {
        // Fallback to default
      }
    }

    // Convert bookingType string to enum
    BookingType bookingTypeEnum;
    switch (bookingType.toLowerCase()) {
      case 'team':
        bookingTypeEnum = BookingType.team;
        break;
      case 'challenge':
        bookingTypeEnum = BookingType.challenge;
        break;
      default:
        bookingTypeEnum = BookingType.personal;
    }

    // Create BookingDraft
    final draft = BookingDraft(
      stadiumId: stadium?.id ?? '1',
      stadiumName: stadium?.name ?? stadiumName,
      stadiumImageUrl: stadium?.imageUrl ?? '',
      ownerId: '', // Would come from stadium
      startTime: startTime,
      endTime: endTime,
      bookingType: bookingTypeEnum,
      isPrivate: false,
      rentBall: false,
      totalPrice: totalPrice,
      currency: 'EGP',
      paymentMethod: method,
    );

    Navigator.pop(context); // Close modal
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentGatewayScreen(bookingDraft: draft),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label - ',
          style: TextStyle(
            color: AppTheme.textSecondary.withValues(alpha: 0.8),
            fontSize: 15,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
