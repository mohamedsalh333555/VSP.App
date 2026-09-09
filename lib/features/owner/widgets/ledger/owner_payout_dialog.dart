import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/repositories/owner_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../screens/owner_account_management_screen.dart';

/// Modal dialogs for requesting digital balance payouts and settlements.
class OwnerPayoutDialog {
  const OwnerPayoutDialog._();

  /// Displays payout request modal with payment destination verification.
  static void show(BuildContext context, double digitalBalance, bool isAr) {
    HapticFeedback.mediumImpact();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.userModel;

    final hasPayoutMethod = (user?.p2pInstapay?.isNotEmpty ?? false) ||
        (user?.p2pVodafone?.isNotEmpty ?? false) ||
        (user?.p2pBank?.isNotEmpty ?? false);

    if (!hasPayoutMethod) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF18181B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isAr ? 'وسيلة التحصيل غير مسجلة' : 'Payout Method Required',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          content: Text(
            isAr
                ? 'يرجى تسجيل وسيلة تحصيل واحدة على الأقل (إنستاباي أو محفظة إلكترونية أو حساب بنكي) في إعدادات الحساب لتتمكن من استلام مستحقاتك.'
                : 'Please add at least one payout method (InstaPay, Mobile Wallet, or Bank IBAN) in Account Settings to request settlements.',
            style: const TextStyle(color: Color(0xFFA1A1AA), height: 1.5, fontSize: 13),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isAr ? 'إلغاء' : 'Cancel', style: const TextStyle(color: Color(0xFFA1A1AA))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OwnerAccountManagementScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: VSPColors.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                isAr ? 'إضافة وسيلة تحصيل' : 'Add Payout Method',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
      return;
    }

    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isAr ? 'طلب تسوية وسحب الرصيد' : 'Request Payout Settlement',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAr ? 'الرصيد الإلكتروني المتاح للتسوية:' : 'Available Digital Balance:',
              style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              '${digitalBalance.toStringAsFixed(0)} ${isAr ? "ج.م" : "EGP"}',
              style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.w900, fontSize: 24),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF141417),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr ? 'جهة التحويل المعتمدة:' : 'Transfer Destination:',
                    style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  if (user?.p2pInstapay?.isNotEmpty ?? false)
                    Text('• ${isAr ? "إنستاباي" : "InstaPay"}: ${user!.p2pInstapay}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  if (user?.p2pVodafone?.isNotEmpty ?? false)
                    Text('• ${isAr ? "المحفظة الذكية" : "Wallet"}: ${user!.p2pVodafone}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  if (user?.p2pBank?.isNotEmpty ?? false)
                    Text('• ${isAr ? "الحساب البنكي" : "Bank IBAN"}: ${user!.p2pBank}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isAr
                  ? 'تتم مراجعة طلبات التسوية وإتمام التحويل من قِبل الإدارة خلال 24 ساعة.'
                  : 'Settlements are reviewed and disbursed by administration within 24 hours.',
              style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11, height: 1.4),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          StatefulBuilder(
            builder: (btnCtx, setBtnState) {
              final String destinationMethod = (user?.p2pInstapay?.isNotEmpty ?? false)
                  ? 'instapay'
                  : ((user?.p2pVodafone?.isNotEmpty ?? false)
                      ? 'wallet'
                      : ((user?.p2pBank?.isNotEmpty ?? false) ? 'bank' : 'unknown'));

              final String destinationVal = (user?.p2pInstapay?.isNotEmpty ?? false)
                  ? user!.p2pInstapay!
                  : ((user?.p2pVodafone?.isNotEmpty ?? false)
                      ? user!.p2pVodafone!
                      : ((user?.p2pBank?.isNotEmpty ?? false) ? user!.p2pBank! : ''));

              return Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                      child: Text(isAr ? 'إلغاء' : 'Cancel', style: const TextStyle(color: Color(0xFFA1A1AA))),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setBtnState(() => isSubmitting = true);
                              final res = await OwnerRepository().requestPayoutSettlement(
                                amount: digitalBalance,
                                method: destinationMethod,
                                destination: destinationVal,
                              );

                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);

                              if (context.mounted) {
                                if (res['success'] == true) {
                                  VSPFeedback.showSuccess(
                                    context,
                                    isAr
                                        ? 'تم إرسال طلب التسوية للإدارة بنجاح.\nسيتم إشعارك فور إتمام التحويل.'
                                        : 'Payout settlement request submitted successfully.',
                                  );
                                } else {
                                  VSPFeedback.showError(
                                    context,
                                    res['error']?.toString() ?? (isAr ? 'فشل إرسال طلب التسوية' : 'Failed to submit request'),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VSPColors.accent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : Text(isAr ? 'تأكيد الإرسال' : 'Confirm Request', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
