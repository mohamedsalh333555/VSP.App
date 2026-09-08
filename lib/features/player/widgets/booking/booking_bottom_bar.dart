import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';

/// الشريط السفلي المتكامل لشاشة الحجز (الخيارات الإضافية، السعر الإجمالي، وزر التأكيد)
class BookingBottomBar extends StatelessWidget {
  final bool isOpenJoin;
  final bool isPrivate;
  final ValueChanged<bool> onPrivateChanged;
  final int initialPlayersCount;
  final int maxPlayersCount;
  final ValueChanged<int> onPlayersCountChanged;
  final bool hasBallOption;
  final bool isBallRented;
  final ValueChanged<bool> onBallRentedChanged;
  final double ballPrice;
  final double totalPrice;
  final double depositAmount;
  final bool needsDeposit;
  final bool isSlotSelected;
  final bool isLoading;
  final VoidCallback onConfirmPressed;

  const BookingBottomBar({
    super.key,
    required this.isOpenJoin,
    required this.isPrivate,
    required this.onPrivateChanged,
    required this.initialPlayersCount,
    required this.maxPlayersCount,
    required this.onPlayersCountChanged,
    required this.hasBallOption,
    required this.isBallRented,
    required this.onBallRentedChanged,
    required this.ballPrice,
    required this.totalPrice,
    required this.depositAmount,
    required this.needsDeposit,
    required this.isSlotSelected,
    required this.isLoading,
    required this.onConfirmPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        bottomPadding > 0 ? bottomPadding + 14 : 20,
      ),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        border: const Border(top: BorderSide(color: VSPColors.divider, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── خيار الحجز الخاص (خاص بـ OpenJoin) ──
          if (isOpenJoin) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isArabic ? 'حجز خاص' : 'Private',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                Transform.scale(
                  scale: 0.85,
                  child: Switch(
                    value: isPrivate,
                    activeColor: Colors.black,
                    activeTrackColor: VSPColors.accent,
                    inactiveThumbColor: Colors.grey,
                    inactiveTrackColor: VSPColors.surfaceAlt,
                    trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                    onChanged: (val) {
                      onPrivateChanged(val);
                      VSPFeedback.showInfo(
                        context,
                        val
                            ? (isArabic
                                ? 'حجز خاص: تقتصر المباراة على فريقك فقط.'
                                : 'Private Booking: Exclusive for your team only.')
                            : (isArabic
                                ? 'حجز عام: ستظهر مباراتك في الخريطة ليتمكن باقي اللاعبين من الانضمام!'
                                : 'Public Booking: Visible on map for players to join!'),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // ── عداد اللاعبين المتوفرين معك (خاص بـ OpenJoin) ──
          if (isOpenJoin) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'عدد اللاعبين المتوفرين معك' : 'Players With You',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isArabic ? 'حدد عدد أصحابك القادمين معك لتكملة سعة الملعب' : 'Specify how many friends you bring with you',
                      style: const TextStyle(
                        color: VSPColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: VSPColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(color: VSPColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Iconsax.minus_copy, size: 16, color: Colors.white),
                        onPressed: initialPlayersCount > 1
                            ? () {
                                HapticFeedback.selectionClick();
                                onPlayersCountChanged(initialPlayersCount - 1);
                              }
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '$initialPlayersCount',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Iconsax.add_copy, size: 16, color: Colors.white),
                        onPressed: initialPlayersCount < maxPlayersCount
                            ? () {
                                HapticFeedback.selectionClick();
                                onPlayersCountChanged(initialPlayersCount + 1);
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // ── خيار إيجار الكرة ──
          if (hasBallOption) ...[
            GestureDetector(
              onTap: () => onBallRentedChanged(!isBallRented),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isBallRented ? VSPColors.accent.withValues(alpha: 0.12) : VSPColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(VSPRadius.lg),
                  border: Border.all(
                    color: isBallRented ? VSPColors.accent : VSPColors.divider,
                    width: isBallRented ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabic ? 'إيجار كرة / ${ballPrice.toInt()} ج.م' : 'Ball / ${ballPrice.toInt()}eg',
                            style: TextStyle(
                              color: isBallRented ? Colors.white : VSPColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isArabic ? 'دفع رسوم إيجار الكرة في هذا الملعب' : 'Pay Per Ball At This Pitch',
                            style: const TextStyle(
                              color: VSPColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isBallRented ? VSPColors.accent : Colors.transparent,
                        border: Border.all(
                          color: isBallRented ? VSPColors.accent : Colors.grey.shade600,
                          width: 1.5,
                        ),
                      ),
                      child: isBallRented
                          ? const Icon(Iconsax.tick_circle_copy, size: 16, color: Colors.black)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // ── السعر الإجمالي وزر تأكيد الحجز ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isArabic ? 'السعر الإجمالي' : 'Total Price',
                    style: const TextStyle(
                      color: VSPColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${totalPrice.toInt()} ${isArabic ? "ج.م" : "eg"}',
                        style: TextStyle(
                          color: isSlotSelected ? VSPColors.accent : Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (depositAmount > 0 && needsDeposit) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: VSPColors.warning.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isArabic ? 'عربون ${depositAmount.toInt()}' : 'Dep ${depositAmount.toInt()}',
                            style: const TextStyle(color: VSPColors.warning, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSlotSelected ? VSPColors.accent : VSPColors.surfaceAlt,
                      foregroundColor: isSlotSelected ? Colors.black : Colors.grey.shade500,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(VSPRadius.lg),
                      ),
                    ),
                    onPressed: (!isSlotSelected || isLoading) ? null : onConfirmPressed,
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : Text(
                            isSlotSelected
                                ? (isArabic ? 'تأكيد الحجز' : 'Booking Confirmation')
                                : (isArabic ? 'اختر الوقت أولاً' : 'Select Time'),
                            style: TextStyle(
                              color: isSlotSelected ? Colors.black : Colors.grey.shade400,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
