import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/core/providers/auth_provider.dart';
import 'package:vsp_application/core/providers/stadium_provider.dart';
import 'package:vsp_application/core/repositories/stadium_repository.dart';
import 'package:vsp_application/data/models.dart';
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

class _AnonymousAuth extends ChangeNotifier implements AuthProvider {
  @override
  bool get isOwner => false;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isGetter) return null;
    return super.noSuchMethod(invocation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> showListing(
    WidgetTester tester,
    StadiumProvider provider, {
    Locale locale = const Locale('en'),
    Widget Function(Stadium)? detailsBuilder,
    ValueListenable<bool>? connectivity,
  }) async {
    final source = connectivity ?? ValueNotifier<bool>(true);
    if (connectivity == null) addTearDown((source as ValueNotifier<bool>).dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<StadiumProvider>.value(value: provider),
          ChangeNotifierProvider<AuthProvider>(create: (_) => _AnonymousAuth()),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AllStadiumsScreen(
            initialGovernorate: 'Cairo',
            detailsBuilder: detailsBuilder,
            connectivityListenable: source,
          ),
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

    repository.request('Cairo', 0).complete({'items': <Stadium>[], 'lastDoc': 0});
    await tester.pumpAndSettle();
    expect(find.text('No Stadiums Found'), findsOneWidget);
    expect(find.text('Reset Filters'), findsOneWidget);

    await tester.tap(find.text('Reset Filters'));
    await tester.pump();
    expect(repository.requests['All'], hasLength(1));
    repository.request('All', 0).complete({'items': <Stadium>[], 'lastDoc': 0});
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
    repository.request('Cairo', 1).complete({'items': <Stadium>[], 'lastDoc': 0});
    await tester.pumpAndSettle();
    expect(find.text('لم يتم العثور على ملاعب'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing optional venue fields do not break the results list', (tester) async {
    final repository = _ListingRepository();
    final provider = StadiumProvider(repository: repository);
    addTearDown(provider.dispose);
    await showListing(tester, provider);

    final partial = Stadium.fromFirestore({
      'id': 'partial-venue',
      'name': 'Partial Pitch',
      'governorate': 'Cairo',
      'is_verified': true,
      'is_blocked': false,
      'is_deleted_by_owner': false,
    }, 'partial-venue');
    repository.request('Cairo', 0).complete({'items': [partial], 'lastDoc': 1});
    await tester.pumpAndSettle();
    expect(find.text('Partial Pitch'), findsOneWidget);
    expect(find.text('No Stadiums Found'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a result opens details for the selected stadium', (tester) async {
    final repository = _ListingRepository();
    final provider = StadiumProvider(repository: repository);
    addTearDown(provider.dispose);
    String? openedId;
    await showListing(tester, provider, detailsBuilder: (stadium) {
      openedId = stadium.id;
      return Scaffold(body: Text('Details: ${stadium.id}'));
    });

    final stadium = Stadium.fromFirestore({
      'id': 'chosen-stadium',
      'name': 'Chosen Stadium',
      'governorate': 'Cairo',
      'is_verified': true,
      'is_blocked': false,
      'is_deleted_by_owner': false,
    }, 'chosen-stadium');
    repository.request('Cairo', 0).complete({'items': [stadium], 'lastDoc': 1});
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chosen Stadium'));
    await tester.pumpAndSettle();
    expect(openedId, 'chosen-stadium');
    expect(find.text('Details: chosen-stadium'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('offline opening offers a truthful state and waits for reconnect', (tester) async {
    final repo = _ListingRepository();
    final provider = StadiumProvider(repository: repo);
    final connectivity = ValueNotifier<bool>(false);
    addTearDown(provider.dispose);
    addTearDown(connectivity.dispose);
    await showListing(tester, provider, connectivity: connectivity);
    expect(find.text('No Internet Connection'), findsOneWidget);
    expect(find.text('No Stadiums Found'), findsNothing);
    expect(repo.requests, isEmpty);

    connectivity.value = true;
    await tester.pump();
    await tester.pump();
    expect(repo.requests['Cairo'], hasLength(1));
    repo.request('Cairo', 0).complete({'items': <Stadium>[], 'lastDoc': 0});
    await tester.pumpAndSettle();
    expect(find.text('No Stadiums Found'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic network loss mid-request ignores stale reply after reconnect', (tester) async {
    final repo = _ListingRepository();
    final provider = StadiumProvider(repository: repo);
    final connectivity = ValueNotifier<bool>(true);
    addTearDown(provider.dispose);
    addTearDown(connectivity.dispose);
    await showListing(tester, provider,
        locale: const Locale('ar'), connectivity: connectivity);
    expect(repo.requests['Cairo'], hasLength(1));

    connectivity.value = false;
    await tester.pump();
    expect(find.text('لا يوجد اتصال بالإنترنت'), findsOneWidget);
    expect(find.text('لم يتم العثور على ملاعب'), findsNothing);

    connectivity.value = true;
    await tester.pump();
    await tester.pump();
    expect(repo.requests['Cairo'], hasLength(2));

    repo.request('Cairo', 1).complete({'items': <Stadium>[], 'lastDoc': 0});
    await tester.pumpAndSettle();
    expect(find.text('لم يتم العثور على ملاعب'), findsOneWidget);
    final stale = Stadium.fromFirestore({
      'id': 'stale-venue', 'name': 'Stale Venue',
      'governorate': 'Cairo', 'is_verified': true,
      'is_blocked': false, 'is_deleted_by_owner': false,
    }, 'stale-venue');
    repo.request('Cairo', 0).complete({'items': [stale], 'lastDoc': 1});
    await tester.pumpAndSettle();
    expect(find.text('Stale Venue'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cached venues stay visible with offline warning and no new pagination', (tester) async {
    final repo = _ListingRepository();
    final provider = StadiumProvider(repository: repo);
    final connectivity = ValueNotifier<bool>(true);
    addTearDown(provider.dispose);
    addTearDown(connectivity.dispose);
    await showListing(tester, provider, connectivity: connectivity);
    final stadium = Stadium.fromFirestore({
      'id': 'cached-venue', 'name': 'Cached Venue',
      'governorate': 'Cairo', 'is_verified': true,
      'is_blocked': false, 'is_deleted_by_owner': false,
    }, 'cached-venue');
    repo.request('Cairo', 0).complete({'items': [stadium], 'lastDoc': 1});
    await tester.pumpAndSettle();
    expect(find.text('Cached Venue'), findsOneWidget);
    connectivity.value = false;
    await tester.pump();
    expect(find.text('Cached Venue'), findsOneWidget);
    expect(find.textContaining('Offline. Showing the last available results'), findsOneWidget);
    expect(find.text('No Internet Connection'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pull to refresh remains pending until the authoritative request resolves',
      (tester) async {
    final repo = _ListingRepository();
    final provider = StadiumProvider(repository: repo);
    final connectivity = ValueNotifier<bool>(true);
    addTearDown(provider.dispose);
    addTearDown(connectivity.dispose);
    await showListing(tester, provider, connectivity: connectivity);

    final venue = Stadium.fromFirestore({
      'id': 'first-venue', 'name': 'First Venue',
      'governorate': 'Cairo', 'is_verified': true,
      'is_blocked': false, 'is_deleted_by_owner': false,
    }, 'first-venue');
    repo.request('Cairo', 0).complete({'items': <Stadium>[venue], 'lastDoc': 1});
    await tester.pumpAndSettle();

    // Drag a real one-item list rather than forcing RefreshIndicator.show().
    // An unscrollable list would silently prevent users from refreshing.
    final resultsList = find.descendant(
      of: find.byType(RefreshIndicator),
      matching: find.byType(ListView),
    );
    expect(resultsList, findsOneWidget);
    expect(
      tester.widget<ListView>(resultsList).physics,
      isA<AlwaysScrollableScrollPhysics>(),
    );
    await tester.drag(resultsList, const Offset(0, 450));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(repo.requests['Cairo'], hasLength(2));
    expect(provider.isLoading, isTrue);

    repo.request('Cairo', 1).complete({'items': <Stadium>[venue], 'lastDoc': 1});
    await tester.pumpAndSettle();
    expect(provider.isLoading, isFalse);
    expect(find.text('First Venue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}
