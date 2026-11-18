import 'package:flutter/material.dart';
import '../../../../core/config/app_env.dart';
import '../../../../core/repositories/team_skills_cup_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Award history is derived only from officially announced, completed cups.
/// It is separate from legacy 1v1 trophies and team challenge Elo scores.
class TeamSkillsHistorySection extends StatefulWidget {
  final String participantId;
  final bool isTeam;
  final TeamSkillsCupRepository? repository;
  /// Incremented only for an explicit user-initiated profile refresh.
  final int refreshRevision;

  /// No RPC may run when the staging/project rollout gate is closed.
  static bool shouldLoad({required bool enabled, required String participantId}) =>
      enabled && participantId.trim().isNotEmpty;

  static String awardTitle(String? type, {required bool isArabic}) {
    switch (type) {
      case 'team_champion':
        return isArabic ? 'بطل مهارات الفرق' : 'Team Skills champion';
      case 'one_v_one_champion':
        // This is the final stage WITHIN Team Skills, not the retired 1v1 cup.
        return isArabic ? 'بطل نهائي المهارات' : 'Skills final champion';
      case 'best_goalkeeper':
        return isArabic ? 'أفضل حارس' : 'Best goalkeeper';
      default:
        return isArabic ? 'إنجاز بطولة' : 'Tournament award';
    }
  }

  /// Only announced awards from a real cup are eligible for display.
  /// The Supabase view enforces publication permissions; this additional
  /// presentation guard prevents malformed/duplicate rows from becoming
  /// apparent trophies when data or API versions diverge.
  static List<Map<String, dynamic>> visibleAwards(
    Iterable<Map<String, dynamic>> rows,
  ) {
    const knownTypes = {
      'team_champion',
      'one_v_one_champion',
      'best_goalkeeper',
    };
    final seen = <String>{};
    final visible = <Map<String, dynamic>>[];
    for (final row in rows) {
      final cupId = row['cup_id'];
      final awardType = row['award_type'];
      final announced = row['announced_at'];
      if (cupId is! String || cupId.trim().isEmpty ||
          awardType is! String || !knownTypes.contains(awardType) ||
          announced is! String || DateTime.tryParse(announced) == null) {
        continue;
      }
      final key = '${cupId.trim()}::${awardType}::${row['player_id'] ?? row['team_id'] ?? ''}';
      if (seen.add(key)) visible.add(row);
    }
    return visible;
  }

  const TeamSkillsHistorySection({
    super.key,
    required this.participantId,
    required this.isTeam,
    this.repository,
    this.refreshRevision = 0,
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
        oldWidget.isTeam != widget.isTeam ||
        oldWidget.repository != widget.repository ||
        oldWidget.refreshRevision != widget.refreshRevision) {
      _refresh();
    }
  }

  void _refresh() {
    if (!TeamSkillsHistorySection.shouldLoad(
      enabled: AppEnv.teamSkillsCupEnabled,
      participantId: widget.participantId,
    )) {
      _future = Future.value(const <Map<String, dynamic>>[]);
      return;
    }
    final repo = widget.repository ?? TeamSkillsCupRepository();
    _future = widget.isTeam
        ? repo.getTeamHistory(widget.participantId)
        : repo.getPlayerHistory(widget.participantId);
  }

  @override
  Widget build(BuildContext context) {
    if (!TeamSkillsHistorySection.shouldLoad(
      enabled: AppEnv.teamSkillsCupEnabled,
      participantId: widget.participantId,
    )) {
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
        final history = TeamSkillsHistorySection.visibleAwards(
          snapshot.data ?? const <Map<String, dynamic>>[],
        );
        if (history.isEmpty) return const SizedBox.shrink();
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
              title: Text(TeamSkillsHistorySection.awardTitle(
                item['award_type']?.toString(), isArabic: ar),
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
