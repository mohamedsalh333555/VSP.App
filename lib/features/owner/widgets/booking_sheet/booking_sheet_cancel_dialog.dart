import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Confirmation dialog for cancelling an owner pitch booking.
class BookingSheetCancelDialog {
  const BookingSheetCancelDialog._();

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String content,
    required String cancelBtn,
    required String confirmBtn,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(content, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelBtn, style: const TextStyle(color: VSPColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmBtn, style: const TextStyle(color: VSPColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
