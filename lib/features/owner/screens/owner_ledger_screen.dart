import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';


class OwnerLedgerScreen extends StatelessWidget {
  const OwnerLedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text('Financial Ledger', style: TextStyle(fontFamily: 'Agency FB', fontSize: 24, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('transactions').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.neonGreen));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No transactions yet.', style: TextStyle(color: Colors.white54)));
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
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.neonGreen.withOpacity(0.15), Colors.transparent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.neonGreen.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Cash Collected', style: TextStyle(color: Colors.white, fontSize: 14)),
                        Text('${totalCash.toStringAsFixed(0)} EGP', 
                          style: const TextStyle(color: AppTheme.neonGreen, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Agency FB')
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(color: Colors.white.withOpacity(0.1)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('App Commission Pending (5%)', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        Text('${commission.toStringAsFixed(0)} EGP', 
                          style: const TextStyle(color: Colors.orangeAccent, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Agency FB')
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This amount is payable to VSP at the end of the month.',
                      style: TextStyle(color: Colors.grey, fontSize: 10, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  itemCount: transactions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final trans = transactions[index].data() as Map<String, dynamic>;
                    final isWin = trans['type'] == 'match_win';
                    final amount = trans['amount'] ?? 0;
                    final date = (trans['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isWin ? Colors.amber.withOpacity(0.2) : AppTheme.neonGreen.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isWin ? Icons.emoji_events : Icons.attach_money,
                              color: isWin ? Colors.amber : AppTheme.neonGreen,
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
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  DateFormat('MMM d, yyyy • h:mm a').format(date),
                                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            isWin ? '+3 pts' : '+${amount} eg',
                            style: TextStyle(
                              color: isWin ? Colors.amber : AppTheme.neonGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              fontFamily: 'Agency FB',
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
