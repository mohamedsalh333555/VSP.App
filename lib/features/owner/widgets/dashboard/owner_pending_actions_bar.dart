import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';

/// شريط الإجراء التشغيلي الفوري للحجوزات المعلقة (فحمي وأخضر نيون)
class OwnerPendingActionsBar extends StatelessWidget {
  final List<Booking> allBookings;
  final bool isArabic;
  final VoidCallback onActionTap;

  const OwnerPendingActionsBar({
    super.key,
    required this.allBookings,
    required this.isArabic,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    // حساب عدد الحجوزات النقدية غير المؤكدة بعد
    final unconfirmedCashBookings = allBookings.where((b) {
      if (b.status == BookingStatus.cancelled || b.status == BookingStatus.completed) {
        return false;
      }
      final isCash = (b.paymentMethod.toLowerCase() == 'cash');
      final isUnpaidOrUnconfirmed = !b.isPaid && b.paymentStatus != 'paid';
      return isCash && isUnpaidOrUnconfirmed;
    }).toList();

    final count = unconfirmedCashBookings.length;

    // إذا لم تكن هناك أي حجوزات معلقة، يعرض شريطاً صامتاً ومطمئناً
    if (count == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: VSPColors.surface, // #18181B الفحمي
          borderRadius: BorderRadius.circular(VSPRadius.card),
          border: Border.all(color: VSPColors.divider, width: 1.0),
        ),
        child: Row(
          children: [
            const Icon(
              Iconsax.tick_circle_copy,
              size: 18,
              color: VSPColors.accent, // #9FDF02 الأخضر نيون
            ),
            const SizedBox(width: 10),
            Text(
              isArabic ? 'كل الحجوزات النقدية مؤكدة ومحدثة' : 'All cash bookings are confirmed',
              style: const TextStyle(
                color: VSPColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final countText = isArabic
        ? '$count حجوزات كاش لسه مش متأكده'
        : '$count cash bookings pending confirmation';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: VSPColors.surface, // #18181B الفحمي
        borderRadius: BorderRadius.circular(VSPRadius.card),
        border: Border.all(
          color: VSPColors.divider,
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(VSPRadius.card),
          onTap: () {
            HapticFeedback.lightImpact();
            onActionTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // أيقونة الكاش بالأخضر النيون
                const Icon(
                  Iconsax.money_3_copy,
                  size: 20,
                  color: VSPColors.accent, // #9FDF02 الأخضر نيون
                ),
                const SizedBox(width: 12),

                // نص الإجراء
                Expanded(
                  child: Text(
                    countText,
                    style: const TextStyle(
                      color: VSPColors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // سهم الانتقال
                Icon(
                  isArabic ? Icons.chevron_left : Icons.chevron_right,
                  size: 20,
                  color: VSPColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
