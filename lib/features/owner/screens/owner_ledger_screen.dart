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

          return ListView.separated(
            padding: const EdgeInsets.all(16),
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
                        color: isWin ? Colors.amber.withValues(alpha: 0.2) : AppTheme.neonGreen.withValues(alpha: 0.2),
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
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
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
          );
        },
      ),
    );
  }
}
