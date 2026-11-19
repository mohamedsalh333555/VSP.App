import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/owner/widgets/dashboard/owner_operational_finance_card.dart';

Widget host({
  required bool revenueVerified,
  bool revenueLoading = false,
  bool balanceVerified = false,
  bool isPro = true,
}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: OwnerOperationalFinanceCard(
        collectedCash: 12345.67,
        collectedOnline: 9876.54,
        cashDue: 6543.21,
        onlinePending: 8765.43,
        onlineHeld: 2468.13,
        upcomingValue: 1234.56,
        availableBalance: 4567.89,
        revenueVerified: revenueVerified,
        revenueLoading: revenueLoading,
        balanceVerified: balanceVerified,
        isProOwner: isPro,
        onOpenLedger: () {},
        onRequestPayout: () {},
        isArabic: false,
      ),
    ),
  ),
);

void main() {
  testWidgets('unverified server revenue displays unknown rather than 0 or stale amounts',
      (tester) async {
    await tester.pumpWidget(host(revenueVerified: false));
    expect(find.textContaining('Collection totals could not be verified.'),
        findsOneWidget);
    expect(find.text('—'), findsAtLeastNWidgets(3));
    expect(find.text('Withdrawal balance unavailable'), findsOneWidget);
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.textContaining('12345'), findsNothing);
    expect(find.textContaining('9876'), findsNothing);
    expect(find.textContaining('6543'), findsNothing);
    expect(find.textContaining('8765'), findsNothing);
    expect(find.textContaining('1234'), findsNothing);
    expect(find.textContaining('Money still to collect'), findsNothing);
  });

  testWidgets('refresh shows verifying, not previous revenue from another venue',
      (tester) async {
    await tester.pumpWidget(host(
      revenueVerified: true,
      balanceVerified: true,
    ));
    expect(find.textContaining('Collection totals could not be verified.'),
        findsNothing);
    await tester.pumpWidget(host(
      revenueVerified: false,
      revenueLoading: true,
    ));
    expect(find.text('Verifying current collection amounts.'),
        findsOneWidget);
    expect(find.text('—'), findsAtLeastNWidgets(3));
    expect(find.textContaining('Money still to collect'), findsNothing);
  });

  testWidgets('free plan also hides unverified balances instead of showing zero',
      (tester) async {
    await tester.pumpWidget(host(
      revenueVerified: false,
      isPro: false,
    ));
    expect(find.textContaining('Collection totals could not be verified.'),
        findsOneWidget);
    expect(find.text('—'), findsAtLeastNWidgets(3));
    expect(find.textContaining('Upcoming confirmed bookings'), findsNothing);
  });

  test('dashboard invalidates cached analytics when requests run or fail', () {
    final dashboard = File(
      'lib/features/owner/screens/owner_dashboard_screen.dart',
    ).readAsStringSync();
    final card = File(
      'lib/features/owner/widgets/dashboard/owner_operational_finance_card.dart',
    ).readAsStringSync();
    expect(dashboard, contains('_hasLoadedAnalytics && !_isLoadingAnalytics && _analyticsError == null'));
    expect(dashboard, contains('revenueVerified: _hasVerifiedCurrentAnalytics'));
    expect(dashboard, contains('revenueLoading: _isLoadingAnalytics'));
    expect(dashboard, contains('analytics: _hasVerifiedCurrentAnalytics ? _dashboardAnalytics : null'));
    expect(dashboard, contains('isInitialLoading: _isLoadingAnalytics'));
    expect(dashboard, contains('hasInitialLoadError: _analyticsError != null'));
    expect(card, contains('revenueVerified ? VSPMoneyFormatter.amount(collectedTotal) : \'—\''));
    expect(card, contains('if (revenueVerified && upcomingValue > 0.009)'));
  });
}
