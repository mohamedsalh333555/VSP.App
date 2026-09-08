import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Card widget displaying the slot time and day of week.
class BookingSheetTimeStadiumCard extends StatelessWidget {
  final String formattedTime;

  const BookingSheetTimeStadiumCard({
    super.key,
    required this.formattedTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.clock_copy, color: VSPColors.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              formattedTime,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
