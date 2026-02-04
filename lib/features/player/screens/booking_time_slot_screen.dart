import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
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
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text('Select Time Slot', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Text(
          'Time Slots for ${stadium.name}\n($bookingType)',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }
}
