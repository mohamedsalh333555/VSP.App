import 'package:share_plus/share_plus.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/repositories/owner_repository.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/utils/vsp_feedback.dart';
import 'owner_account_management_screen.dart';

class OwnerLedgerScreen extends StatelessWidget {
  const OwnerLedgerScreen({super.key});

  Future<void> _exportLedgerCsv(BuildContext context, bool isAr) async {
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
          subject: isAr ? "كشف حساب VSP المالي" : "VSP Financial Ledger",
        ),
      );
    } catch (e) {
      if (context.mounted) {
        VSPFeedback.showError(context, 'Error exporting ledger: $e');
      }
    }
  }

  void _showPayoutRequestDialog(BuildContext context, double digitalBalance, bool isAr) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.userModel;

    final hasPayoutMethod = (user?.p2pInstapay?.isNotEmpty ?? false) ||
        (user?.p2pVodafone?.isNotEmpty ?? false) ||
        (user?.p2pBank?.isNotEmpty ?? false);

    if (!hasPayoutMethod) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: VSPColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
          title: Text(
            isAr ? 'تنبيه: وسيلة التحصيل غير مسجلة ⚠️' : 'Payout Method Missing ⚠️',
            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Text(
            isAr
                ? 'يرجى تسجيل وسيلة تحصيل واحدة على الأقل (إنستاباي أو محفظة إلكترونية أو حساب بنكي) في إعدادات الحساب لتتمكن من استلام مستحقاتك.'
                : 'Please add at least one payout method (InstaPay, Wallet, or Bank IBAN) in Account Settings to request withdrawals.',
            style: const TextStyle(color: VSPColors.textSecondary, height: 1.5),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isAr ? 'إلغاء' : 'Cancel', style: const TextStyle(color: VSPColors.textSecondary)),
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
              ),
              child: Text(isAr ? 'إضافة وسيلة تحصيل 💳' : 'Add Payout Method 💳'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Text(
          isAr ? 'طلب تسوية رصيد VSP 💸' : 'Request Payout Settlement 💸',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAr
                  ? 'الرصيد الإلكتروني المتاح للتسوية:'
                  : 'Available Digital Payout Balance:',
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              '${digitalBalance.toStringAsFixed(0)} ${isAr ? "ج.م" : "EGP"}',
              style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.w900, fontSize: 22),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: VSPColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: VSPColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr ? 'سيتم التحويل إلى:' : 'Transfer destination:',
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  if (user?.p2pInstapay?.isNotEmpty ?? false)
                    Text('• InstaPay: ${user!.p2pInstapay}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  if (user?.p2pVodafone?.isNotEmpty ?? false)
                    Text('• Wallet: ${user!.p2pVodafone}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  if (user?.p2pBank?.isNotEmpty ?? false)
                    Text('• Bank: ${user!.p2pBank}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isAr
                  ? '💡 تتم مراجعة التحويل وإرساله عبر الإدارة خلال 24 ساعة من تاريخ الطلب.'
                  : '💡 Settlements are reviewed and disbursed by admin within 24 hours.',
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11, height: 1.4),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isAr ? 'إلغاء' : 'Cancel', style: const TextStyle(color: VSPColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              VSPFeedback.showSuccess(
                context,
                isAr
                    ? 'تم إرسال طلب التسوية للإدارة بنجاح! 🚀\nسيتم إشعارك فور إتمام التحويل.'
                    : 'Payout request submitted successfully! 🚀',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: VSPColors.accent,
              foregroundColor: Colors.black,
            ),
            child: Text(isAr ? 'تأكيد إرسال الطلب' : 'Confirm Request'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const VSPBackButton(),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.export_3_copy, color: VSPColors.accent),
            tooltip: isAr ? 'تصدير كشف الحساب (CSV)' : 'Export Ledger (CSV)',
            onPressed: () => _exportLedgerCsv(context, isAr),
          ),
        ],
        title: Text(isAr ? 'السجل المالي والتسويات' : 'Financial Ledger', style: Theme.of(context).textTheme.displaySmall),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: OwnerRepository().getTransactionsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
          }

          final transactions = snapshot.data ?? [];

          if (transactions.isEmpty) {
            return Center(
              child: Text(
                isAr ? 'لا توجد معاملات مالية بعد.' : 'No transactions yet.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
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
              // 1. Digital VSP Payout Balance Card
              VSPCard(
                margin: const EdgeInsets.fromLTRB(VSPSpacing.md, VSPSpacing.sm, VSPSpacing.md, 0),
                padding: const EdgeInsets.all(VSPSpacing.md),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Iconsax.wallet_3_copy, color: Color(0xFF3B82F6), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isAr ? 'رصيد VSP الإلكتروني (Paymob)' : 'Digital VSP Balance',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  isAr ? 'مستحقات إلكترونية قابلة للتحويل' : 'Withdrawable digital earnings',
                                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Text(
                          '${totalDigitalVsp.toStringAsFixed(0)} ${isAr ? "ج.م" : "EGP"}',
                          style: const TextStyle(
                            color: Color(0xFF60A5FA),
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    if (totalDigitalVsp > 0) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: PrimaryButton(
                          text: isAr ? 'طلب تسوية وسحب الرصيد 💸' : 'Request Payout Settlement 💸',
                          height: 38,
                          color: const Color(0xFF2563EB),
                          textColor: Colors.white,
                          onPressed: () => _showPayoutRequestDialog(context, totalDigitalVsp, isAr),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 2. Pitch Cash Collected Card
              VSPCard(
                margin: const EdgeInsets.fromLTRB(VSPSpacing.md, VSPSpacing.sm, VSPSpacing.md, VSPSpacing.sm),
                padding: const EdgeInsets.all(VSPSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: VSPColors.success.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Iconsax.money_recive_copy, color: VSPColors.success, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAr ? 'إجمالي التحصيل النقدي بالملعب' : 'Total Pitch Cash Collected',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              isAr ? 'تم استلامها كاش مباشرة من اللاعبين' : 'Received in cash at pitch',
                              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      '${totalPitchCash.toStringAsFixed(0)} ${isAr ? "ج.م" : "EGP"}',
                      style: const TextStyle(
                        color: VSPColors.accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Transactions Stream List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: transactions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final trans = transactions[index];
                    final type = trans['type']?.toString() ?? 'cash';
                    final method = trans['payment_method']?.toString() ?? type;
                    final amountVal = trans['amount'] ?? 0;
                    final double amount = (amountVal is num) ? amountVal.toDouble() : 0.0;
                    final dateStr = trans['created_at'] as String?;
                    final date = dateStr != null ? DateTime.parse(dateStr) : DateTime.now();

                    final IconData icon;
                    final Color color;
                    final String title;
                    final String amountText;

                    if (type == 'match_win') {
                      icon = Iconsax.cup_copy;
                      color = VSPColors.warning;
                      title = isAr ? 'مكافأة الفوز بمباراة' : 'Match Win Reward';
                      amountText = isAr ? '+3 نقاط' : '+3 pts';
                    } else if (type == 'digital' || type == 'online' || method == 'paymob') {
                      icon = Iconsax.wallet_1_copy;
                      color = const Color(0xFF3B82F6); // Electric Blue/Indigo
                      title = isAr ? 'تحصيل إلكتروني آمن (Paymob)' : 'Digital Online Payment';
                      amountText = '+${amount.toStringAsFixed(0)} ${isAr ? "ج.م" : "EGP"}';
                    } else {
                      // Default to cash
                      icon = Iconsax.card_copy;
                      color = VSPColors.success;
                      title = isAr ? 'تحصيل نقدي بالملعب' : 'Pitch Cash Payment';
                      amountText = '+${amount.toStringAsFixed(0)} ${isAr ? "ج.م" : "EGP"}';
                    }

                    return VSPCard(
                      padding: const EdgeInsets.all(VSPSpacing.md),
                      margin: EdgeInsets.zero,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              icon,
                              color: color,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('MMM d, yyyy • h:mm a', Localizations.localeOf(context).toString()).format(date),
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            amountText,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
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
