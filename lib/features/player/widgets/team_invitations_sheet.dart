import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _pending = TeamRepository().getPendingTeamInvitations(widget.userId);
  }

  Future<void> _respond(String id, bool accept) async {
    if (_busyId != null) return;
    setState(() => _busyId = id);
    try {
      await TeamRepository().respondToTeamInvitation(id, accept: accept);
      if (!mounted) return;
      setState(_refresh);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(accept ? 'تم قبول الدعوة' : 'تم رفض الدعوة')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر الرد على الدعوة. حاول مرة أخرى.')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
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
                        Text(isArabic ? 'تعذر تحميل الدعوات' : 'Could not load invitations'),
                        TextButton(
                          onPressed: () => setState(_refresh),
                          child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
                        ),
                      ],
                    );
                  }
                  final invitations = snapshot.data ?? [];
                  if (invitations.isEmpty) {
                    return Text(isArabic ? 'لا توجد دعوات معلقة' : 'No pending invitations');
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: invitations.length,
                    itemBuilder: (context, index) {
                      final invitation = invitations[index];
                      final id = invitation['id']?.toString().trim();
                      final hasValidId = id != null && id.isNotEmpty && id != 'null';
                      return ListTile(
                        title: Text(isArabic ? 'دعوة للانضمام إلى فريق' : 'Invitation to join a team'),
                        subtitle: Text(
                          (invitation['team_name']?.toString().trim().isNotEmpty ?? false)
                              ? invitation['team_name'].toString()
                              : (isArabic ? 'فريق غير متاح' : 'Team unavailable'),
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            TextButton(
                              onPressed: _busyId == null && hasValidId ? () => _respond(id!, false) : null,
                              child: Text(isArabic ? 'رفض' : 'Decline'),
                            ),
                            FilledButton(
                              onPressed: _busyId == null && hasValidId ? () => _respond(id!, true) : null,
                              child: Text(isArabic ? 'قبول' : 'Accept'),
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
