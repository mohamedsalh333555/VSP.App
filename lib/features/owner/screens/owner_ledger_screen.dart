import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_card.dart';

class OwnerLedgerScreen extends StatelessWidget {
  const OwnerLedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(isAr ? Iconsax.arrow_right_3_copy : Iconsax.arrow_left_2_copy, color: VSPColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isAr ? 'السجل المالي والتسويات' : 'Financial Ledger', style: Theme.of(context).textTheme.displaySmall),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client
            .from('transactions')
            .stream(primaryKey: ['id'])
            .map((list) {
              final sorted = List<Map<String, dynamic>>.from(list);
              sorted.sort((a, b) {
                final dateA = DateTime.parse(a['created_at'].toString());
                final dateB = DateTime.parse(b['created_at'].toString());
                return dateB.compareTo(dateA);
              });
              return sorted;
            }),
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
