import 'package:share_plus/share_plus.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/repositories/owner_repository.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../../../core/utils/vsp_feedback.dart';
import 'owner_account_management_screen.dart';

/// شاشة السجل المالي والتسويات للمالك (Monochrome + Emerald Clean Ledger)
class OwnerLedgerScreen extends StatefulWidget {
  const OwnerLedgerScreen({super.key});

  @override
  State<OwnerLedgerScreen> createState() => _OwnerLedgerScreenState();
}

class _OwnerLedgerScreenState extends State<OwnerLedgerScreen> {
  late final Stream<List<Map<String, dynamic>>> _transactionsStream;

  @override
  void initState() {
    super.initState();
    _transactionsStream = OwnerRepository().getTransactionsStream();
  }

  Future<void> _exportLedgerCsv(BuildContext context, bool isAr) async {
    HapticFeedback.lightImpact();
    try {
      final transactions = await OwnerRepository().getTransactionsList();
      if (transactions.isEmpty) {
        if (context.mounted) {
          VSPFeedback.showInfo(
            context,
            isAr ? 'لا توجد معاملات لتصديرها.' : 'No transactions to export.',
          );
        }
        return;
      }

      final StringBuffer csv = StringBuffer();
      csv.writeln('Date,Transaction_ID,Type,Amount_EGP,Payment_Method');

      for (final tx in transactions) {
        final dateStr = tx['created_at'] != null
            ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(tx['created_at'].toString()))
            : '';
        final id = tx['id']?.toString() ?? '';
        final type = tx['type']?.toString() ?? 'cash';
        final amount = tx['amount'] ?? 0;
        final method = tx['payment_method'] ?? type;

        csv.writeln('"$dateStr","$id","$type","$amount","$method"');
      }

      final String csvText = csv.toString();
      await SharePlus.instance.share(
        ShareParams(
          text: csvText,
          subject: isAr ? "كشف الحساب المالي للمنشأة" : "Facility Financial Ledger",
        ),
      );
    } catch (e) {
      if (context.mounted) {
        VSPFeedback.showError(context, isAr ? 'خطأ في تصدير السجل: $e' : 'Error exporting ledger: $e');
      }
    }
  }

  void _showPayoutRequestDialog(BuildContext context, double digitalBalance, bool isAr) {
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

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const VSPBackButton(),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.export_3_copy, color: Colors.white70),
            tooltip: isAr ? 'تصدير كشف الحساب' : 'Export Ledger',
            onPressed: () => _exportLedgerCsv(context, isAr),
          ),
        ],
        title: Text(
          isAr ? 'السجل المالي والتسويات' : 'Financial Ledger',
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _transactionsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
          }

          final transactions = snapshot.data ?? [];

          if (transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Iconsax.receipt_2_1_copy, size: 36, color: Color(0xFFA1A1AA)),
                  const SizedBox(height: 12),
                  Text(
                    isAr ? 'لا توجد معاملات مالية مسجلة بعد' : 'No financial transactions yet',
                    style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }

          double totalPitchCash = 0;
          double totalDigitalVsp = 0;

          for (var doc in transactions) {
            final type = doc['type']?.toString() ?? 'cash';
            final amt = (doc['amount'] ?? 0).toDouble();

            if (type == 'digital' || type == 'online' || type == 'paymob') {
              totalDigitalVsp += amt;
            } else if (type != 'match_win') {
              totalPitchCash += amt;
            }
          }

          return Column(
            children: [
              // كارت الرصيد الإلكتروني
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF141417),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAr ? 'الرصيد الإلكتروني المتاح' : 'Available Digital Balance',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isAr ? 'مستحقات قابلة للتحويل' : 'Withdrawable earnings',
                              style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11),
                            ),
                          ],
                        ),
                        Text(
                          '${totalDigitalVsp.toStringAsFixed(0)} ${isAr ? "ج.م" : "EGP"}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                    if (totalDigitalVsp > 0) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _showPayoutRequestDialog(context, totalDigitalVsp, isAr),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: VSPColors.accent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              isAr ? 'طلب تسوية وسحب الرصيد' : 'Request Payout Settlement',
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // كارت التحصيل النقدي بالملعب
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF141417),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAr ? 'إجمالي التحصيل النقدي' : 'Pitch Cash Collected',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isAr ? 'تم استلامها كاش بالملعب' : 'Received in cash at pitch',
                          style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11),
                        ),
                      ],
                    ),
                    Text(
                      '${totalPitchCash.toStringAsFixed(0)} ${isAr ? "ج.م" : "EGP"}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),

              // قائمة المعاملات
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: transactions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final trans = transactions[index];
                    final type = trans['type']?.toString() ?? 'cash';
                    final method = trans['payment_method']?.toString() ?? type;
                    final amountVal = trans['amount'] ?? 0;
                    final double amount = (amountVal is num) ? amountVal.toDouble() : 0.0;
                    final dateStr = trans['created_at'] as String?;
                    final date = dateStr != null ? DateTime.parse(dateStr) : DateTime.now();

                    final String title;
                    final String amountText;

                    if (type == 'match_win') {
                      title = isAr ? 'مكافأة فوز بمباراة' : 'Match Win Reward';
                      amountText = isAr ? '+3 نقاط' : '+3 pts';
                    } else if (type == 'digital' || type == 'online' || method == 'paymob') {
                      title = isAr ? 'تحصيل إلكتروني آمن' : 'Digital Online Payment';
                      amountText = '+${amount.toStringAsFixed(0)} ${isAr ? "ج.م" : "EGP"}';
                    } else {
                      title = isAr ? 'تحصيل نقدي بالملعب' : 'Pitch Cash Payment';
                      amountText = '+${amount.toStringAsFixed(0)} ${isAr ? "ج.م" : "EGP"}';
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141417),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  DateFormat('yyyy/MM/dd — hh:mm a', isAr ? 'ar' : 'en').format(date.toLocal()),
                                  style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            amountText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
