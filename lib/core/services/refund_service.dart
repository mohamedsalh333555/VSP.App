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

 final refundAmount = (response is Map && response['refund_amount'] != null)
 ? (response['refund_amount'] as num).toDouble()
 : (isPaid ? amountPaid : 0.0);
 final refundReason = (response is Map && response['refund_reason'] != null)
 ? response['refund_reason'].toString()
 : (isPaid ? 'full_refund' : 'unpaid_cancellation');

 if (context.mounted) {
 if (!isPaid) {
 VSPFeedback.showSuccess(context, "تم إلغاء الحجز غير المدفوع بنجاح.");
 } else {
 _showRefundDialog(context, refundAmount, refundReason);
 }
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
 title: const Text("سياسة استرداد المبلغ ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
 '⏱ سيتم تحويل المبلغ لحسابك خلال 3 - 5 أيام عمل عبر البنك/المحفظة.',
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
