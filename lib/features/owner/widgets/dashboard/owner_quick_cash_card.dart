import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/booking_provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/app_date_formatter.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../core/utils/vsp_launcher_utils.dart';
import '../../../../core/utils/vsp_quick_booking_receipt_formatter.dart';
import '../../../../data/models.dart';
import '../../../../shared/widgets/primary_button.dart';

/// بطاقة تأكيد الكاش السريعة بلمسة واحدة في لوحة تحكم المالك/الكاشير
class OwnerQuickCashCard extends StatefulWidget {
  final List<Booking> allBookings;
  final List<Stadium> stadiums;
  final String selectedStadiumFilter;
  final bool isArabic;
  final DateTime? currentTime;

  const OwnerQuickCashCard({
    super.key,
    required this.allBookings,
    this.stadiums = const [],
    this.selectedStadiumFilter = 'all',
    required this.isArabic,
    this.currentTime,
  });

  @override
  State<OwnerQuickCashCard> createState() => _OwnerQuickCashCardState();
}

class _OwnerQuickCashCardState extends State<OwnerQuickCashCard> {
  String? _confirmingBookingId;

  Future<void> _onConfirmCash(Booking booking) async {
    setState(() => _confirmingBookingId = booking.id);
    HapticFeedback.heavyImpact();

    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    final success = await bookingProvider.updatePaymentStatus(booking.id, true);

    if (mounted) {
      setState(() => _confirmingBookingId = null);
    }

    if (success && mounted) {
      VSPFeedback.showSuccess(
        context,
        widget.isArabic
            ? 'تم استلام وتأكيد النقدية وتحديث الحسابات'
            : 'Cash received & confirmed successfully',
      );
      _promptSendReceipt(booking);
    } else if (!success && mounted) {
      VSPFeedback.showError(
        context,
        widget.isArabic
            ? 'تعذر تأكيد استلام النقدية، يرجى المحاولة مرة أخرى'
            : 'Could not confirm cash, please try again',
      );
    }
  }

