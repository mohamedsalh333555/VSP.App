import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/team_profile/team_profile_head_to_head_panel.dart';

Team _team() => Team(
  id: 'team-a',
  name: 'Falcons',
  captainName: 'Captain',
  captainImageUrl: '',
  date: '',
  stadium: '',
  pricePerPerson: 0,
  currentPlayers: 5,
  maxPlayers: 5,
);

const _oldMatchups = <Map<String, dynamic>>[
  {
    'team_a_id': 'team-a',
    'team_b_id': 'team-b',
    'team_b': {'name': 'Wolves', 'logo_url': ''},
    'team_a_wins': 4,
    'team_b_wins': 1,
    'draws': 0,
  },
];

Widget _wrap({
  required Locale locale,
  required bool isLoading,
  required bool hasError,
  required List<Map<String, dynamic>> records,
  required VoidCallback onRetry,
}) => MaterialApp(
  locale: locale,
  supportedLocales: const [Locale('ar'), Locale('en')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  home: Scaffold(
    body: SingleChildScrollView(
      child: TeamProfileHeadToHeadPanel(
        team: _team(),
        headToHeadRecords: records,
        isLoading: isLoading,
        hasError: hasError,
        onRetry: onRetry,
      ),
    ),
  ),
);

void main() {
  for (final locale in const [Locale('ar'), Locale('en')]) {
    testWidgets('verified empty matchup result stays visible: ${locale.languageCode}',
        (tester) async {
      await tester.pumpWidget(_wrap(
        locale: locale,
        isLoading: false,
        hasError: false,
        records: const [],
        onRetry: () {},
      ));
      final isArabic = locale.languageCode == 'ar';
      expect(find.text(isArabic
          ? 'لا توجد مواجهات مسجلة حتى الآن'
          : 'No recorded matchups yet'), findsOneWidget);
      expect(find.text(isArabic
          ? 'تعذر تحميل سجل المواجهات. لا يتم عرض السجل كأنه فارغ.'
          : 'Match history could not be loaded. It is not being shown as empty.'),
          findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('loading never presents cached scores: ${locale.languageCode}',
        (tester) async {
      await tester.pumpWidget(_wrap(
        locale: locale,
        isLoading: true,
        hasError: false,
        records: _oldMatchups,
        onRetry: () {},
      ));
      expect(find.text(locale.languageCode == 'ar'
          ? 'جارٍ تحميل سجل المواجهات' : 'Loading match history'),
          findsOneWidget);
      expect(find.text('vs Wolves'), findsNothing);
      expect(find.text('ضد Wolves'), findsNothing);
      expect(find.text('4 wins'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('read failure masks cached scores and allows retry: ${locale.languageCode}',
        (tester) async {
      var retries = 0;
      await tester.pumpWidget(_wrap(
        locale: locale,
        isLoading: false,
        hasError: true,
        records: _oldMatchups,
        onRetry: () => retries++,
      ));
      final isArabic = locale.languageCode == 'ar';
      expect(find.text(isArabic
          ? 'تعذر تحميل سجل المواجهات. لا يتم عرض السجل كأنه فارغ.'
          : 'Match history could not be loaded. It is not being shown as empty.'),
          findsOneWidget);
      expect(find.text('vs Wolves'), findsNothing);
      expect(find.text('ضد Wolves'), findsNothing);
      await tester.tap(find.text(isArabic ? 'إعادة المحاولة' : 'Retry'));
      expect(retries, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('verified records render only after read success', (tester) async {
    await tester.pumpWidget(_wrap(
      locale: const Locale('en'),
      isLoading: false,
      hasError: false,
      records: _oldMatchups,
      onRetry: () {},
    ));
    expect(find.text('vs Wolves'), findsOneWidget);
    expect(find.text('Wins: 4 | Draws: 0 | Losses: 1'), findsOneWidget);
    expect(find.text('4 wins'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final locale in const [Locale('ar'), Locale('en')]) {
    testWidgets('contradictory public opponent identity hides score: ${locale.languageCode}',
        (tester) async {
      final contradictory = <Map<String, dynamic>>[
        ..._oldMatchups,
        {
          ..._oldMatchups.single,
          'team_b': {'name': 'Different Wolves', 'logo_url': ''},
        },
        ..._oldMatchups,
      ];
      await tester.pumpWidget(_wrap(
        locale: locale,
        isLoading: false,
        hasError: false,
        records: contradictory,
        onRetry: () {},
      ));
      expect(find.text('vs Wolves'), findsNothing);
      expect(find.text('ضد Wolves'), findsNothing);
      expect(find.text('4 wins'), findsNothing);
      expect(find.text('المواجهات المسجلة: 4 فوز • 0 تعادل • 1 خسارة'),
          findsNothing);
      expect(find.text(locale.languageCode == 'ar'
          ? 'بيانات المواجهات المتاحة غير صالحة للعرض'
          : 'Available head-to-head records cannot be verified'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('mirrored matching opponent rows count once, not twice',
      (tester) async {
    await tester.pumpWidget(_wrap(
      locale: const Locale('en'),
      isLoading: false,
      hasError: false,
      records: [
        ..._oldMatchups,
        {
          'team_a_id': 'team-b',
          'team_b_id': 'team-a',
          'team_a': {'name': 'Wolves', 'logo_url': ''},
          'team_b_wins': 4,
          'team_a_wins': 1,
          'draws': 0,
        },
      ],
      onRetry: () {},
    ));
    expect(find.text('vs Wolves'), findsOneWidget);
    expect(find.text('Recorded matchups: 4 W • 0 D • 1 L'), findsOneWidget);
    expect(find.text('4 wins'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}
