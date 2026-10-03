import 'package:flutter/material.dart';
import 'collective_match_invite_sheet.dart';

class CollectiveMatchInviteRoute extends StatefulWidget {
  final String inviteToken;
  const CollectiveMatchInviteRoute({super.key, required this.inviteToken});

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      CollectiveMatchInviteSheet.showForInvite(
        context,
        inviteToken: widget.inviteToken,
      ).then((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Color(0xFF101114),
    body: Center(child: CircularProgressIndicator()),
  );
}