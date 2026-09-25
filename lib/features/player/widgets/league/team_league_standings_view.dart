import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/repositories/league/team_league_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

class TeamLeagueStandingsView extends StatelessWidget {
  final TeamLeagueData league;
  final String userTeamId;

  const TeamLeagueStandingsView({
    super.key,
    required this.league,
    required this.userTeamId,
  });

  @override
  Widget build(BuildContext context) {
    final standings = league.standings;
    final championName = league.championTeamName;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 🏆 Champion Podium Banner
        if (championName != null && championName.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(VSPSpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFFD700).withValues(alpha: 0.25),
                  const Color(0xFFB8860B).withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(VSPRadius.xl),
              border: Border.all(color: const Color(0xFFFFD700), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFD700),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Iconsax.cup_copy, color: Colors.black, size: 36),
                ),
                const SizedBox(height: 10),
                const Text(
                  '🏆 بطل الدوري',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  championName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'مبروك التتويج بلقب الدوري المصغر!',
                  style: TextStyle(
                    color: VSPColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: VSPSpacing.lg),
        ],

        // Standings Table Card
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
                    'جدول ترتيب الدوري',
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
                'حساب النقاط: (فوز = 3 نقاط | تعادل = 1 نقطة | خسارة = 0)',
                style: TextStyle(color: VSPColors.textSecondary, fontSize: 11),
              ),
              const Divider(color: VSPColors.divider, height: 20),

              // Header Row
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
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
                        'ف',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: VSPColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'ت',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: VSPColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'خ',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: VSPColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '+/-',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: VSPColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'نقاط',
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
                      'لا توجد بيانات ترتيب حالياً',
                      style: TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: standings.length,
                  separatorBuilder: (_, __) => const Divider(color: VSPColors.surfaceAlt, height: 12),
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
                                  ? const Color(0xFFFFD700)
                                  : VSPColors.surfaceAlt,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isFirst ? Colors.black : Colors.white,
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
                                      fontSize: 12,
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
                          // GD
                          Expanded(
                            child: Text(
                              item.goalDifference > 0 ? '+${item.goalDifference}' : '${item.goalDifference}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: item.goalDifference > 0
                                    ? Colors.green
                                    : item.goalDifference < 0
                                        ? Colors.red
                                        : Colors.white,
                                fontSize: 11,
                              ),
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
}
