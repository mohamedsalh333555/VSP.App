import 'package:flutter/material.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/vsp_ui.dart';
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: VSPColors.background,
    body: SafeArea(
      child: VSPStateView(
        state: VSPUiState.loading,
        title: Localizations.localeOf(context).languageCode == 'ar' ? 'جارٍ فتح الدعوة' : 'Opening invitation',
        message: Localizations.localeOf(context).languageCode == 'ar' ? 'نجهّز تفاصيل الحجز والدعوة.' : 'Preparing booking and invitation details.',
      ),
    ),
  );
}