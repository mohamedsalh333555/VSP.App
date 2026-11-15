import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/repositories/booking/challenge_non_played_report_repository.dart';

void main() {
  test('status reader returns only caller-safe fields; no report is distinct', () async {
    var payload = <String, dynamic>{
      'success': true, 'reported': true, 'state': 'excluded',
      'under_review': true, 'my_appeal_submitted': true,
      'opponent_outcome': 'awayWin',
      'other_captain_appeal_reason': 'Never disclose',
      'admin_review_reason': 'Private evidence',
    };
    final requests = <String>[];
    final repo = ChallengeNonPlayedReportRepository(
      currentUserId: () => 'captain',
      rpc: (name, args) async {
        requests.add(name);
        expect(args, {'p_booking_id': 'booking-uuid'});
        return payload;
      },
    );
    final safe = await repo.fetchMyReportStatus('booking-uuid');
    expect(safe, {
      'success': true, 'reported': true, 'state': 'excluded',
      'under_review': true, 'my_appeal_submitted': true,
    });
    expect(safe!.toString(), isNot(contains('awayWin')));
    expect(safe.toString(), isNot(contains('Never disclose')));
    expect(safe.toString(), isNot(contains('Private evidence')));
    payload = {'success': true, 'reported': false};
    expect(await repo.fetchMyReportStatus('booking-uuid'),
        {'success': true, 'reported': false});
    payload = {'success': true, 'reported': false, 'state': 'excluded'};
    expect(await repo.fetchMyReportStatus('booking-uuid'), isNull);
    payload = {'success': false, 'error': 'NOT_AUTHORIZED'};
    expect(await repo.fetchMyReportStatus('booking-uuid'), isNull);
    payload = {'success': true, 'reported': true, 'state': 'somethingNew'};
    expect(await repo.fetchMyReportStatus('booking-uuid'), isNull);
    expect(requests, everyElement('get_my_challenge_non_played_status'));
  });

  test('no authenticated actor or failed RPC never means no report', () async {
    var calls = 0;
    final noUser = ChallengeNonPlayedReportRepository(
      currentUserId: () => null,
      rpc: (name, args) async {
        calls++;
        return {'success': true, 'reported': false};
      },
    );
    expect(await noUser.fetchMyReportStatus('booking-uuid'), isNull);
    expect((await noUser.ownerReportNotPlayed(
      bookingId: 'booking-uuid', reason: 'Match did not happen')).accepted, isFalse);
    expect(calls, 0);
    final error = ChallengeNonPlayedReportRepository(
      currentUserId: () => 'owner',
      rpc: (name, args) async => throw StateError('network dropped'),
    );
    expect(await error.fetchMyReportStatus('booking-uuid'), isNull);
    expect((await error.ownerReportNotPlayed(
      bookingId: 'booking-uuid', reason: 'The booking did not happen')).accepted,
      isFalse);
  });

  test('report and appeal use independent nonfinancial RPCs and idempotent receipts', () async {
    final called = <String>[];
    final params = <Map<String, dynamic>>[];
    final repo = ChallengeNonPlayedReportRepository(
      currentUserId: () => 'actor',
      rpc: (name, args) async {
        called.add(name);
        params.add(args);
        return {
          'success': true,
          'state': switch (name) {
            'captain_appeal_challenge_non_played_atomic' => 'under_review',
            'review_challenge_non_played_atomic' => 'restored',
            _ => 'excluded',
          },
          'already_reported': true,
          'ranking_reversed': true,
        };
      },
    );
    final owner = await repo.ownerReportNotPlayed(
      bookingId: 'booking-uuid', reason: '  The match was not played  ',
    );
    final captain = await repo.captainAppeal(
      bookingId: 'booking-uuid', reason: 'Our match was played',
    );
    final admin = await repo.adminReview(
      bookingId: 'booking-uuid', reason: 'Reviewed the available evidence',
      decision: 'restore',
    );
    expect(owner.accepted && owner.alreadyApplied && owner.rankingReversed, isTrue);
    expect(captain.accepted && admin.accepted, isTrue);
    expect(called, [
      'owner_report_challenge_not_played_atomic',
      'captain_appeal_challenge_non_played_atomic',
      'review_challenge_non_played_atomic',
    ]);
    expect(params[0]['p_reason'], 'The match was not played');
    expect(params[2]['p_decision'], 'restore');
    expect(called.where((s) => s.contains('no_show')), isEmpty);
  });

  test('malformed success acknowledgements are not accepted', () async {
    expect(
      ChallengeReportCommandReceipt.fromRpc({'success': true}).accepted,
      isFalse,
    );
    expect(
      ChallengeReportCommandReceipt.fromRpc({
        'success': true, 'state': 'pending',
      }).accepted,
      isFalse,
    );
    final repo = ChallengeNonPlayedReportRepository(
      currentUserId: () => 'actor',
      rpc: (name, args) async => {
        'success': true,
        // A review must never call itself restored if the server upheld it.
        'state': 'excluded',
      },
    );
    final receipt = await repo.adminReview(
      bookingId: 'book-uuid',
      reason: 'Reviewed all available match evidence',
      decision: 'restore',
    );
    expect(receipt.accepted, isFalse);
  });

  test('invalid reason, empty booking and review decision never reach server', () async {
    final calls = <String>[];
    final repo = ChallengeNonPlayedReportRepository(
      currentUserId: () => 'captain',
      rpc: (name, args) async {
        calls.add(name);
        return {'success': true};
      },
    );
    expect((await repo.ownerReportNotPlayed(
      bookingId: '', reason: 'The match was not played')).accepted, isFalse);
    expect((await repo.captainAppeal(
      bookingId: 'uuid', reason: 'short')).accepted, isFalse);
    expect((await repo.adminReview(
      bookingId: 'uuid', reason: 'Checked the match evidence',
      decision: 'delete')).accepted, isFalse);
    expect(calls, isEmpty);
  });
}
