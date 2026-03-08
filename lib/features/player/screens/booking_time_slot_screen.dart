import 'package:flutter/material.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../data/models.dart';

class BookingTimeSlotScreen extends StatelessWidget {
  final Stadium stadium;
  final String bookingType; // 'full' or 'individual'

  const BookingTimeSlotScreen({
    super.key,
    required this.stadium,
    required this.bookingType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        title: Text('Select Time Slot', style: Theme.of(context).textTheme.displaySmall),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: VSPColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Text(
          'Time Slots for ${stadium.name}\n($bookingType)',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
