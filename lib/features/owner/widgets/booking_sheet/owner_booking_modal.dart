import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../data/models.dart';
import '../owner_booking_sheet.dart';

/// Shows the dedicated bottom sheet modal for owner booking management.
Future<void> showOwnerBookingModal({
  required BuildContext context,
  required bool isEdit,
  required Map<String, dynamic> slot,
  required Stadium selectedStadium,
  DateTime? baseDate,
  int? selectedDayIndex,
  required BuildContext parentContext,
}) {
  final now = DateTime.now();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (modalContext) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: OwnerBookingSheet(
        isEdit: isEdit,
        slot: slot,
        selectedStadium: selectedStadium,
        baseDate: baseDate ?? now,
        selectedDayIndex: selectedDayIndex ?? 0,
        parentContext: parentContext,
      ),
    ),
  );
}
