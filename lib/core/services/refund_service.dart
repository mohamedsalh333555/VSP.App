import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../ui/tokens/vsp_tokens.dart';
import '../utils/vsp_feedback.dart';

class RefundService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> cancelBookingWithRefund(
    BuildContext context, {
    required String bookingId,
    required DateTime bookingStartTime,
    required double amountPaid,
    required bool isPaid,
  }) async {
    try {
      if (!isPaid) {
        await _supabase.from('bookings').update({
          'status': 'cancelled',
          'cancelled_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', bookingId);

        if (context.mounted) {
          VSPFeedback.showSuccess(context, "تم إلغاء الحجز غير المدفوع بنجاح.");
        }
        return;
      }

      final hoursBeforeBooking = bookingStartTime.difference(DateTime.now()).inHours;
      double refundAmount = 0.0;
      String refundReason = '';

      if (hoursBeforeBooking >= 24) {
        refundAmount = amountPaid;
        refundReason = 'full_refund';
      } else if (hoursBeforeBooking >= 2) {
        refundAmount = amountPaid * 0.75;
        refundReason = 'partial_refund_75';
      } else {
        refundAmount = 0.0;
        refundReason = 'no_refund_too_late';
      }

      try {
        await _supabase.functions.invoke('process_refund', body: {
          'booking_id': bookingId,
          'refund_amount': refundAmount,
          'refund_reason': refundReason,
        });
      } catch (e) {
        debugPrint('Refund Function invoke notice: $e');
      }

      await _supabase.from('bookings').update({
        'status': 'cancelled',
        'payment_status': 'refunded',
        'cancelled_at': DateTime.now().toUtc().toIso8601String(),
        'refund_amount': refundAmount,
      }).eq('id', bookingId);

      if (context.mounted) {
        _showRefundDialog(context, refundAmount, refundReason);
      }
    } catch (e) {
      if (context.mounted) {
        VSPFeedback.showError(context, "فشل إلغاء الحجز. يرجى التواصل مع الدعم الفني.");
      }
    }
  }

  void _showRefundDialog(BuildContext context, double amount, String reason) {
    String refundText = '';
    switch (reason) {
      case 'full_refund':
        refundText = 'سيتم استرداد 100% من المبلغ (${amount.toStringAsFixed(0)} ج.م)';
        break;
      case 'partial_refund_75':
        refundText = 'سيتم استرداد 75% من المبلغ (${amount.toStringAsFixed(0)} ج.م)\nخصم 25% رسوم إلغاء متأخر.';
        break;
      case 'no_refund_too_late':
        refundText = 'عذراً، الإلغاء قبل أقل من ساعتين لا يتيح استرداد المبلغ.';
        break;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
        title: const Text("سياسة استرداد المبلغ 💰", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(refundText, style: const TextStyle(color: VSPColors.textPrimary, fontSize: 14, height: 1.5)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VSPColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
              ),
              child: const Text(
                '⏱️ سيتم تحويل المبلغ لحسابك خلال 3 - 5 أيام عمل عبر البنك/المحفظة.',
                style: TextStyle(fontSize: 12, color: VSPColors.accent, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("موافق", style: TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
