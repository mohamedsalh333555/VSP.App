import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
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
              OwnerDigitalBalanceCard(
                digitalBalance: totalDigitalVsp,
                isAr: isAr,
                onRequestPayout: () => OwnerPayoutDialog.show(context, totalDigitalVsp, isAr),
              ),

              // كارت التحصيل النقدي بالملعب
              OwnerPitchCashCard(
                pitchCash: totalPitchCash,
                isAr: isAr,
              ),

              // قائمة المعاملات
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
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
