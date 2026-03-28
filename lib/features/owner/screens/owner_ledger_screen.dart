import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_card.dart';


class OwnerLedgerScreen extends StatelessWidget {
  const OwnerLedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Financial Ledger', style: Theme.of(context).textTheme.displaySmall),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('transactions').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No transactions yet.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary)));
          }

          final transactions = snapshot.data!.docs;

          double totalCash = 0;
          for (var doc in transactions) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['type'] != 'match_win') {
              totalCash += (data['amount'] ?? 0).toDouble();
            }
          }
          final double commission = totalCash * 0.05;

          return Column(
            children: [
              // ── Financial Summary Header ──
              VSPCard(
                margin: const EdgeInsets.all(VSPSpacing.md),
                padding: const EdgeInsets.all(VSPSpacing.lg),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Cash Collected', style: Theme.of(context).textTheme.bodyMedium),
                        Text('${totalCash.toStringAsFixed(0)} EGP', 
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(color: VSPColors.accent)
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: VSPColors.divider),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('App Commission Pending (5%)', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary)),
                        Text('${commission.toStringAsFixed(0)} EGP', 
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: VSPColors.warning)
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This amount is payable to VSP at the end of the month.',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary, fontStyle: FontStyle.italic),
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
                    final trans = transactions[index].data() as Map<String, dynamic>;
                    final isWin = trans['type'] == 'match_win';
                    final amount = trans['amount'] ?? 0;
                    final date = (trans['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

                    return VSPCard(
                      padding: const EdgeInsets.all(VSPSpacing.md),
                      margin: EdgeInsets.zero,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (isWin ? VSPColors.warning : VSPColors.accent).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isWin ? Icons.emoji_events : Icons.attach_money,
                              color: isWin ? VSPColors.warning : VSPColors.accent,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isWin ? 'Match Win Reward' : 'Booking Payment',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                Text(
                                  DateFormat('MMM d, yyyy • h:mm a').format(date),
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            isWin ? '+3 pts' : '+$amount eg',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: isWin ? VSPColors.warning : VSPColors.accent,
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
