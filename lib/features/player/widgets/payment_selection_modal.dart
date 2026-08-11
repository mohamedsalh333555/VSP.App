import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models.dart';
import '../screens/payment_gateway_screen.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';

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
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final String timeRange = selectedTimeSlots.isNotEmpty
        ? '${selectedTimeSlots.first} ${isArabic ? 'إلى' : 'To'} ${selectedTimeSlots.last}'
        : '';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(VSPSpacing.lg),
        decoration: BoxDecoration(
          color: VSPColors.surfaceAlt,
          borderRadius: BorderRadius.circular(VSPRadius.xl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close Button
            Align(
              alignment: isArabic ? Alignment.topLeft : Alignment.topRight,
              child: IconButton(
                icon: Icon(Iconsax.close_circle_copy, color: VSPColors.textPrimary, size: 24),
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
                color: VSPColors.accent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Iconsax.tick_circle_copy,
                color: VSPColors.accent,
                size: 40,
              ),
            ),

            const SizedBox(height: VSPSpacing.md),

            // Title
            Text(
              isArabic ? 'تأكيد حجزك' : 'Confirm Your Booking',
              style: Theme.of(context).textTheme.displaySmall,
            ),

            const SizedBox(height: VSPSpacing.lg),

            // Booking Details
            _buildDetailRow(context, isArabic ? 'التاريخ' : 'Date', DateFormat('yyyy/MM/dd').format(selectedDate)),
            const SizedBox(height: VSPSpacing.sm),
            _buildDetailRow(context, isArabic ? 'الوقت' : 'Time', timeRange),
            const SizedBox(height: VSPSpacing.sm),
            _buildDetailRow(context, isArabic ? 'السعر' : 'Price', '${totalPrice.toInt()} ${isArabic ? 'ج.م' : 'EGP'}'),

            const SizedBox(height: VSPSpacing.xl),

            // Confirm Cash Booking Button
            PrimaryButton(
              text: isArabic ? 'تأكيد الحجز النقدي' : 'Confirm Cash Booking',
              onPressed: () => _navigateToPayment(context, 'cash'),
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
      

      try {
        startTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          parseHour(firstSlot),
          0,
        );
        
        endTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          parseHour(lastSlot) + 1,
          0,
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
      needsDeposit: stadium?.needsDeposit ?? false,
    );

    Navigator.pop(context); // Close modal
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentGatewayScreen(bookingDraft: draft),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Row(
      children: [
        Text(
          '$label - ',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: VSPColors.textSecondary.withValues(alpha: 0.8),
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: VSPColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
