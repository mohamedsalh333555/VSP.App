import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/repositories/matchup_repository.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/services/matchup_dashboard_service.dart';

class _HistoryRepo extends MatchupRepository {
  final Future<List<MatchupTeam>> Function(String) loadTeams;
  final Future<List<MatchupResult>> Function(String) loadResults;
  _HistoryRepo({required this.loadTeams, required this.loadResults});

  @override
  Future<List<MatchupTeam>> getMatchupTeamsStrict(String bookingId) =>
      loadTeams(bookingId);

  @override
  Future<List<MatchupResult>> getMatchupResultsStrict(String bookingId) =>
      loadResults(bookingId);
}

void main() {
  test('strict result/roster fetch failures propagate; legacy returns empty',
      () async {
    final repo = _HistoryRepo(
      loadTeams: (_) async => throw StateError('private roster token'),
      loadResults: (_) async => throw StateError('private result token'),
    );
    await expectLater(
        repo.getMatchupTeamsStrict('match'), throwsA(isA<StateError>()));
    await expectLater(
        repo.getMatchupResultsStrict('match'), throwsA(isA<StateError>()));
    expect(await repo.getMatchupTeams('match'), isEmpty);
    expect(await repo.getMatchupResults('match'), isEmpty);
  });

  test('strict legitimate empty state remains distinguishable from outage',
      () async {
    final repo = _HistoryRepo(
      loadTeams: (_) async => [],
      loadResults: (_) async => [],
    );
    expect(await repo.getMatchupTeamsStrict('match'), isEmpty);
    expect(await repo.getMatchupResultsStrict('match'), isEmpty);
  });

  test('match result and closure receipts require authoritative booking scope',
      () {
    expect(MatchupDashboardService.isConfirmedMutationReceipt(
        {'success': true,'booking_id': 'match','result_id': 'result'},
        bookingId: 'match', requireResultId: true), isTrue);
    for (final bad in <Object?>[
      null,
      {'success': false,'booking_id':'match','result_id':'result'},
      {'success': true,'booking_id':'other','result_id':'result'},
      {'success': true,'booking_id':'match','result_id':''},
      {'success': true,'booking_id':'match'},
    ]) {
      expect(MatchupDashboardService.isConfirmedMutationReceipt(
          bad,bookingId:'match',requireResultId:true), isFalse);
    }
    expect(MatchupDashboardService.isConfirmedMutationReceipt(
        {'success': true,'booking_id':'match','already_closed':true},
        bookingId:'match'), isTrue);
    expect(MatchupDashboardService.isConfirmedMutationReceipt(
        {'success': false,'booking_id':'match'},bookingId:'match'), isFalse);
    expect(MatchupDashboardService.isConfirmedMutationReceipt(
        {'success': true,'booking_id':'different'},bookingId:'match'), isFalse);
  });

  test('live matchup dashboard requires strict reads and validated receipts',
      () {
    final source = File(
      'lib/features/player/screens/matchup_live_dashboard_screen.dart',
    ).readAsStringSync();
    expect(source, contains('getMatchupTeamsStrict(requestedBookingId)'));
    expect(source, contains('getMatchupResultsStrict(requestedBookingId)'));
    expect(source, contains('isConfirmedMutationReceipt('));
    expect(source, contains('widget.bookingId != requestedBookingId'));
    expect(source, contains('_hasLoadError = true'));
    for (final log in source.split('\n').where(
        (line) => line.contains('debugPrint('))) {
      expect(RegExp(r'\$(?:e|error|teamId|bookingId|uid)\b')
          .hasMatch(log), isFalse, reason: log);
    }
  });
}
