import 'package:flutter/material.dart';
import '../../../../core/repositories/stadium_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../screens/stadium_details_screen.dart';

/// Safe repeat-booking entrypoint. It opens the *current* stadium page for
/// choosing a NEW slot; this widget cannot create bookings or charges.
class RepeatBookingAction extends StatefulWidget {
  final String stadiumId;
  final bool Function() canContinue;
  final Future<Stadium?> Function(String)? loadLatestStadium;
  final Widget Function(Stadium)? detailsBuilder;

  const RepeatBookingAction({
    super.key,
    required this.stadiumId,
    required this.canContinue,
    this.loadLatestStadium,
    this.detailsBuilder,
  });

  @override
  State<RepeatBookingAction> createState() => _RepeatBookingActionState();
}

class _RepeatBookingActionState extends State<RepeatBookingAction> {
  bool _loading = false;
  bool _hasError = false;
  int _requestEpoch = 0;

  @override
  void didUpdateWidget(covariant RepeatBookingAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A newly allocated callback on parent rebuild is not a new venue.
    // The current callback is checked after fetching for account safety.
    if (oldWidget.stadiumId != widget.stadiumId) {
      _requestEpoch++;
      _loading = false;
      _hasError = false;
    }
  }

  // An auth provider may be disposed while logging out or switching accounts.
  // A failed permission check is a denial, never an unhandled exception.
  bool _currentViewerAllowed() {
    try {
      return widget.canContinue();
    } catch (_) {
      return false;
    }
  }

  Future<void> _openCurrentVenue() async {
    if (_loading || widget.stadiumId.trim().isEmpty ||
        !_currentViewerAllowed()) {
      return;
    }

    final requestId = ++_requestEpoch;
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      // Unlike a cached booking, this query fails closed if offline or stale.
      final latest = await (widget.loadLatestStadium ??
          StadiumRepository().getStadiumByIdStrict)(widget.stadiumId);
      if (!mounted || requestId != _requestEpoch || !_currentViewerAllowed()) {
        return;
      }
      if (latest == null || latest.id != widget.stadiumId ||
          !latest.isVerified || latest.isBlocked || latest.isUnderMaintenance ||
          !latest.basePrice.isFinite || latest.basePrice <= 0) {
        setState(() => _hasError = true);
        return;
      }
      setState(() => _loading = false);
      // The existing details resolver requires another fresh server snapshot
      // before enabling Book Now; the standard booking modal explicitly
      // confirms the new time, price, deposit and payment. No auto-charge.
      Navigator.of(context).push<void>(MaterialPageRoute<void>(
        builder: (_) => widget.detailsBuilder?.call(latest) ??
            StadiumDetailsScreen(stadium: latest),
      ));
    } catch (_) {
      if (mounted && requestId == _requestEpoch && _currentViewerAllowed()) {
        setState(() => _hasError = true);
      }
    } finally {
      if (mounted && requestId == _requestEpoch) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _loading ? null : _openCurrentVenue,
          icon: _loading
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh_rounded, size: 18),
          label: Text(ar ? 'احجز تاني' : 'Book again'),
          style: OutlinedButton.styleFrom(
            foregroundColor: VSPColors.textPrimary,
            side: const BorderSide(color: VSPColors.divider),
            minimumSize: const Size(48, 48),
          ),
        ),
        if (_hasError)
          Padding(
            padding: const EdgeInsets.only(top: VSPSpacing.xs),
            child: Text(
              ar
                  ? 'تعذر التحقق من بيانات الملعب الحالية. جرّب مرة أخرى.'
                  : 'Could not verify the latest venue details. Please retry.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
