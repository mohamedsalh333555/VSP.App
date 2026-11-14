import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/core/providers/stadium_provider.dart';
import 'package:vsp_application/core/repositories/stadium_repository.dart';
import 'package:vsp_application/features/player/screens/all_stadiums_screen.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

class _ListingRepository extends StadiumRepository {
  final requests = <String, List<Completer<Map<String, dynamic>>>>{};

  @override
  Future<Map<String, dynamic>> getStadiumsPaginated({
    int limit = 10,
    dynamic startAfter,
    String? governorate,
    String? sportType,
    String? pitchSize,
    List<String>? sportTypes,
    List<String>? pitchSizes,
    double? minPrice,
    double? maxPrice,
    bool? noDepositOnly,
    List<String>? amenities,
    String? quickFilter,
    String? floorType,
    String? searchQuery,
    String? sortBy,
  }) {
    final result = Completer<Map<String, dynamic>>();
    requests.putIfAbsent(governorate ?? 'All', () => []).add(result);
    return result.future;
  }

  Completer<Map<String, dynamic>> request(String governorate, int index) =>
      requests[governorate]![index];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> showListing(
    WidgetTester tester,
    StadiumProvider provider, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<StadiumProvider>.value(
        value: provider,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AllStadiumsScreen(initialGovernorate: 'Cairo'),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('no matching governorate results show a reset action', (tester) async {
    final repository = _ListingRepository();
    final provider = StadiumProvider(repository: repository);
    addTearDown(provider.dispose);
    await showListing(tester, provider);

    repository.request('Cairo', 0).complete({'items': [], 'lastDoc': 0});
    await tester.pumpAndSettle();
    expect(find.text('No Stadiums Found'), findsOneWidget);
    expect(find.text('Reset Filters'), findsOneWidget);

    await tester.tap(find.text('Reset Filters'));
    await tester.pump();
    expect(repository.requests['All'], hasLength(1));
    repository.request('All', 0).complete({'items': [], 'lastDoc': 0});
    await tester.pumpAndSettle();
    expect(find.text('No Stadiums Found'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('malformed result shows safe error and retry in Arabic', (tester) async {
    final repository = _ListingRepository();
    final provider = StadiumProvider(repository: repository);
    addTearDown(provider.dispose);
    await showListing(tester, provider, locale: const Locale('ar'));

    repository.request('Cairo', 0).complete({'items': 'PRIVATE_BAD_PAYLOAD', 'lastDoc': 0});
    await tester.pumpAndSettle();
    expect(find.text('تعذر تحميل الملاعب'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(find.textContaining('PRIVATE_BAD_PAYLOAD'), findsNothing);

    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pump();
    expect(repository.requests['Cairo'], hasLength(2));
    repository.request('Cairo', 1).complete({'items': [], 'lastDoc': 0});
    await tester.pumpAndSettle();
    expect(find.text('لم يتم العثور على ملاعب'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
