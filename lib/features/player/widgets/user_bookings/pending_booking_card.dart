import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart' as app_auth;
import '../../../../core/providers/booking_provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../screens/payment_gateway_screen.dart';

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
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.timer_1_copy, color: VSPColors.accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic ? 'لديك حجز معلق في انتظار السداد' : 'Pending Booking Awaiting Payment',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              IconButton(
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                icon: const Icon(Iconsax.trash_copy, color: Colors.redAccent, size: 18),
                tooltip: isArabic ? 'إلغاء الحجز المعلق' : 'Cancel Pending Booking',
                onPressed: () async {
                  final bp = Provider.of<BookingProvider>(context, listen: false);
                  await bp.cancelBooking(pendingBooking.id);
                  if (context.mounted) {
                    final auth = Provider.of<app_auth.AuthProvider>(context, listen: false);
                    if (auth.currentUser?.uid != null) {
                      bp.loadUserBookings(auth.currentUser!.uid);
                    }
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
            style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final bp = Provider.of<BookingProvider>(context, listen: false);
                    final updated = await bp.getBookingById(pendingBooking.id);
                    if (context.mounted) {
                      if (updated != null && (updated.status == BookingStatus.confirmed || updated.isPaid)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isArabic ? ' تم تأكيد حجزك بنجاح!' : ' Booking Confirmed!'),
                            backgroundColor: VSPColors.accent,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isArabic
                                ? 'لم يتم تأكيد السداد بعد، يرجى استكمال عملية التثبيت.'
                                : 'Payment pending. Complete checkout.'),
                            backgroundColor: VSPColors.surfaceAlt,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Iconsax.refresh_copy, size: 14, color: Colors.white),
                  label: Text(
                    isArabic ? 'استعلم ' : 'Check Status ',
                    style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF27272A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
