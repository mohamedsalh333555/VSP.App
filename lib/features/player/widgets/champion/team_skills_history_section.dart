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
    Iterable<Map<String, dynamic>> rows, {
    String? participantId,
    bool? isTeam,
  }) {
    const knownTypes = {
      'team_champion',
      'one_v_one_champion',
      'best_goalkeeper',
    };
    final expectedId = participantId?.trim();
    // Only one award of a type can exist per cup in the canonical database.
    // If a response violates that invariant, do not show either candidate.
    final byCupAward = <String, Map<String, dynamic>>{};
    final conflicting = <String>{};
    for (final row in rows) {
      final cupId = row['cup_id'];
      final cupName = row['cup_name'];
      final teamId = row['team_id'];
      final playerId = row['player_id'];
      final awardType = row['award_type'];
      final announced = row['announced_at'];
      if (cupId is! String || cupId.trim().isEmpty ||
          cupName is! String || cupName.trim().isEmpty ||
          teamId is! String || teamId.trim().isEmpty ||
          awardType is! String || !knownTypes.contains(awardType) ||
          announced is! String || DateTime.tryParse(announced) == null) {
        continue;
      }
      // The database requires no individual recipient for team titles, and
      // a known actual recipient for individual titles. Reject mismatches on
      // the client as well, consistent with the Admin archive.
      if ((awardType == 'team_champion' && playerId != null) ||
          (awardType != 'team_champion' &&
              (playerId is! String || playerId.trim().isEmpty))) {
        continue;
      }
      final awardKey = '${cupId.trim()}::${awardType}';
      if (conflicting.contains(awardKey)) continue;
      final previous = byCupAward[awardKey];
      if (previous == null) {
        byCupAward[awardKey] = row;
      } else if (previous['team_id'] != teamId ||
          (previous['player_id'] is String
                  ? (previous['player_id'] as String).trim() : '') !=
              (playerId is String ? playerId.trim() : '') ||
          previous['cup_name'] != cupName ||
          previous['announced_at'] != announced) {
        byCupAward.remove(awardKey);
        conflicting.add(awardKey);
      }
    }
    // Views scope these records, but validate again after integrity checks.
    // This prevents a cross-team response from hiding a contradictory winner.
    if (expectedId == null) return byCupAward.values.toList(growable: false);
    if (expectedId.isEmpty || isTeam == null) return const [];
    return byCupAward.values.where((row) =>
        isTeam ? row['team_id'] == expectedId :
            row['player_id'] == expectedId).toList(growable: false);
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
          participantId: widget.participantId,
          isTeam: widget.isTeam,
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
