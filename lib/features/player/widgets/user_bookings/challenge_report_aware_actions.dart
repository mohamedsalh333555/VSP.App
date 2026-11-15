import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/challenge_result_rollout_flags.dart';
import '../../../../core/repositories/booking/challenge_non_played_report_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import 'challenge_non_played_report_status.dart';
import 'challenge_result_actions.dart';

typedef ChallengeReportStatusLoader =
    Future<Map<String, Object?>?> Function(String bookingId);

/// The only bridge from the existing player card to the new scoped
/// report-status RPC. By default the original UX remains unchanged.
/// Opt-in MUST be held until all result/report/feed SQL is verified.
class ChallengeReportAwareActions extends StatefulWidget {
  final Booking booking;
  final String? myTeamId;
  final bool badgeOnly;
  final bool reportFeatureEnabled;
  final ChallengeReportStatusLoader? statusLoader;

  const ChallengeReportAwareActions({
    super.key,
    required this.booking,
    required this.myTeamId,
    this.badgeOnly = false,
    this.reportFeatureEnabled =
        ChallengeResultRolloutFlags.nonPlayedReportsEnabled,
    this.statusLoader,
  });

  @override
  State<ChallengeReportAwareActions> createState() =>
      _ChallengeReportAwareActionsState();
}

class _ChallengeReportAwareActionsState
    extends State<ChallengeReportAwareActions> {
  Future<Map<String, Object?>?>? _pending;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _subscribe();
    _startLookup();
  }

  void _subscribe() {
    if (!widget.reportFeatureEnabled || widget.statusLoader != null) return;
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      // Reset a previously loaded private "my_appeal_submitted" flag on
      // account switch. The repository independently guards in-flight RPCs.
      if (mounted) _reload();
    });
  }

  void _startLookup() {
    if (!widget.reportFeatureEnabled || widget.myTeamId == null) {
      _pending = null;
      return;
    }
    final fetcher = widget.statusLoader ??
        ChallengeNonPlayedReportRepository().fetchMyReportStatus;
    _pending = fetcher(widget.booking.id);
  }

  void _reload() {
    if (!mounted) return;
    setState(_startLookup);
  }

  @override
  void didUpdateWidget(covariant ChallengeReportAwareActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reportFeatureEnabled != widget.reportFeatureEnabled ||
        oldWidget.statusLoader != widget.statusLoader) {
      _authSubscription?.cancel();
      _authSubscription = null;
      _subscribe();
      _startLookup();
    } else if (oldWidget.booking.id != widget.booking.id ||
        oldWidget.myTeamId != widget.myTeamId ||
        oldWidget.booking.status != widget.booking.status ||
        oldWidget.booking.matchResultStatus !=
            widget.booking.matchResultStatus ||
        oldWidget.booking.finalOutcome != widget.booking.finalOutcome) {
      _startLookup();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Widget _render(BuildContext context, {
    ChallengeNonPlayedReportStatus? status,
    required bool gated,
  }) {
    if (widget.badgeOnly) {
      return ChallengeResultActions.buildChallengeStatusBadge(
        context,
        booking: widget.booking,
        myTeamId: widget.myTeamId,
        reportStatus: status,
        reportLookupRequired: gated,
      );
    }
    return ChallengeResultActions(
      booking: widget.booking,
      myTeamId: widget.myTeamId,
      reportStatus: status,
      reportLookupRequired: gated,
      allowAppeal: gated,
      onReportChanged: _reload,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.myTeamId == null) return const SizedBox.shrink();
    if (!widget.reportFeatureEnabled) {
      return _render(context, gated: false);
    }
    return FutureBuilder<Map<String, Object?>?>(
      future: _pending,
      builder: (context, snapshot) {
        final status =
            ChallengeNonPlayedReportStatus.fromScopedRpc(snapshot.data);
        if (widget.badgeOnly) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            final isArabic = Localizations.localeOf(context).languageCode == 'ar';
            return ChallengeResultActions.buildStatusBadge(
              isArabic
                  ? 'جارٍ التحقق من بلاغ المباراة'
                  : 'Checking match report status',
              VSPColors.warning,
            );
          }
          if (status == null) {
            final isArabic = Localizations.localeOf(context).languageCode == 'ar';
            return ChallengeResultActions.buildStatusBadge(
              isArabic ? 'حالة المباراة غير متاحة' : 'Match status unavailable',
              VSPColors.warning,
            );
          }
          return _render(context, status: status, gated: true);
        }

        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ChallengeResultActions.buildStatusBadge(
            isArabic
                ? 'جارٍ التحقق من حالة المباراة'
                : 'Checking match status',
            VSPColors.warning,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _render(context, status: status, gated: true),
            const SizedBox(height: VSPSpacing.xs),
            TextButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(isArabic
                  ? 'تحديث حالة المباراة'
                  : 'Refresh match status'),
            ),
          ],
        );
      },
    );
  }
}
