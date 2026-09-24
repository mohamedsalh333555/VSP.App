import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/repositories/owner_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../widgets/ledger/owner_ledger_balance_cards.dart';
import '../widgets/ledger/owner_ledger_transaction_item.dart';
import '../widgets/ledger/owner_payout_dialog.dart';

/// شاشة السجل المالي والتسويات للمالك (Monochrome + Emerald Clean Ledger)
class OwnerLedgerScreen extends StatefulWidget {
  const OwnerLedgerScreen({super.key});

  @override
  State<OwnerLedgerScreen> createState() => _OwnerLedgerScreenState();
}

class _OwnerLedgerScreenState extends State<OwnerLedgerScreen> {
  late final Stream<List<Map<String, dynamic>>> _transactionsStream;
  Map<String, dynamic>? _summary;

  @override
  void initState() {
    super.initState();
    _transactionsStream = OwnerRepository().getTransactionsStream();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final res = await OwnerRepository().getOwnerFinancialSummary(uid);
    if (mounted) {
      setState(() {
        _summary = res;
      });
    }
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
            icon: const Icon(Iconsax.refresh_copy, color: Colors.white70),
            tooltip: isAr ? 'تحديث السجل' : 'Refresh Ledger',
            onPressed: () => _loadSummary(),
          ),
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

          // Authoritative DB summary values if loaded, fallback to transaction summation
          double availableDigital = (_summary?['available_balance'] as num?)?.toDouble() ?? 0.0;
          double totalPitchCash = (_summary?['cash_revenue'] as num?)?.toDouble() ?? 0.0;
          if (_summary == null) {
            for (var doc in transactions) {
              final type = doc['type']?.toString() ?? 'cash';
              final amt = (doc['amount'] ?? 0).toDouble();

              if (type == 'digital' || type == 'online' || type == 'paymob') {
                availableDigital += amt;
              } else if (type != 'match_win' && type != 'payout' && type != 'payout_pending' && type != 'payout_disbursed') {
                totalPitchCash += amt;
              }
            }
          }

          if (transactions.isEmpty && _summary == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Iconsax.receipt_2_1_copy, size: 36, color: VSPColors.textSecondary),
                  const SizedBox(height: 12),
                  Text(
                    isAr ? 'لا توجد معاملات مالية مسجلة بعد' : 'No financial transactions yet',
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // كارت الرصيد الإلكتروني المتاح للسحب
              OwnerDigitalBalanceCard(
                digitalBalance: availableDigital,
                isAr: isAr,
                onRequestPayout: () => OwnerPayoutDialog.show(context, availableDigital, isAr),
              ),

              // كارت التحصيل النقدي بالملعب (يظهر فقط عند وجود تحصيل نقدي)
              if (totalPitchCash > 0)
                OwnerPitchCashCard(
                  pitchCash: totalPitchCash,
                  isAr: isAr,
                ),

                  // قائمة المعاملات
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20, top: 4),
                  physics: const BouncingScrollPhysics(),
                  itemCount: transactions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return OwnerLedgerTransactionItem(
                      transaction: transactions[index],
                      isAr: isAr,
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
