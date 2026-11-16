import 'package:flutter/material.dart';
import '../../../../core/repositories/team_skills_cup_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Award history is derived only from officially announced, completed cups.
/// It is separate from legacy 1v1 trophies and team challenge Elo scores.
class TeamSkillsHistorySection extends StatefulWidget {
  final String participantId;
  final bool isTeam;
  final TeamSkillsCupRepository? repository;

  const TeamSkillsHistorySection({
    super.key,
    required this.participantId,
    required this.isTeam,
    this.repository,
  });

  @override
  State<TeamSkillsHistorySection> createState() => _TeamSkillsHistorySectionState();
}

class _TeamSkillsHistorySectionState extends State<TeamSkillsHistorySection> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() { super.initState(); _refresh(); }

  @override
  void didUpdateWidget(covariant TeamSkillsHistorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.participantId != widget.participantId ||
        oldWidget.isTeam != widget.isTeam) {
      _refresh();
    }
  }

  void _refresh() {
    final repo = widget.repository ?? TeamSkillsCupRepository();
    _future = widget.isTeam
        ? repo.getTeamHistory(widget.participantId)
        : repo.getPlayerHistory(widget.participantId);
  }

  @override
  Widget build(BuildContext context) {
    const enabled = bool.fromEnvironment(
      'VSP_ENABLE_TEAM_SKILLS_CUP', defaultValue: false,
    );
    if (!enabled || widget.participantId.isEmpty) {
      return const SizedBox.shrink();
    }
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(VSPSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Row(children: [
            Expanded(child: Text(
              ar ? 'تعذر تحميل إنجازات مهارات الفرق' : 'Could not load Team Skills awards',
              style: const TextStyle(color: VSPColors.textSecondary),
            )),
            TextButton(onPressed: () => setState(_refresh),
              child: Text(ar ? 'إعادة المحاولة' : 'Retry')),
          ]);
        }
        final history = snapshot.data ?? const <Map<String, dynamic>>[];
        if (history.isEmpty) return const SizedBox.shrink();
        String awardTitle(String? type) {
          switch (type) {
            case 'team_champion': return ar ? 'بطل مهارات الفرق' : 'Team Skills champion';
            case 'one_v_one_champion': return ar ? 'بطل ختام 1 ضد 1' : '1v1 knockout champion';
            case 'best_goalkeeper': return ar ? 'أفضل حارس' : 'Best goalkeeper';
            default: return ar ? 'إنجاز بطولة' : 'Tournament award';
          }
        }
        return Container(
          padding: const EdgeInsets.all(VSPSpacing.md),
          decoration: BoxDecoration(
            color: VSPColors.surface,
            border: Border.all(color: VSPColors.divider),
            borderRadius: BorderRadius.circular(VSPRadius.lg),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ar ? 'إنجازات مهارات الفرق' : 'Team Skills Cup awards',
              style: const TextStyle(color: VSPColors.textPrimary,
                fontWeight: FontWeight.bold, fontSize: 16)),
            ...history.map((item)=>ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.emoji_events_outlined, color: VSPColors.accent),
              title: Text(awardTitle(item['award_type']?.toString()),
                style: const TextStyle(color: VSPColors.textPrimary)),
              subtitle: Text(item['cup_name']?.toString() ?? '',
                style: const TextStyle(color: VSPColors.textSecondary)),
            )),
          ]),
        );
      },
    );
  }
}
