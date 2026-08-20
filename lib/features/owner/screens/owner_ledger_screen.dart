import 'package:share_plus/share_plus.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/repositories/owner_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../shared/widgets/vsp_back_button.dart';

class OwnerLedgerScreen extends StatelessWidget {
  const OwnerLedgerScreen({super.key});

  Future<void> _exportLedgerCsv(BuildContext context, bool isAr) async {
    try {
      final transactions = await OwnerRepository().getTransactionsList();
      if (transactions.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isAr ? 'لا توجد معاملات لتصديرها.' : 'No transactions to export.')),
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
      await Share.share(
        csvText,
        subject: isAr ? "كشف حساب VSP المالي" : "VSP Financial Ledger",
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting ledger: $e')),
        );
      }
    }
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
            return Center(child: Text(isAr ? 'لا توجد معاملات مالية بعد.' : 'No transactions yet.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary)));
          }

          double totalCash = 0;
          for (var doc in transactions) {
            if (doc['type'] != 'match_win') {
              totalCash += (doc['amount'] ?? 0).toDouble();
            }
          }

          return Column(
            children: [
              VSPCard(
                margin: const EdgeInsets.all(VSPSpacing.md),
                padding: const EdgeInsets.all(VSPSpacing.lg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isAr ? 'إجمالي المبالغ المحصلة' : 'Total Cash Collected', style: Theme.of(context).textTheme.bodyMedium),
                    Text('${totalCash.toStringAsFixed(0)} ${isAr ? "ج.م" : "EGP"}', 
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(color: VSPColors.accent)
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: transactions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final trans = transactions[index];
                    final type = trans['type'] ?? 'cash';
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
                    } else if (type == 'digital') {
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
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                Text(
                                  DateFormat('MMM d, yyyy • h:mm a', Localizations.localeOf(context).toString()).format(date),
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            amountText,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: color,
                              fontWeight: FontWeight.bold,
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
