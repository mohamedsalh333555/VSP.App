import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Section showcasing the team's achievements and unlocked badges.
class TeamAchievementsSection extends StatelessWidget {
  final Team team;
  final bool isArabic;

  const TeamAchievementsSection({
    super.key,
    required this.team,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    // Exact condition checking matching user requirements
    final int uniqueOpponentsCount = team.playedOpponents.isNotEmpty
        ? team.playedOpponents.length
        : (team.wins + team.draws + team.losses);

    final bool isStreak3Unlocked = team.currentWinningStreak >= 3;
    final bool isStreak10Unlocked = team.currentWinningStreak >= 10;
    final bool isExplorerUnlocked = uniqueOpponentsCount >= 5;
    final bool isChampionUnlocked = team.championshipsWon >= 1;

    final badges = [
      {
        'id': 'streak_3',
        'name': isArabic ? 'سلسلة 3 انتصارات' : 'Streak 3',
        'icon': Iconsax.flash_1_copy,
        'desc': isArabic ? 'تحقيق الفوز في 3 مباريات متتالية بدون هزيمة' : 'Win 3 matches in a row',
        'isUnlocked': isStreak3Unlocked,
        'progress': '${team.currentWinningStreak.clamp(0, 3)}/3',
      },
      {
        'id': 'streak_10',
        'name': isArabic ? 'سلسلة 10 انتصارات' : 'Streak 10',
        'icon': Iconsax.security_safe_copy,
        'desc': isArabic ? 'تحقيق الفوز في 10 مباريات متتالية بدون هزيمة' : 'Win 10 matches in a row',
        'isUnlocked': isStreak10Unlocked,
        'progress': '${team.currentWinningStreak.clamp(0, 10)}/10',
      },
      {
        'id': 'explorer',
        'name': isArabic ? 'مواجهة 5 فرق' : '5 Different Teams',
        'icon': Iconsax.discover_copy,
        'desc': isArabic ? 'خوض مباريات ضد 5 فرق مختلفة وإدخال النتيجة' : 'Play against 5 different teams',
        'isUnlocked': isExplorerUnlocked,
        'progress': '${uniqueOpponentsCount.clamp(0, 5)}/5',
      },
      {
        'id': 'champion',
        'name': isArabic ? 'بطل البطولات' : 'Champion',
        'icon': Iconsax.cup_copy,
        'desc': isArabic ? 'الحصول والتتويج بأي بطولة رسمية مع فريقك' : 'Win at least 1 official tournament',
        'isUnlocked': isChampionUnlocked,
        'progress': '${team.championshipsWon.clamp(0, 1)}/1',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isArabic ? 'إنجازات الفريق' : 'Team Achievements',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (team.currentWinningStreak > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: VSPColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: VSPColors.warning.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.flash_1_copy, color: VSPColors.warning, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      isArabic ? 'سلسلة فوز: ${team.currentWinningStreak}' : 'Win Streak: ${team.currentWinningStreak}',
                      style: const TextStyle(color: VSPColors.warning, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: VSPSpacing.md),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: badges.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final badge = badges[index];
              final bool isUnlocked = badge['isUnlocked'] as bool;
              final String name = badge['name'] as String;
              final String desc = badge['desc'] as String;
              final String progress = badge['progress'] as String;
              final IconData icon = badge['icon'] as IconData;

              return GestureDetector(
                onTap: () => _showBadgeInfo(context, name, desc, isUnlocked, progress),
                child: Container(
                  width: 86,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isUnlocked ? VSPColors.accent.withValues(alpha: 0.06) : VSPColors.surface,
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(
                      color: isUnlocked ? VSPColors.accent.withValues(alpha: 0.5) : VSPColors.divider,
                      width: isUnlocked ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isUnlocked ? VSPColors.accent.withValues(alpha: 0.15) : VSPColors.surfaceAlt,
                              border: Border.all(
                                color: isUnlocked ? VSPColors.accent : VSPColors.divider,
                                width: isUnlocked ? 1.5 : 1.0,
                              ),
                            ),
                            child: Icon(
                              icon,
                              color: isUnlocked ? VSPColors.accent : VSPColors.textSecondary.withValues(alpha: 0.35),
                              size: 22,
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: isUnlocked ? VSPColors.accent : VSPColors.surfaceAlt,
                                shape: BoxShape.circle,
                                border: Border.all(color: VSPColors.background, width: 1),
                              ),
                              child: Icon(
                                isUnlocked ? Iconsax.tick_circle_copy : Iconsax.lock_1_copy,
                                color: isUnlocked ? Colors.black : VSPColors.textSecondary,
                                size: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isUnlocked ? Colors.white : VSPColors.textSecondary,
                          fontSize: 10.5,
                          fontWeight: isUnlocked ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isUnlocked ? (isArabic ? 'مكتمل' : 'Unlocked') : progress,
                        style: TextStyle(
                          color: isUnlocked ? VSPColors.accent : VSPColors.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showBadgeInfo(BuildContext context, String name, String desc, bool isUnlocked, String progress) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Row(
          children: [
            Icon(
              isUnlocked ? Iconsax.award_copy : Iconsax.lock_1_copy,
              color: isUnlocked ? VSPColors.accent : VSPColors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: isUnlocked ? Colors.white : VSPColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(desc, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.5)),
            const SizedBox(height: VSPSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isUnlocked ? VSPColors.accent.withValues(alpha: 0.1) : VSPColors.surfaceAlt,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: isUnlocked ? VSPColors.accent : VSPColors.divider),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isArabic ? 'حالة الإنجاز:' : 'Status:',
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                  ),
                  Text(
                    isUnlocked
                        ? (isArabic ? 'تم التحقيق ' : 'Unlocked ')
                        : (isArabic ? 'قيد التقدم ($progress)' : 'In Progress ($progress)'),
                    style: TextStyle(
                      color: isUnlocked ? VSPColors.accent : Colors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PrimaryButton(
            text: isArabic ? 'حسناً، فهمت' : 'Got it',
            height: 44,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
