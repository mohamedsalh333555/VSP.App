import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart' as app_auth;
import '../../../../core/providers/booking_provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../screens/payment_gateway_screen.dart';
import '../../services/payment_checkout_service.dart';

/// Card showing a pending booking that is awaiting payment confirmation or checkout completion.
class PendingBookingCard extends StatelessWidget {
  final Booking pendingBooking;
  final bool isArabic;

  const PendingBookingCard({
    super.key,
    required this.pendingBooking,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: VSPSpacing.md),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.card),
        border: Border.all(color: VSPColors.warning, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.timer_1_copy, color: VSPColors.warning, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic ? 'لديك حجز معلق في انتظار السداد' : 'Pending Booking Awaiting Payment',
                  style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              IconButton(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                padding: const EdgeInsets.all(12),
                icon: const Icon(Iconsax.trash_copy, color: VSPColors.error, size: 18),
                tooltip: isArabic ? 'إلغاء الحجز المعلق' : 'Cancel Pending Booking',
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      scrollable: true,
                      backgroundColor: VSPColors.surface,
                      title: Text(
                        isArabic ? 'إلغاء الحجز المعلّق؟' : 'Cancel pending booking?',
                      ),
                      content: Text(
                        isArabic
                            ? 'سيتم إلغاء الحجز المعلّق وتحرير الموعد. هل تريد المتابعة؟'
                            : 'This pending booking will be cancelled and its time slot released. Continue?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: Text(isArabic ? 'الاحتفاظ بالحجز' : 'Keep booking'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: VSPColors.error,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(isArabic ? 'تأكيد الإلغاء' : 'Confirm cancellation'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true || !context.mounted) return;

                  final bp = Provider.of<BookingProvider>(context, listen: false);
                  final success = await bp.cancelBooking(pendingBooking.id);
                  if (!context.mounted) return;

                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                        isArabic ? 'تم إلغاء الحجز المعلّق.' : 'Pending booking cancelled.',
                      ),
                      backgroundColor: VSPColors.accent,
                    ));
                    final auth = Provider.of<app_auth.AuthProvider>(context, listen: false);
                    final userId = auth.currentUser?.id;
                    if (userId != null) {
                      await bp.loadUserBookings(userId);
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                        isArabic
                            ? 'تعذر إلغاء الحجز. حاول مرة أخرى.'
                            : 'Could not cancel booking. Please try again.',
                      ),
                      backgroundColor: VSPColors.error,
                    ));
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isArabic
                ? 'الحجز لملعب "${pendingBooking.stadiumName}" مثبت لك مؤقتاً. يمكنك الاستعلام عن الدفع أو استكماله الآن.'
                : 'Booking held for "${pendingBooking.stadiumName}". Verify status or complete checkout now.',
            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final bp = Provider.of<BookingProvider>(context, listen: false);
                    try {
                      final updated = await bp.getBookingById(pendingBooking.id);
                      if (!context.mounted) return;
                      final isConfirmed = updated != null &&
                          PaymentCheckoutService.isPaymentConfirmed(
                            status: updated.status.toDbValue(),
                            paymentStatus: updated.paymentStatus,
                          );
                      if (isConfirmed) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isArabic ? 'تم تأكيد حجزك بنجاح!' : 'Booking confirmed.'),
                            backgroundColor: VSPColors.accent,
                          ),
                        );
                        final userId = Provider.of<app_auth.AuthProvider>(
                          context,
                          listen: false,
                        ).currentUser?.id;
                        if (userId != null) {
                          await bp.loadUserBookings(userId);
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isArabic
                                ? 'لم يتم تأكيد السداد بعد، يرجى استكمال عملية الدفع.'
                                : 'Payment is not confirmed yet. Please complete checkout.'),
                            backgroundColor: VSPColors.warning,
                          ),
                        );
                      }
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isArabic
                              ? 'تعذر التحقق من حالة الحجز. حاول مرة أخرى.'
                              : 'Could not check booking status. Please try again.'),
                          backgroundColor: VSPColors.error,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Iconsax.refresh_copy, size: 14, color: Colors.white),
                  label: Text(
                    isArabic ? 'استعلم ' : 'Check Status ',
                    style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VSPColors.surfaceAlt,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.chip)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    final draft = BookingDraft(
                      stadiumId: pendingBooking.stadiumId,
                      stadiumName: pendingBooking.stadiumName,
                      stadiumImageUrl: pendingBooking.stadiumImageUrl,
                      ownerId: pendingBooking.ownerId,
                      startTime: pendingBooking.startTime,
                      endTime: pendingBooking.endTime,
                      bookingType: pendingBooking.bookingType,
                      totalPrice: pendingBooking.totalPrice,
                      depositPaid: pendingBooking.depositPaid,
                      needsDeposit: pendingBooking.depositPaid > 0,
                      isPaid: false,
                      isPrivate: pendingBooking.isPrivate,
                      rentBall: pendingBooking.rentBall,
                      playerTeamId: pendingBooking.playerTeamId,
                      playerTeamName: pendingBooking.playerTeamName,
                      opponentTeamId: pendingBooking.opponentTeamId,
                      opponentTeamName: pendingBooking.opponentTeamName,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => PaymentGatewayScreen(
                          bookingDraft: draft,
                          existingBookingId: pendingBooking.id,
                          existingBooking: pendingBooking,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Iconsax.card_copy, size: 14, color: Colors.black),
                  label: Text(
                    isArabic ? 'استكمل الدفع ' : 'Resume Checkout ',
                    style: const TextStyle(color: Colors.black, fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VSPColors.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.chip)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
