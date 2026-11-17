import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/owner/widgets/subscription/owner_plan_comparison_contract.dart';

void main() {
  test('Pro comparison only shows capabilities absent from the Free plan', () {
    final additions = OwnerPlanComparisonContract.additionalProFeatures(
      basicFeatures: {
        'cash_booking': true,
        'online_booking': true,
        'tournament_management': true,
        'ai_insights': false,
        'excel_reports': false,
        'support': 'standard',
      },
      proFeatures: {
        'cash_booking': true,
        'online_booking': true,
        'tournament_management': true,
        'ai_insights': true,
        'excel_reports': true,
        'support': 'priority_24_7',
      },
    );
    expect(additions.keys.toList(), containsAll(
      ['ai_insights', 'excel_reports', 'support'],
    ));
    expect(additions, isNot(contains('cash_booking')));
    expect(additions, isNot(contains('tournament_management')));
    expect(additions['support'], 'priority_24_7');
  });

  test('unknown features, missing rows and disabled capabilities stay hidden', () {
    final additions = OwnerPlanComparisonContract.additionalProFeatures(
      basicFeatures: const {},
      proFeatures: {
        'private_account_data': true,
        'unreviewed_premium_promise': true,
        'ai_insights': 'true',
        'excel_reports': false,
        'support': 'secret_vip_tier',
      },
    );
    expect(additions, isEmpty);
  });

  test('paid plans must not advertise a benefit already in Free', () {
    final additional = OwnerPlanComparisonContract.additionalProFeatures(
      basicFeatures: const {
        'ai_insights': true,
        'support': 'priority_24_7',
      },
      proFeatures: const {
        'ai_insights': true,
        'support': 'priority_24_7',
      },
    );
    expect(additional, isEmpty);
  });

  test('returned comparison snapshot cannot be mutated by callers', () {
    final additions = OwnerPlanComparisonContract.additionalProFeatures(
      basicFeatures: const {},
      proFeatures: const {'ai_insights': true},
    );
    expect(() => additions['fake'] = true, throwsUnsupportedError);
  });

  test('stadium capacity comparison requires valid server-sourced uplift', () {
    expect(OwnerPlanComparisonContract.hasHigherStadiumCapacity(
      freeMaxStadiums: 1, proMaxStadiums: 3,
    ), isTrue);
    expect(OwnerPlanComparisonContract.hasHigherStadiumCapacity(
      freeMaxStadiums: 1, proMaxStadiums: 1,
    ), isFalse);
    expect(OwnerPlanComparisonContract.hasHigherStadiumCapacity(
      freeMaxStadiums: 3, proMaxStadiums: 1,
    ), isFalse);
    expect(OwnerPlanComparisonContract.hasHigherStadiumCapacity(
      freeMaxStadiums: 0, proMaxStadiums: 3,
    ), isFalse);
  });

  test('UI compares only loaded plans without fixed prices or checkout assertions', () {
    final src = File(
      'lib/features/owner/screens/subscription_plans_screen.dart',
    ).readAsStringSync();
    expect(src, contains('_buildPlanComparison(isArabic, _freePlan!, _proPlan!)'));
    expect(src, contains('OwnerPlanComparisonContract.additionalProFeatures('));
    expect(src, contains('OwnerPlanComparisonContract.hasHigherStadiumCapacity('));
    expect(src, contains('final addedLabels = _featureLabels(extras, isArabic)'));
    expect(src, contains('What does Pro add?'));
    expect(src, contains('المزايا المعروضة مأخوذة من تفاصيل الباقات الحالية.'));
    expect(src, contains('Could not load current plan prices and features.'));
    expect(src, contains('fetchPublicPlans()'));
    expect(src, contains("plan['code'] != 'basic'"));
    expect(src, contains('(monthly == 0 && yearly == 0)'));
    expect(src, contains('basicIsActuallyFree &&'));
    expect(src, contains("final copilotIncluded = (plan['features'] as Map)['ai_insights'] == true;"));
    expect(src, contains("copilotIncluded ? ' + Copilot' : ''"));

    // Nothing about a pricing-screen view should fire a paid activation event.
    expect(src, isNot(contains('AnalyticsService.logSubscriptionActivated(')));
  });
}
