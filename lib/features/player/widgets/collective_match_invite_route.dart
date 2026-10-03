import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/match_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../data/models.dart';
import 'collective_match_invite_sheet.dart';

class CollectiveMatchInviteRoute extends StatefulWidget {
  final String bookingId;
  const CollectiveMatchInviteRoute({super.key, required this.bookingId});

  @override
  State<CollectiveMatchInviteRoute> createState() => _CollectiveMatchInviteRouteState();
}

class _CollectiveMatchInviteRouteState extends State<CollectiveMatchInviteRoute> {
  bool _opened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated || auth.userModel == null) return;

    Booking? booking;
    try {
      booking = await MatchRepository().getPublicMatchDetails(widget.bookingId);
    } catch (_) {}

    if (!mounted) return;
    if (booking == null || !booking.isOpenJoin) {
      context.go('/match/${widget.bookingId}');
      return;
    }

    await CollectiveMatchInviteSheet.show(context, bookingId: widget.bookingId, initialBooking: booking);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: VSPColors.background,
    body: Center(child: CircularProgressIndicator(color: VSPColors.accent)),
  );
}
