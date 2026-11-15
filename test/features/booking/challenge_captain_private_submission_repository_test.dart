import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/repositories/booking/challenge_captain_private_submission_repository.dart';

void main() {
  test('the captain reads only their own validated choice and revision', () async {
    final names = <String>[];
    final repo = ChallengeCaptainPrivateSubmissionRepository(
      currentUserId: () => 'captain',
      rpc: (name, params) async {
        names.add(name);
        expect(params, {'p_booking_id': 'match'});
        return {
          'success': true, 'submitted': true, 'my_outcome': 'homeWin',
          'my_revision': 3, 'submitted_at': 'private timestamp',
          'opponent_outcome': 'awayWin', 'other_captain_id': 'private',
        };
      },
    );
    final myVote = await repo.fetchMySubmission('match');
    expect(myVote?.submitted, true);
    expect(myVote?.myOutcome, ChallengeCaptainOutcome.homeWin);
    expect(myVote?.revision, 3);
    expect(names, ['get_my_challenge_result_submission']);
    expect(myVote.toString(), isNot(contains('awayWin')));
    expect(myVote.toString(), isNot(contains('private')));
  });

  test('unsubmitted state differs from unavailable and unknown payloads', () {
    final noVote = ChallengeCaptainSubmission.fromScopedRpc({
      'success': true, 'submitted': false,
    });
    expect(noVote?.submitted, false);
    expect(noVote?.myOutcome, isNull);
    expect(ChallengeCaptainSubmission.fromScopedRpc({
      'success': false, 'submitted': true, 'my_outcome': 'homeWin',
      'my_revision': 1,
    }), isNull);
    expect(ChallengeCaptainSubmission.fromScopedRpc({
      'success': true, 'submitted': false, 'my_outcome': 'homeWin',
    }), isNull);
    expect(ChallengeCaptainSubmission.fromScopedRpc({
      'success': true, 'submitted': false, 'my_revision': 1,
    }), isNull);
    expect(ChallengeCaptainSubmission.fromScopedRpc({
      'success': true, 'submitted': true, 'my_outcome': 'awayWin',
      'my_revision': 0,
    }), isNull);
    expect(ChallengeCaptainSubmission.fromScopedRpc({
      'success': true, 'submitted': true, 'my_outcome': 'unexpected',
      'my_revision': 1,
    }), isNull);
    expect(ChallengeCaptainSubmission.fromScopedRpc({
      'success': true, 'submitted': true, 'my_outcome': 'draw',
      'my_revision': 2,
    })?.myOutcome, ChallengeCaptainOutcome.draw);
  });

  test('session changes discard a private result read in flight', () async {
    var actor = 'captain-A';
    final pending = Completer<Object?>();
    final repo = ChallengeCaptainPrivateSubmissionRepository(
      currentUserId: () => actor,
      rpc: (name, params) => pending.future,
    );
    final request = repo.fetchMySubmission('match');
    actor = 'captain-B';
    pending.complete({
      'success': true, 'submitted': true,
      'my_outcome': 'homeWin', 'my_revision': 1,
    });
    expect(await request, isNull);
  });

  test('network, unauthenticated access and invalid input fail closed', () async {
    var count = 0;
    final noUser = ChallengeCaptainPrivateSubmissionRepository(
      currentUserId: () => null,
      rpc: (name, params) async {
        count++;
        return {'success': true, 'submitted': false};
      },
    );
    expect(await noUser.fetchMySubmission('match'), isNull);
    expect(count, 0);
    final failed = ChallengeCaptainPrivateSubmissionRepository(
      currentUserId: () => 'captain',
      rpc: (name, params) async => throw StateError('connection lost'),
    );
    expect(await failed.fetchMySubmission('match'), isNull);
    expect(await failed.fetchMySubmission('  '), isNull);
  });
}
