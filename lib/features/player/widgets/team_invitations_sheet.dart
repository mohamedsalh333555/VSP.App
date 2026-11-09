import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/team_repository.dart';

/// Player-owned inbox: invitations do not become memberships until accepted.
class TeamInvitationsSheet extends StatefulWidget {
  const TeamInvitationsSheet({super.key, required this.userId});

  final String userId;

  @override
  State<TeamInvitationsSheet> createState() => _TeamInvitationsSheetState();
}

class _TeamInvitationsSheetState extends State<TeamInvitationsSheet> {
  late Future<List<Map<String, dynamic>>> _pending;
  String? _busyId;
  int _requestGeneration = 0;

  bool get _isCurrentAccount =>
      context.read<AuthProvider>().currentUser?.id == widget.userId;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant TeamInvitationsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _busyId = null;
      _refresh();
    }
  }

  void _refresh() {
    _requestGeneration++;
    _pending = TeamRepository().getPendingTeamInvitations(widget.userId);
  }

  Future<void> _respond(String id, bool accept) async {
    if (_busyId != null) return;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    if (!_isCurrentAccount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تغيّر الحساب الحالي. افتح الدعوات من الحساب الصحيح.'
                : 'The active account changed. Open invitations from the correct account.',
          ),
        ),
      );
      return;
    }

    final requestUserId = widget.userId;
    final generation = _requestGeneration;
    setState(() => _busyId = id);
    try {
      await TeamRepository().respondToTeamInvitation(id, accept: accept);
      if (!mounted ||
          generation != _requestGeneration ||
          requestUserId != widget.userId ||
          !_isCurrentAccount) {
        return;
      }
      setState(_refresh);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? (isArabic ? 'تم قبول الدعوة' : 'Invitation accepted')
                : (isArabic ? 'تم رفض الدعوة' : 'Invitation declined'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted ||
          generation != _requestGeneration ||
          requestUserId != widget.userId ||
          !_isCurrentAccount) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تعذر الرد على الدعوة. ربما انتهت أو تم التعامل معها بالفعل.'
                : 'Could not respond. The invitation may have expired or already been handled.',
          ),
        ),
      );
    } finally {
      if (mounted &&
          generation == _requestGeneration &&
          requestUserId == widget.userId) {
        setState(() => _busyId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final activeUserId = context.watch<AuthProvider>().currentUser?.id;
    final accountMatches = activeUserId == widget.userId;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isArabic ? 'دعوات الفرق' : 'Team invitations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (!accountMatches)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  isArabic
                      ? 'هذه الدعوات تخص حسابًا آخر. أغلق النافذة وافتحها من الحساب الحالي.'
                      : 'These invitations belong to another account. Close this sheet and reopen it from the active account.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              Flexible(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _pending,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isArabic
                                ? 'تعذر تحميل الدعوات'
                                : 'Could not load invitations',
                          ),
                          TextButton(
                            onPressed: () => setState(_refresh),
                            child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
                          ),
                        ],
                      );
                    }
                    final invitations = snapshot.data ?? [];
                    if (invitations.isEmpty) {
                      return Text(
                        isArabic
                            ? 'لا توجد دعوات معلقة'
                            : 'No pending invitations',
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: invitations.length,
                      itemBuilder: (context, index) {
                        final invitation = invitations[index];
                        final id = invitation['id']?.toString().trim();
                        final hasValidId =
                            id != null && id.isNotEmpty && id != 'null';
                        final teamName =
                            invitation['team_name']?.toString().trim();
                        final isBusy = _busyId == id;
                        return ListTile(
                          title: Text(
                            isArabic
                                ? 'دعوة للانضمام إلى فريق'
                                : 'Invitation to join a team',
                          ),
                          subtitle: Text(
                            teamName?.isNotEmpty == true
                                ? teamName!
                                : (isArabic
                                    ? 'فريق غير متاح'
                                    : 'Team unavailable'),
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              TextButton(
                                onPressed:
                                    _busyId == null && hasValidId
                                        ? () => _respond(id, false)
                                        : null,
                                child: Text(
                                  isBusy
                                      ? '…'
                                      : (isArabic ? 'رفض' : 'Decline'),
                                ),
                              ),
                              FilledButton(
                                onPressed:
                                    _busyId == null && hasValidId
                                        ? () => _respond(id, true)
                                        : null,
                                child: Text(
                                  isBusy
                                      ? '…'
                                      : (isArabic ? 'قبول' : 'Accept'),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
