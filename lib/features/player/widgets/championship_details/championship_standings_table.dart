import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/repositories/tournament_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';

/// قسم جدول الترتيب الحي للبطولة (يدعم نظام الدوري ونظام المجموعات)
class ChampionshipStandingsSection extends StatelessWidget {
  final Championship championship;

  const ChampionshipStandingsSection({super.key, required this.championship});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isGroupOrLeague = championship.type == 'League' || championship.type == 'GroupsAndKnockout';
    if (!isGroupOrLeague) return const SizedBox.shrink();

    final isGroups = championship.type == 'GroupsAndKnockout';
    final numGroups = championship.numberOfGroups;
    final groupNames = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Iconsax.award_copy, color: VSPColors.accent, size: 20),
            const SizedBox(width: 8),
            Text(
              isArabic ? 'جدول الترتيب الحي' : 'Live Standings Table',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (isGroups) ...[
          for (int g = 0; g < numGroups; g++) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Text(
                isArabic ? 'المجموعة ${groupNames[g]}' : 'Group ${groupNames[g]}',
                style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            _buildStandingsTableWidget(context, championship.id, groupName: groupNames[g]),
            const SizedBox(height: 12),
          ],
        ] else ...[
          _buildStandingsTableWidget(context, championship.id),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildStandingsTableWidget(BuildContext context, String championshipId, {String? groupName}) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: TournamentRepository().getChampionshipStandings(championshipId, groupName: groupName),
      builder: (context, snapshot) {
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
            decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(12)),
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
                  label: Text(isArabic ? 'الفريق' : 'Team', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                DataColumn(
                  label: Text(isArabic ? 'لعب' : 'P', style: const TextStyle(color: Colors.white70)),
                ),
                DataColumn(
                  label: Text(isArabic ? 'فاز' : 'W', style: const TextStyle(color: Colors.white70)),
                ),
                DataColumn(
                  label: Text(isArabic ? 'تعادل' : 'D', style: const TextStyle(color: Colors.white70)),
                ),
                DataColumn(
                  label: Text(isArabic ? 'خسر' : 'L', style: const TextStyle(color: Colors.white70)),
                ),
                DataColumn(
                  label: Text(isArabic ? 'له' : 'GF', style: const TextStyle(color: Colors.white70)),
                ),
                DataColumn(
                  label: Text(isArabic ? 'عليه' : 'GA', style: const TextStyle(color: Colors.white70)),
                ),
                DataColumn(
                  label: Text(isArabic ? '+/-' : 'GD', style: const TextStyle(color: Colors.white70)),
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
                        color: rank <= 2 ? VSPColors.accent : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )),
                    DataCell(Text(
                      r['team_name']?.toString() ?? 'Team',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    )),
                    DataCell(Text('${r['played'] ?? 0}', style: const TextStyle(color: Colors.white70))),
                    DataCell(Text('${r['won'] ?? 0}', style: const TextStyle(color: VSPColors.accent))),
                    DataCell(Text('${r['drawn'] ?? 0}', style: const TextStyle(color: VSPColors.warning))),
                    DataCell(Text('${r['lost'] ?? 0}', style: const TextStyle(color: VSPColors.error))),
                    DataCell(Text('${r['goals_for'] ?? 0}', style: const TextStyle(color: Colors.white70))),
                    DataCell(Text('${r['goals_against'] ?? 0}', style: const TextStyle(color: Colors.white70))),
                    DataCell(Text('${r['goal_difference'] ?? 0}', style: const TextStyle(color: Colors.white70))),
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
