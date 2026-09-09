import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/owner/widgets/ledger/owner_ledger_balance_cards.dart';
import 'package:vsp_application/features/owner/widgets/ledger/owner_ledger_transaction_item.dart';

void main() {
  group('Owner Ledger Components Widget Tests', () {
    testWidgets('OwnerDigitalBalanceCard displays balance and calls payout callback', (tester) async {
      bool payoutTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OwnerDigitalBalanceCard(
              digitalBalance: 2500.0,
              isAr: false,
              onRequestPayout: () => payoutTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('2500 EGP'), findsOneWidget);
      expect(find.text('Request Payout Settlement'), findsOneWidget);

      await tester.tap(find.text('Request Payout Settlement'));
      await tester.pump();
      expect(payoutTapped, isTrue);
    });

    testWidgets('OwnerPitchCashCard displays cash amount', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OwnerPitchCashCard(
              pitchCash: 1200.0,
              isAr: false,
            ),
          ),
        ),
      );

      expect(find.text('1200 EGP'), findsOneWidget);
      expect(find.text('Pitch Cash Collected'), findsOneWidget);
    });

    testWidgets('OwnerLedgerTransactionItem formats digital payment item', (tester) async {
      final tx = {
        'type': 'digital',
        'payment_method': 'paymob',
        'amount': 450.0,
        'created_at': '2026-09-09T12:00:00Z',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OwnerLedgerTransactionItem(
              transaction: tx,
              isAr: false,
            ),
          ),
        ),
      );

      expect(find.text('Digital Online Payment'), findsOneWidget);
      expect(find.text('+450 EGP'), findsOneWidget);
    });
  });
}
