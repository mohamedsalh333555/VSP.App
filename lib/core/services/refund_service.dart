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
      final now = DateTime.now();
      final cutoff = bookingStartTime.subtract(const Duration(hours: 2));
      if (now.isAfter(cutoff)) {
        if (context.mounted) {
          VSPFeedback.showError(context, "عذراً، لا يمكن إلغاء الحجز قبل موعد المباراة بأقل من ساعتين وفقاً للائحة الاسترداد.");
        }
        return;
      }

      if (isPaid && amountPaid > 0) {
        // استدعاء دالة process_paymob_refund Edge Function للتواصل المباشر مع بوابة Paymob
        final response = await _supabase.functions.invoke(
          'process_paymob_refund',
          body: {
            'booking_id': bookingId,
            'reason': 'User requested cancellation with refund',
          },
        );

        final data = response.data;
        if (data is Map && data['success'] == true) {
          final refundAmount = (data['refund_amount'] as num?)?.toDouble() ?? amountPaid;
          if (context.mounted) {
            _showRefundDialog(context, refundAmount, isFailed: false);
          }
        } else if (data is Map && data['refund_failed'] == true) {
          final refundAmount = (data['refund_amount'] as num?)?.toDouble() ?? amountPaid;
          if (context.mounted) {
            _showRefundDialog(context, refundAmount, isFailed: true);
          }
        } else {
          final errMsg = data is Map ? data['message']?.toString() : null;
          if (context.mounted) {
            VSPFeedback.showError(context, errMsg ?? "فشل معالجة إلغاء الحجز.");
          }
        }
      } else {
        // إلغاء حجز غير مدفوع
        final response = await _supabase.rpc('cancel_booking_with_refund_atomic', params: {
          'p_booking_id': bookingId,
          'p_user_id': _supabase.auth.currentUser?.id,
        });

        if (response is Map && response['success'] == false) {
          if (context.mounted) {
            VSPFeedback.showError(context, response['message']?.toString() ?? "فشل إلغاء الحجز.");
          }
          return;
        }

        if (context.mounted) {
          VSPFeedback.showSuccess(context, "تم إلغاء الحجز غير المدفوع بنجاح.");
        }
      }
    } catch (e) {
      if (context.mounted) {
        VSPFeedback.showError(context, "فشل إلغاء الحجز: $e");
      }
    }
  }

  void _showRefundDialog(BuildContext context, double amount, {required bool isFailed}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
        title: Row(
          children: [
            Icon(
              isFailed ? Icons.warning_amber_rounded : Icons.check_circle_outline,
              color: isFailed ? VSPColors.warning : VSPColors.accent,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              isFailed ? "تنبيه معالجة الاسترداد" : "تم استرداد المبلغ بنجاح",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isFailed
                  ? "تم إلغاء الحجز بنجاح، ولكن واجهت بوابة الدفع مشكلة مؤقتة في إتمام الاسترداد التلقائي للمبلغ (${amount.toStringAsFixed(0)} ج.م).\n\nتم إخطار فريق الدعم الفني لمراجعة العملية وتحويل المبلغ لك يدوياً."
                  : "تم إلغاء الحجز واعتماد استرداد 100% من المبلغ (${amount.toStringAsFixed(0)} ج.م) عبر Paymob بنجاح.",
              style: const TextStyle(color: VSPColors.textPrimary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isFailed ? VSPColors.warning : VSPColors.accent).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: (isFailed ? VSPColors.warning : VSPColors.accent).withValues(alpha: 0.3)),
              ),
              child: Text(
                isFailed
                    ? '⏱ سيقوم فريق الدعم الفني بالتواصل معك ومتابعة التحويل.'
                    : '⏱ سيتم إيداع المبلغ في حسابك البنكي أو محفظتك الإلكترونية خلال 3 - 5 أيام عمل وفقاً للبنك المصدر.',
                style: TextStyle(fontSize: 12, color: isFailed ? VSPColors.warning : VSPColors.accent, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("موافق", style: TextStyle(color: isFailed ? VSPColors.warning : VSPColors.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