  void _promptSendReceipt(Booking booking) {
    if (booking.playerPhone == null || booking.playerPhone!.isEmpty) return;

    final stadium = widget.stadiums.firstWhere(
      (s) => s.id == booking.stadiumId,
      orElse: () => Stadium(
        id: booking.stadiumId,
        name: booking.stadiumName,
        location: '',
        ownerId: booking.ownerId,
        imageUrl: '',
        type: 'Football',
        size: '5v5',
        baths: 0,
        cafeteria: 0,
        playersPerTeam: 5,
        totalFieldCapacity: 10,
        pricePerHour: booking.totalPrice,
        basePrice: booking.totalPrice,
        area: '',
      ),
    );

    final double actualDeposit = (booking.depositPaid > 0 && booking.depositPaid < booking.totalPrice)
        ? booking.depositPaid
        : 0.0;
    final receiptText = VSPQuickBookingReceiptFormatter.buildReceiptMessage(
      stadiumName: booking.stadiumName,
      bookingRef: booking.id.length >= 8 ? booking.id.substring(0, 8).toUpperCase() : booking.id,
      customerName: booking.hostName ?? (widget.isArabic ? 'كابتن' : 'Captain'),
      startTime: booking.startTime.toLocal(),
      endTime: booking.endTime.toLocal(),
      totalPrice: booking.totalPrice,
      depositPaid: actualDeposit,
      isCashConfirmed: true,
      googleMapsUrl: stadium.googleMapsUrl,
      stadiumPhone: stadium.phone,
      isArabic: widget.isArabic,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: VSPColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Icon(Iconsax.receipt_2_copy, color: VSPColors.accent, size: 36),
            const SizedBox(height: 12),
            Text(
              widget.isArabic ? 'تم تأكيد استلام النقدية!' : 'Cash Receipt Confirmed!',
              style: const TextStyle(color: VSPColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              widget.isArabic
                  ? 'هل ترغب في إرسال إيصال رسمي للكابتن عبر واتساب؟'
                  : 'Send an official WhatsApp confirmation receipt to captain?',
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              text: widget.isArabic ? 'إرسال إيصال عبر واتساب' : 'Send Receipt on WhatsApp',
              onPressed: () async {
                Navigator.pop(ctx);
                await VSPLauncherUtils.openWhatsApp(
                  context,
                  phone: booking.playerPhone!,
                  message: receiptText,
                );
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                widget.isArabic ? 'إغلاق' : 'Close',
                style: const TextStyle(color: VSPColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.currentTime ?? DateTime.now();

    final pendingCashBookings = widget.allBookings.where((b) {
      if (b.status == BookingStatus.cancelled) return false;
      if (b.isPaid || b.paymentStatus == 'paid') return false;
      if (widget.selectedStadiumFilter != 'all' && b.stadiumId != widget.selectedStadiumFilter) return false;
      return DateUtils.isSameDay(b.startTime.toLocal(), now);
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (pendingCashBookings.isEmpty) {
      final todayPaidBookings = widget.allBookings.where((b) {
        if (b.status == BookingStatus.cancelled) return false;
        if (!b.isPaid && b.paymentStatus != 'paid') return false;
        return DateUtils.isSameDay(b.startTime.toLocal(), now);
      });

      if (todayPaidBookings.isEmpty) return const SizedBox.shrink();

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: VSPColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(color: VSPColors.accent.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Iconsax.wallet_2_copy, color: VSPColors.accent, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.isArabic ? 'جميع مدفوعات اليوم مؤكدة بالكامل' : 'All today cash collections settled',
                style: const TextStyle(color: VSPColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    final totalRemainingCash = pendingCashBookings.fold<double>(0.0, (sum, b) {
      final deposit = b.depositPaid;
      return sum + (b.totalPrice - deposit).clamp(0.0, 999999.0);
    });

    final String locale = widget.isArabic ? 'ar' : 'en';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: const Icon(Iconsax.wallet_2_copy, color: VSPColors.accent, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isArabic ? 'تحصيل كاش اليوم' : "Today's Cash Collection",
                      style: const TextStyle(
                        color: VSPColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.isArabic
                          ? 'متبقي للتحصيل: ${totalRemainingCash.toInt()} ج.م'
                          : 'Pending collection: ${totalRemainingCash.toInt()} EGP',
                      style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Text(
                  '${pendingCashBookings.length} ${widget.isArabic ? 'قيد التحصيل' : 'Pending'}',
                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
          const SizedBox(height: 10),
          for (int i = 0; i < pendingCashBookings.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _buildBookingCard(pendingCashBookings[i], locale),
          ],
        ],
      ),
    );
  }

  Widget _buildBookingCard(Booking b, String locale) {
    final isConfirming = _confirmingBookingId == b.id;
    final deposit = b.depositPaid;
    final cashRemaining = (b.totalPrice - deposit).clamp(0.0, 999999.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  AppDateFormatter.formatTime(b.startTime.toLocal(), locale),
                  style: const TextStyle(color: VSPColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  b.hostName != null && b.hostName!.isNotEmpty ? b.hostName! : (widget.isArabic ? 'لاعب' : 'Player'),
                  style: const TextStyle(color: VSPColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${cashRemaining.toInt()} ${widget.isArabic ? "ج.م" : "EGP"}',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (deposit > 0) ...[
            const SizedBox(height: 4),
            Text(
              widget.isArabic ? 'عربون مدفوع إلكترونياً: ${deposit.toInt()} ج.م' : 'Online deposit paid: ${deposit.toInt()} EGP',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10.5),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VSPColors.success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.sm)),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: isConfirming ? null : () => _onConfirmCash(b),
                    icon: isConfirming
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Iconsax.wallet_3_copy, size: 16),
                    label: Text(
                      widget.isArabic ? 'تم استلام الكاش' : 'Confirm Cash Received',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              if (b.playerPhone != null && b.playerPhone!.isNotEmpty) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.02),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.sm)),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () => VSPLauncherUtils.makePhoneCall(context, b.playerPhone!),
                    child: const Icon(Iconsax.call_copy, size: 15, color: Colors.white70),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
