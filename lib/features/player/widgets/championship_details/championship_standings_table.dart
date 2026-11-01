import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/repositories/tournament_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../shared/widgets/vsp_error_state.dart';

/// قسم جدول الترتيب الحي للبطولة (يدعم نظام الدوري ونظام المجموعات)
class ChampionshipStandingsSection extends StatefulWidget {
  final Championship championship;
  final int refreshVersion;
  final VoidCallback onRetry;

  const ChampionshipStandingsSection({
    super.key,
    required this.championship,
    required this.refreshVersion,
    required this.onRetry,
  });

  @override
  State<ChampionshipStandingsSection> createState() =>
      _ChampionshipStandingsSectionState();
}

class _ChampionshipStandingsSectionState
    extends State<ChampionshipStandingsSection> {
  final Map<String, Future<List<Map<String, dynamic>>>> _standingsFutures = {};

  @override
  void didUpdateWidget(covariant ChampionshipStandingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.championship.id != widget.championship.id ||
        oldWidget.refreshVersion != widget.refreshVersion) {
      _standingsFutures.clear();
    }
  }

  Future<List<Map<String, dynamic>>> _standingsFuture(String? groupName) {
    final key = groupName ?? '__all__';
    return _standingsFutures.putIfAbsent(
      key,
      () => TournamentRepository().getChampionshipStandings(
        widget.championship.id,
        groupName: groupName,
      ),
    );
  }

  void _retryStandings() {
    setState(_standingsFutures.clear);
    widget.onRetry();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isGroupOrLeague = widget.championship.type == 'League' || widget.championship.type == 'GroupsAndKnockout';
    if (!isGroupOrLeague) return const SizedBox.shrink();

    final isGroups = widget.championship.type == 'GroupsAndKnockout';
    final numGroups = widget.championship.numberOfGroups;
    final groupNames = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
    final safeGroupCount = numGroups.clamp(0, groupNames.length).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Iconsax.award_copy, color: VSPColors.accent, size: 20),
            const SizedBox(width: 8),
            Text(
              isArabic ? 'جدول الترتيب الحي' : 'Live Standings Table',
              style: const TextStyle(color: VSPColors.white, fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (isGroups) ...[
          for (int g = 0; g < safeGroupCount; g++) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Text(
                isArabic ? 'المجموعة ${groupNames[g]}' : 'Group ${groupNames[g]}',
                style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            _buildStandingsTableWidget(context, groupName: groupNames[g]),
            const SizedBox(height: 12),
          ],
        ] else ...[
          _buildStandingsTableWidget(context),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildStandingsTableWidget(BuildContext context, {String? groupName}) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _standingsFuture(groupName),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return VSPErrorState(
            customMessage: isArabic
                ? 'تعذر تحميل جدول الترتيب. حاول مرة أخرى.'
                : 'Could not load standings. Try again.',
            onRetry: _retryStandings,
            retryButtonText: isArabic ? 'إعادة المحاولة' : 'Retry',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: VSPColors.accent),
            ),
          );
        }

        final rows = snapshot.data ?? [];
        if (rows.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.md)),
            child: Center(
              child: Text(
                isArabic ? 'لا توجد مباريات مسجلة بعد' : 'No recorded matches yet',
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.circular(VSPRadius.md),
            border: Border.all(color: VSPColors.divider),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 14,
              headingRowHeight: 40,
              dataRowMaxHeight: 44,
              columns: [
                DataColumn(
                  label: Text(isArabic ? '#' : '#', style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold)),
                ),
                DataColumn(
                  label: Text(isArabic ? 'الفريق' : 'Team', style: const TextStyle(color: VSPColors.white, fontWeight: FontWeight.bold)),
                ),
                DataColumn(
                  label: Text(isArabic ? 'لعب' : 'P', style: const TextStyle(color: VSPColors.white70)),
                ),
                DataColumn(
                  label: Text(isArabic ? 'فاز' : 'W', style: const TextStyle(color: VSPColors.white70)),
                ),
                DataColumn(
                  label: Text(isArabic ? 'تعادل' : 'D', style: const TextStyle(color: VSPColors.white70)),
                ),
                DataColumn(
                  label: Text(isArabic ? 'خسر' : 'L', style: const TextStyle(color: VSPColors.white70)),
                ),
                DataColumn(
                  label: Text(isArabic ? 'له' : 'GF', style: const TextStyle(color: VSPColors.white70)),
                ),
                DataColumn(
                  label: Text(isArabic ? 'عليه' : 'GA', style: const TextStyle(color: VSPColors.white70)),
                ),
                DataColumn(
                  label: Text(isArabic ? '+/-' : 'GD', style: const TextStyle(color: VSPColors.white70)),
                ),
                DataColumn(
                  label: Text(isArabic ? 'النقاط' : 'PTS', style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold)),
                ),
              ],
              rows: rows.asMap().entries.map((entry) {
                final rank = entry.key + 1;
                final r = entry.value;

                return DataRow(
                  cells: [
                    DataCell(Text(
                      '$rank',
                      style: TextStyle(
                        color: rank <= 2 ? VSPColors.accent : VSPColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )),
                    DataCell(Text(
                      r['team_name']?.toString() ?? 'Team',
                      style: const TextStyle(color: VSPColors.white, fontWeight: FontWeight.bold),
                    )),
                    DataCell(Text('${r['played'] ?? 0}', style: const TextStyle(color: VSPColors.white70))),
                    DataCell(Text('${r['won'] ?? 0}', style: const TextStyle(color: VSPColors.accent))),
                    DataCell(Text('${r['drawn'] ?? 0}', style: const TextStyle(color: VSPColors.warning))),
                    DataCell(Text('${r['lost'] ?? 0}', style: const TextStyle(color: VSPColors.error))),
                    DataCell(Text('${r['goals_for'] ?? 0}', style: const TextStyle(color: VSPColors.white70))),
                    DataCell(Text('${r['goals_against'] ?? 0}', style: const TextStyle(color: VSPColors.white70))),
                    DataCell(Text('${r['goal_difference'] ?? 0}', style: const TextStyle(color: VSPColors.white70))),
                    DataCell(Text(
                      '${r['points'] ?? 0}',
                      style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 14),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
