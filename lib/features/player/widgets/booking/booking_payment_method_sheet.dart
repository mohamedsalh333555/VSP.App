import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/booking_provider.dart';
import '../../../../core/services/remote_config_service.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';
import '../../screens/booking_success_screen.dart';
import '../../screens/payment_gateway_screen.dart';

/// يعرض شيت اختيار وسيلة الدفع (أونلاين كامل، عربون أونلاين، أو كاش بالملعب)
void showBookingPaymentMethodSheet({
  required BuildContext context,
  required BookingDraft draft,
  required double totalPrice,
  required double depositAmount,
  required bool requiresDeposit,
  required UserModel currentUserModel,
  required BookingProvider bookingProvider,
  required NavigatorState nav,
}) {
  final isArabic = Localizations.localeOf(context).languageCode == 'ar';

  final config = Provider.of<RemoteConfigService>(context, listen: false);
  final isOnlineEnabled = config.isFeatureEnabled('online_payment_enabled');

  showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: VSPColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      bool isNavigating = false;
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(ctx).padding.bottom > 0 ? 8 : 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: VSPColors.divider, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isArabic ? 'اختر طريقة الدفع' : 'Select Payment Option',
                    style: const TextStyle(color: VSPColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  if (!isOnlineEnabled)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: VSPColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: VSPColors.warning.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Iconsax.info_circle_copy, color: VSPColors.warning, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isArabic
                                  ? 'الدفع الإلكتروني قيد الصيانة المجدولة حالياً.'
                                  : 'Online payment is currently under maintenance.',
                              style: const TextStyle(color: VSPColors.warning, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // -------------------------------------------------------------
                  // حالة 1: الملعب يشترط عربوناً -> (دفع كامل أونلاين vs دفع العربون)
                  // -------------------------------------------------------------
                  if (requiresDeposit && isOnlineEnabled) ...[
                    // خيار 1: دفع كامل المبلغ أونلاين
                    ListTile(
                      leading: const Icon(Iconsax.card_copy, color: VSPColors.accent),
                      title: Text(
                        isArabic ? 'دفع كامل المبلغ أونلاين' : 'Pay Full Amount Online',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        isArabic
                            ? 'سداد ${totalPrice.toInt()} ج.م كاملاً بالفيزا/المحفظة (المتبقي بالملعب: 0 ج.م)'
                            : 'Pay full ${totalPrice.toInt()} EGP online (Remaining at pitch: 0 EGP)',
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                      ),
                      onTap: isNavigating
                          ? null
                          : () {
                              setSheetState(() => isNavigating = true);
                              HapticFeedback.lightImpact();
                              Navigator.pop(ctx);
                              final fullDraft = draft.copyWith(
                                needsDeposit: false,
                                depositPaid: 0.0,
                              );
                              nav.push(MaterialPageRoute(
                                builder: (_) => PaymentGatewayScreen(
                                  bookingDraft: fullDraft,
                                  forceFullPayment: true,
                                ),
                              ));
                            },
                    ),
                    const Divider(color: VSPColors.divider),
                    // خيار 2: دفع العربون فقط أونلاين
                    ListTile(
                      leading: const Icon(Iconsax.lock_copy, color: Colors.amber),
                      title: Text(
                        isArabic ? 'دفع العربون فقط أونلاين' : 'Pay Deposit Only Online',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        isArabic
                            ? 'سداد ${depositAmount.toInt()} ج.م عربون لتأكيد الحجز + سداد المتبقي (${(totalPrice - depositAmount).toInt()} ج.م) كاش بالملعب'
                            : 'Pay ${depositAmount.toInt()} EGP deposit now + pay remaining (${(totalPrice - depositAmount).toInt()} EGP) in cash',
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                      ),
                      onTap: isNavigating
                          ? null
                          : () {
                              setSheetState(() => isNavigating = true);
                              HapticFeedback.lightImpact();
                              Navigator.pop(ctx);
                              final depositDraft = draft.copyWith(
                                needsDeposit: true,
                                depositPaid: depositAmount,
                              );
                              nav.push(MaterialPageRoute(
                                builder: (_) => PaymentGatewayScreen(
                                  bookingDraft: depositDraft,
                                ),
                              ));
                            },
                    ),
                  ]

                  // -------------------------------------------------------------
                  // حالة 2: الدفع نقدياً (أو إذا كان الدفع الإلكتروني معطلاً)
                  // -------------------------------------------------------------
                  else ...[
                    if (isOnlineEnabled) ...[
                      // خيار 1: دفع إلكتروني
                      ListTile(
                        leading: const Icon(Iconsax.card_copy, color: VSPColors.accent),
                        title: Text(
                          isArabic ? 'دفع إلكتروني كامل' : 'Full Online Payment',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          isArabic ? 'سداد بالفيزا / فودافون كاش / إنستاباي' : 'Pay via Visa / Vodafone Cash / InstaPay',
                          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                        ),
                        onTap: isNavigating
                            ? null
                            : () {
                                setSheetState(() => isNavigating = true);
                                HapticFeedback.lightImpact();
                                Navigator.pop(ctx);
                                nav.push(MaterialPageRoute(
                                  builder: (_) => PaymentGatewayScreen(
                                    bookingDraft: draft,
                                    forceFullPayment: true,
                                  ),
                                ));
                              },
                      ),
                      const Divider(color: VSPColors.divider),
                    ],
                    // خيار 2: دفع نقدي
                    ListTile(
                      leading: isNavigating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.accent),
                            )
                          : const Icon(Iconsax.money_3_copy, color: VSPColors.warning),
                      title: Text(
                        isArabic ? 'دفع نقدي بالكامل في الملعب' : 'Pay Full Cash at Pitch',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        isArabic ? 'سداد المبلغ كاملاً للمسؤول عند الحضور' : 'Pay total amount in cash upon arrival',
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                      ),
                      onTap: isNavigating
                          ? null
                          : () async {
                              HapticFeedback.mediumImpact();
                              setSheetState(() => isNavigating = true);
                              try {
                                final cashDraft = draft.copyWith(
                                  paymentMethod: 'cash',
                                  isPaid: false,
                                  depositPaid: 0.0,
                                  isDepositPaid: false,
                                );
                                final booking = await bookingProvider.createBooking(cashDraft, currentUserModel.uid);
                                if (booking != null && sheetContext.mounted) {
                                  HapticFeedback.lightImpact();
                                  Navigator.pop(ctx);
                                  nav.pushReplacement(
                                    MaterialPageRoute(builder: (_) => BookingSuccessScreen(booking: booking)),
                                  );
                                } else if (bookingProvider.errorMessage != null && sheetContext.mounted) {
                                  HapticFeedback.vibrate();
                                  setSheetState(() => isNavigating = false);
                                  VSPFeedback.showError(sheetContext, bookingProvider.errorMessage!);
                                }
                              } catch (e) {
                                HapticFeedback.vibrate();
                                if (sheetContext.mounted) {
                                  setSheetState(() => isNavigating = false);
                                  VSPFeedback.showError(sheetContext, e.toString().replaceAll('Exception: ', ''));
                                }
                              }
                            },
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
