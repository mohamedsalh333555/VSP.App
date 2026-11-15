import 'package:supabase_flutter/supabase_flutter.dart';

/// Access to only the new, caller-scoped result-report RPCs. Do not enable
/// these calls in the production booking UI before the server feature gate.
typedef ChallengeReportRpcInvoker = Future<Object?> Function(
  String functionName,
  Map<String, dynamic> parameters,
);

/// A small, non-sensitive command receipt. Never expose an opponent vote,
/// a private appeal reason or administrator review details to the caller.
class ChallengeReportCommandReceipt {
  final bool accepted;
  final bool alreadyApplied;
  final String? state;
  final bool rankingReversed;

  const ChallengeReportCommandReceipt({
    required this.accepted,
    this.alreadyApplied = false,
    this.state,
    this.rankingReversed = false,
  });

  static const rejected = ChallengeReportCommandReceipt(accepted: false);

  static ChallengeReportCommandReceipt fromRpc(Object? raw) {
    if (raw is! Map || raw['success'] != true) return rejected;
    final state = raw['state'];
    return ChallengeReportCommandReceipt(
      accepted: true,
      alreadyApplied: raw['already_submitted'] == true ||
          raw['already_reported'] == true ||
          raw['already_reviewed'] == true,
      state: state is String &&
              (state == 'excluded' ||
                  state == 'restored' ||
                  state == 'under_review')
          ? state
          : null,
      rankingReversed:
          raw['ranking_reversed'] == true || raw['ranking_restored'] == true,
    );
  }
}

class ChallengeNonPlayedReportRepository {
  final SupabaseClient? _client;
  final ChallengeReportRpcInvoker? _rpcOverride;
  final String? Function()? _userIdOverride;
  static const Duration _timeout = Duration(seconds: 12);

  const ChallengeNonPlayedReportRepository({
    SupabaseClient? client,
    ChallengeReportRpcInvoker? rpc,
    String? Function()? currentUserId,
  })  : _client = client,
        _rpcOverride = rpc,
        _userIdOverride = currentUserId;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  String? get _currentUserId => _userIdOverride == null
      ? _supabase.auth.currentUser?.id
      : _userIdOverride();

  bool get _hasAuthenticatedActor => _currentUserId?.isNotEmpty == true;

  Future<Object?> _call(String name, Map<String, dynamic> params) {
    if (_rpcOverride != null) return _rpcOverride(name, params);
    return _supabase.rpc(name, params: params);
  }

  /// Null means unknown/unavailable/not authorized, NEVER "not reported".
  /// A server-verified reported:false response is returned distinctly.
  /// Explicitly copy known fields to avoid leaking any future RPC additions.
  Future<Map<String, Object?>?> fetchMyReportStatus(String bookingId) async {
    if (bookingId.trim().isEmpty || !_hasAuthenticatedActor) return null;
    try {
      final raw = await _call('get_my_challenge_non_played_status', {
        'p_booking_id': bookingId,
      }).timeout(_timeout);
      if (raw is! Map || raw['success'] != true) return null;
      if (raw['reported'] == false && raw['state'] == null) {
        return {'success': true, 'reported': false};
      }
      final state = raw['state'];
      if (raw['reported'] != true ||
          (state != 'excluded' && state != 'restored')) return null;
      return {
        'success': true,
        'reported': true,
        'state': state,
        'under_review': state == 'excluded' && raw['under_review'] == true,
        'my_appeal_submitted': raw['my_appeal_submitted'] == true,
      };
    } catch (_) {
      // Fail closed: stale win badges/actions must be blocked by the
      // reportLookupRequired client gate until this call succeeds.
      return null;
    }
  }

  static bool _validReason(String reason) {
    final count = reason.trim().runes.length;
    return count >= 8 && count <= 500;
  }

  Future<ChallengeReportCommandReceipt> ownerReportNotPlayed({
    required String bookingId,
    required String reason,
  }) => _command(
        'owner_report_challenge_not_played_atomic',
        bookingId: bookingId,
        reason: reason,
      );

  Future<ChallengeReportCommandReceipt> captainAppeal({
    required String bookingId,
    required String reason,
  }) => _command(
        'captain_appeal_challenge_non_played_atomic',
        bookingId: bookingId,
        reason: reason,
      );

  Future<ChallengeReportCommandReceipt> adminReview({
    required String bookingId,
    required String reason,
    required String decision,
  }) async {
    if (decision != 'uphold' && decision != 'restore') {
      return ChallengeReportCommandReceipt.rejected;
    }
    return _command(
      'review_challenge_non_played_atomic',
      bookingId: bookingId,
      reason: reason,
      decision: decision,
    );
  }

  Future<ChallengeReportCommandReceipt> _command(
    String name, {
    required String bookingId,
    required String reason,
    String? decision,
  }) async {
    if (!_hasAuthenticatedActor ||
        bookingId.trim().isEmpty ||
        !_validReason(reason)) {
      return ChallengeReportCommandReceipt.rejected;
    }
    final params = <String, dynamic>{
      'p_booking_id': bookingId,
      'p_reason': reason.trim(),
      if (decision != null) 'p_decision': decision,
    };
    try {
      return ChallengeReportCommandReceipt.fromRpc(
        await _call(name, params).timeout(_timeout),
      );
    } catch (_) {
      // Unknown network outcome: retry only through server-idempotent RPCs.
      // Never automatically trigger financial no-show or refunds.
      return ChallengeReportCommandReceipt.rejected;
    }
  }
}
