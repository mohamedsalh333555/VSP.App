import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/repositories/owner_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/vsp_ui.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../../../shared/widgets/vsp_error_state.dart';
import '../widgets/ledger/owner_ledger_balance_cards.dart';
import '../widgets/ledger/owner_ledger_transaction_item.dart';
import '../widgets/ledger/owner_payout_dialog.dart';

/// شاشة السجل المالي والتسويات للمالك (Monochrome + Emerald Clean Ledger)
class OwnerLedgerScreen extends StatefulWidget {
  final bool payoutOnly;

  const OwnerLedgerScreen({super.key, this.payoutOnly = false});

  @override
  State<OwnerLedgerScreen> createState() => _OwnerLedgerScreenState();
}

class _OwnerLedgerScreenState extends State<OwnerLedgerScreen> {
  late Stream<List<Map<String, dynamic>>> _transactionsStream;
  Map<String, dynamic>? _summary;

  @override
  void initState() {
    super.initState();
    _transactionsStream = widget.payoutOnly
        ? OwnerRepository().getPayoutSettlementsStream()
        : OwnerRepository().getTransactionsStream();
    _loadSummary();
  }

  void _retryTransactions() {
    setState(() {
      _transactionsStream = widget.payoutOnly
          ? OwnerRepository().getPayoutSettlementsStream()
          : OwnerRepository().getTransactionsStream();
    });
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
      // Add UTF-8 BOM so Excel opens Arabic correctly without garbled characters
      csv.write('\uFEFF');
      csv.writeln(isAr
          ? 'التاريخ,رقم المعاملة,النوع,المبلغ (ج.م),طريقة الدفع'
          : 'Date,Transaction_ID,Type,Amount_EGP,Payment_Method');

      for (final tx in transactions) {
        final dateStr = tx['created_at'] != null
            ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(tx['created_at'].toString()))
            : '';
        final id = tx['id']?.toString() ?? '';
        final rawType = tx['type']?.toString() ?? 'cash';
        final type = isAr
            ? (rawType == 'payment'
                ? 'سداد حجز'
                : rawType == 'deposit'
                    ? 'عربون'
                    : rawType == 'refund'
                        ? 'استرداد'
                        : rawType == 'payout'
                            ? 'سحب أرباح'
                            : rawType)
            : rawType;
        final amount = tx['amount'] ?? 0;
        final rawMethod = tx['payment_method'] ?? rawType;
        final method = isAr
            ? (rawMethod == 'cash'
                ? 'نقدي'
                : rawMethod == 'wallet'
                    ? 'محفظة إلكترونية'
                    : rawMethod == 'card'
                        ? 'بطاقة بنكية'
                        : rawMethod)
            : rawMethod;

        final csvRow = [dateStr, id, type, amount, method]
            .map((value) => '"${value.toString().replaceAll('"', '""')}"')
            .join(',');
        csv.writeln(csvRow);
      }

      final tempDir = await getTemporaryDirectory();
      final dateStamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final filePath = '${tempDir.path}/vsp_ledger_$dateStamp.csv';
      final file = File(filePath);
      await file.writeAsString(csv.toString(), encoding: utf8);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath, mimeType: 'text/csv')],
          subject: isAr ? "كشف الحساب المالي للمنشأة" : "Facility Financial Ledger",
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Error exporting owner financial ledger: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (context.mounted) {
        VSPFeedback.showError(context, isAr ? 'تعذر تصدير السجل المالي. حاول مرة أخرى.' : 'Could not export the financial ledger. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return VSPScaffold(
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
          widget.payoutOnly
              ? (isAr ? 'سجل السحوبات' : 'Withdrawal History')
              : (isAr ? 'السجل المالي والتسويات' : 'Financial Ledger'),
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: SafeArea(top: false, bottom: true, child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _transactionsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return VSPStateView(
              state: VSPUiState.loading,
              title: isAr ? 'جاري تحميل السجل المالي' : 'Loading financial ledger',
              message: isAr ? 'بنحدّث الرصيد والمعاملات من المصدر المالي.' : 'Refreshing balance and transactions from the financial source.',
            );
          }

          final rawRows = snapshot.data ?? [];
          if (snapshot.hasError && rawRows.isEmpty) {
            return VSPErrorState(
              customMessage: isAr
                  ? 'تعذر تحميل السجل المالي. أعد المحاولة لتحديث البيانات.'
                  : 'Could not load the financial ledger. Retry to refresh the data.',
              retryButtonText: isAr ? 'إعادة المحاولة' : 'Retry',
              onRetry: _retryTransactions,
            );
          }
          final transactions = widget.payoutOnly
              ? rawRows.map((row) {
                  final status = row['status']?.toString().toLowerCase();
                  final type = status == 'completed'
                      ? 'payout_disbursed'
                      : status == 'rejected'
                          ? 'payout_rejected'
                          : 'payout_pending';
                  return <String, dynamic>{
                    'id': row['id'],
                    'type': type,
                    'amount': row['amount'],
                    'payment_method': row['method'],
                    'created_at': row['created_at'],
                  };
                }).toList()
              : rawRows;

          // الرصيد المالي لا يُستنتج من قائمة المعاملات؛ المصدر الوحيد هو ملخص الخادم.
          final summaryReady = _summary?['success'] == true;
          final double availableDigital = summaryReady
              ? ((_summary?['available_balance'] as num?)?.toDouble() ?? 0.0)
              : 0.0;
          final double totalPitchCash = summaryReady
              ? ((_summary?['cash_revenue'] as num?)?.toDouble() ?? 0.0)
              : 0.0;

          if (transactions.isEmpty && (_summary == null || widget.payoutOnly)) {
            return VSPStateView(
              state: VSPUiState.empty,
              icon: Iconsax.receipt_2_1_copy,
              title: isAr ? 'لا توجد معاملات مالية بعد' : 'No financial transactions yet',
              message: isAr
                  ? 'ستظهر هنا التحصيلات والسحوبات والتسويات بعد تسجيلها.'
                  : 'Collections, payouts, and settlements will appear here once recorded.',
            );
          }

          return Column(
            children: [
              if (snapshot.hasError)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(
                    VSPSpacing.md,
                    VSPSpacing.sm,
                    VSPSpacing.md,
                    0,
                  ),
                  padding: const EdgeInsets.all(VSPSpacing.md),
                  decoration: BoxDecoration(
                    color: VSPColors.warning.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(
                      color: VSPColors.warning.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Iconsax.warning_2_copy,
                        color: VSPColors.warning,
                        size: 18,
                      ),
                      const SizedBox(width: VSPSpacing.sm),
                      Expanded(
                        child: Text(
                          isAr
                              ? 'تعذر تحديث المعاملات. المعروض هو آخر سجل تم تحميله.'
                              : 'Could not refresh transactions. Showing the last loaded ledger.',
                          style: const TextStyle(color: VSPColors.textSecondary),
                        ),
                      ),
                      TextButton(
                        onPressed: _retryTransactions,
                        child: Text(isAr ? 'إعادة المحاولة' : 'Retry'),
                      ),
                    ],
                  ),
                ),
              // كارت الرصيد الإلكتروني المتاح للسحب
              OwnerDigitalBalanceCard(
                digitalBalance: availableDigital,
                isAr: isAr,
                onRequestPayout: () => OwnerPayoutDialog.show(context, availableDigital, isAr),
                completedBookingsCount: (_summary?['completed_bookings_count'] as num?)?.toInt(),
                totalWithdrawn: (_summary?['total_withdrawn'] as num?)?.toDouble(),
                upcomingOnlineRevenue: (_summary?['upcoming_online_revenue'] as num?)?.toDouble(),
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
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 4,
                    bottom: MediaQuery.of(context).padding.bottom + 20,
                  ),
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
      ),
    );
  }
}
