import 'package:supabase_flutter/supabase_flutter.dart';

/// The private captain endpoint returns ONLY this user's submission.
/// Never read the shared legacy bookings.pending_outcome for this value.
enum ChallengeCaptainOutcome { homeWin, draw, awayWin }

class ChallengeCaptainSubmission {
  final bool submitted;
  final ChallengeCaptainOutcome? myOutcome;
  final int? revision;

  const ChallengeCaptainSubmission._({
    required this.submitted,
    this.myOutcome,
    this.revision,
  });

  static ChallengeCaptainSubmission? fromScopedRpc(Object? raw) {
    if (raw is! Map || raw['success'] != true) return null;
    if (raw['submitted'] == false) {
      // Contradictory data is not a valid, unsubmitted private vote.
      if (raw['my_outcome'] != null || raw['my_revision'] != null) return null;
      return const ChallengeCaptainSubmission._(submitted: false);
    }
    if (raw['submitted'] != true) return null;
    final outcome = switch (raw['my_outcome']) {
      'homeWin' => ChallengeCaptainOutcome.homeWin,
      'draw' => ChallengeCaptainOutcome.draw,
      'awayWin' => ChallengeCaptainOutcome.awayWin,
      _ => null,
    };
    final revision = raw['my_revision'];
    if (outcome == null || revision is! int || revision <= 0) return null;
    // Intentionally discard identity, timestamps, future keys and all
    // opponent/internal fields even if returned by a faulty backend.
    return ChallengeCaptainSubmission._(
      submitted: true, myOutcome: outcome, revision: revision,
    );
  }
}

typedef ChallengeCaptainSubmissionRpc = Future<Object?> Function(
  String name, Map<String, dynamic> params,
);

class ChallengeCaptainPrivateSubmissionRepository {
  final SupabaseClient? _client;
  final ChallengeCaptainSubmissionRpc? _rpcOverride;
  final String? Function()? _userIdOverride;

  const ChallengeCaptainPrivateSubmissionRepository({
    SupabaseClient? client,
    ChallengeCaptainSubmissionRpc? rpc,
    String? Function()? currentUserId,
  })  : _client = client,
        _rpcOverride = rpc,
        _userIdOverride = currentUserId;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;
  String? get _currentUserId => _userIdOverride == null
      ? _supabase.auth.currentUser?.id
      : _userIdOverride();

  Future<ChallengeCaptainSubmission?> fetchMySubmission(
      String bookingId) async {
    final actor = _currentUserId;
    if (actor == null || actor.isEmpty || bookingId.trim().isEmpty) return null;
    try {
      final raw = await (_rpcOverride != null
          ? _rpcOverride('get_my_challenge_result_submission', {
              'p_booking_id': bookingId,
            })
          : _supabase.rpc('get_my_challenge_result_submission',
              params: {'p_booking_id': bookingId}))
          .timeout(const Duration(seconds: 12));
      if (_currentUserId != actor) return null;
      return ChallengeCaptainSubmission.fromScopedRpc(raw);
    } catch (_) {
      // Unknown/unavailable never means "the other captain has voted".
      return null;
    }
  }
}
