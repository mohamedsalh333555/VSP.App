import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../screens/payment_gateway_screen.dart';
import '../screens/booking_success_screen.dart';

class PaymentSelectionModal extends StatelessWidget {
  final double totalPrice;
  final String bookingType;
  final DateTime selectedDate;
  final List<String> selectedTimeSlots;
  final String stadiumName;

  const PaymentSelectionModal({
    super.key,
    required this.totalPrice,
    required this.bookingType,
    required this.selectedDate,
    required this.selectedTimeSlots,
    this.stadiumName = 'Santiago Bernabéu Stadium',
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
                color: AppTheme.neonGreen.withOpacity(0.2),
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
            _buildDetailRow('Price', '${totalPrice.toInt()}'),

            const SizedBox(height: 32),

            // Pay Upon Arrival Button
            if (!isChallengeMode)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BookingSuccessScreen(
                          totalPrice: totalPrice,
                          paymentMethod: 'Pay Upon Arrival',
                          bookingDate: selectedDate,
                          timeRange: timeRange,
                        ),
                      ),
                    );
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
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PaymentGatewayScreen(
                        totalPrice: totalPrice,
                        bookingDate: selectedDate,
                        timeRange: timeRange,
                      ),
                    ),
                  );
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

  Widget _buildDetailRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label - ',
          style: TextStyle(
            color: AppTheme.textSecondary.withOpacity(0.8),
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
