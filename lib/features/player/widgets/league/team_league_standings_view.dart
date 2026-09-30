import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/repositories/league/team_league_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Tab 2: "تفاصيل الدوري"
/// Contains:
/// 1. معلومات الدوري (League Info)
/// 2. الفرق المشاركة (Participating Teams)
/// 3. جدول الدوري (Standings Table without goals)
class TeamLeagueDetailsView extends StatelessWidget {
  final TeamLeagueData league;
  final String userTeamId;

  const TeamLeagueDetailsView({
    super.key,
    required this.league,
    required this.userTeamId,
  });

  @override
  Widget build(BuildContext context) {
    final standings = league.standings;
    final isCompleted = league.status == 'completed';
    final topTeam = standings.isNotEmpty ? standings.first : null;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 🏆 Top Team / Leader Banner (if completed or underway with leader)
        if (isCompleted && topTeam != null) ...[
          Container(
            padding: const EdgeInsets.all(VSPSpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  VSPColors.medalGold.withValues(alpha: 0.25),
                  const Color(0xFFB8860B).withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(VSPRadius.xl),
              border: Border.all(color: VSPColors.medalGold, width: 2),
            ),
            child: Column(
              children: [
                const Icon(Iconsax.cup_copy, color: VSPColors.medalGold, size: 36),
                const SizedBox(height: 8),
                const Text(
                  'انتهى الدوري — المتصدر',
                  style: TextStyle(
                    color: VSPColors.medalGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  topTeam.teamName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'المركز الأول برصيد ${topTeam.points} نقاط',
                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: VSPSpacing.md),
        ],

        // 1. League Info Card
        Container(
          decoration: BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.circular(VSPRadius.lg),
            border: Border.all(color: VSPColors.borderLight),
          ),
          padding: const EdgeInsets.all(VSPSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Iconsax.info_circle_copy, color: VSPColors.accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    league.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: VSPColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('خاص', style: TextStyle(color: VSPColors.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoRow('نظام الدوري', 'دوري — دور واحد'),
              _buildInfoRow('المحافظة', league.governorate ?? 'القاهرة'),
              _buildInfoRow('عدد الفرق', '${league.joinedTeamsCount} / ${league.maxTeams} فرق'),
              _buildInfoRow('الفترة بين المباريات', 'كل ${league.matchIntervalDays} أيام'),
              _buildInfoRow(
                'حالة الدوري',
                league.status == 'completed'
                    ? 'انتهى الدوري'
                    : league.status == 'ongoing'
                        ? 'جاري المنافسات'
                        : 'مرحلة تجميع الفرق',
              ),
            ],
          ),
        ),
        const SizedBox(height: VSPSpacing.md),

        // 2. Participating Teams Card
        Container(
          decoration: BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.circular(VSPRadius.lg),
            border: Border.all(color: VSPColors.borderLight),
          ),
          padding: const EdgeInsets.all(VSPSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Iconsax.people_copy, color: VSPColors.accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'الفرق المشاركة (${league.teams.length})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const Divider(color: VSPColors.divider, height: 20),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: league.teams.length,
                separatorBuilder: (_, __) => const Divider(color: VSPColors.surfaceAlt, height: 12),
                itemBuilder: (context, idx) {
                  final t = league.teams[idx];
                  final isMyTeam = t.id == userTeamId;
                  return Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: VSPColors.surfaceAlt,
                          shape: BoxShape.circle,
                          border: Border.all(color: isMyTeam ? VSPColors.accent : VSPColors.divider),
                        ),
                        child: Center(
                          child: Text(
                            '${idx + 1}',
                            style: TextStyle(
                              color: isMyTeam ? VSPColors.accent : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          t.name,
                          style: TextStyle(
                            color: isMyTeam ? VSPColors.accent : Colors.white,
                            fontWeight: isMyTeam ? FontWeight.bold : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'رسوم مشاركة الفريق: مدفوعة',
                          style: TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: VSPSpacing.md),

        // 3. Standings Table Card (Section 28 & 29: No Goals, Win=3, Draw=1, Loss=0)
        Container(
          decoration: BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.circular(VSPRadius.lg),
            border: Border.all(color: VSPColors.borderLight),
          ),
          padding: const EdgeInsets.all(VSPSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Iconsax.ranking_copy, color: VSPColors.accent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'جدول الدوري',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'الفوز = 3 نقاط | التعادل = 1 نقطة | الخسارة = 0',
                style: TextStyle(color: VSPColors.textSecondary, fontSize: 11),
              ),
              const Divider(color: VSPColors.divider, height: 20),

              // Header Row: الترتيب | الفريق | لعب | فاز | تعادل | خسر | النقاط
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                decoration: BoxDecoration(
                  color: VSPColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '#',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: VSPColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: Text(
                        'الفريق',
                        style: TextStyle(color: VSPColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'لعب',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: VSPColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'فاز',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: VSPColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'تعادل',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: VSPColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'خسر',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: VSPColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'النقاط',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: VSPColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Table Body
              if (standings.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'لا توجد مباريات مكتملة في جدول الترتيب حتى الآن',
                      style: TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: standings.length,
                  separatorBuilder: (_, __) => const Divider(color: VSPColors.surfaceAlt, height: 10),
                  itemBuilder: (context, index) {
                    final item = standings[index];
                    final isUserTeam = item.teamId == userTeamId;
                    final isFirst = index == 0;

                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      decoration: BoxDecoration(
                        color: isUserTeam
                            ? VSPColors.accent.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          // Rank
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isFirst
                                  ? VSPColors.medalGold
                                  : VSPColors.surfaceAlt,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${item.rank}',
                              style: TextStyle(
                                color: isFirst ? Colors.black : VSPColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Team Name
                          Expanded(
                            flex: 4,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.teamName,
                                    style: TextStyle(
                                      color: isUserTeam ? VSPColors.accent : Colors.white,
                                      fontWeight: isUserTeam ? FontWeight.bold : FontWeight.w500,
                                      fontSize: 12.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isUserTeam)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Text('⭐', style: TextStyle(fontSize: 10)),
                                  ),
                              ],
                            ),
                          ),

                          // Played
                          Expanded(
                            child: Text(
                              '${item.played}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          // Won
                          Expanded(
                            child: Text(
                              '${item.won}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          // Drawn
                          Expanded(
                            child: Text(
                              '${item.drawn}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          // Lost
                          Expanded(
                            child: Text(
                              '${item.lost}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          // Points
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: VSPColors.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${item.points}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: VSPColors.accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

// Backward compatibility alias for any existing imports
typedef TeamLeagueStandingsView = TeamLeagueDetailsView;
