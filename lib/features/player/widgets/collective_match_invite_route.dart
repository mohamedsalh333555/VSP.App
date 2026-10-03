import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/match_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated || auth.userModel == null) return;
    try {
      final data = await MatchRepository().getPrivateCollectiveInviteDetails(widget.inviteToken);
      if (!mounted) return;
      if (data == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الدعوة غير متاحة أو انتهت.')));
        context.go('/player');
        return;
      }
      await CollectiveMatchInviteSheet.showInviteData(context, data);
      if (mounted) context.go('/player');
    } catch (_) {
      if (mounted) context.go('/player');
    }
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: VSPColors.background,
    body: Center(child: CircularProgressIndicator(color: VSPColors.accent)),
  );
}