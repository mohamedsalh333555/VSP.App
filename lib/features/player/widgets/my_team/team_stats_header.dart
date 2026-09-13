import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/repositories/team_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';

/// Header section displaying the 1v1 champion banner and team stat metrics (Points, Members, Trophies, Wins).
class TeamStatsHeader extends StatelessWidget {
  final Team team;
  final int membersCount;
  final bool isArabic;

  const TeamStatsHeader({
    super.key,
    required this.team,
    required this.membersCount,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 1v1 Champion Banner (if applicable)
        FutureBuilder<bool>(
          future: TeamRepository().has1v1Champion(team.id),
          builder: (context, champSnap) {
            if (champSnap.data == true) {
              return Container(
                margin: const EdgeInsets.only(bottom: VSPSpacing.md),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF332608), Color(0xFF1E1A0C)],
                  ),
                  borderRadius: BorderRadius.circular(VSPRadius.lg),
                  border: Border.all(color: const Color(0xFFEAB308), width: 1),
                ),
                child: Row(
                  children: [
                    const SizedBox.shrink(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabic ? 'فريق يضم بطل 1v1 رسمي!' : 'Home of Official 1v1 Champion!',
                            style: const TextStyle(
                              color: Color(0xFFFDE047),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            isArabic
                                ? 'أحد لاعبي هذا الفريق حاصل على المركز الأول في بطولة الفردي'
                                : 'A member of this team won 1st place in the 1v1 tournament',
                            style: const TextStyle(color: Color(0xFFCA8A04), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),

        // 2. 4-Metrics Row (Points, Members, Trophies, Wins)
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _showEloInfoDialog(context),
                child: _buildStatCard(
                  context,
                  team.points.toString(),
                  isArabic ? 'نقاط الدوري' : l10n.points,
                  showInfoIcon: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(context, membersCount.toString(), l10n.members),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(context, team.championshipsWon.toString(), l10n.trophies),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(context, team.wins.toString(), l10n.wins),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String value, String label, {bool showInfoIcon = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
        color: VSPColors.surface.withValues(alpha: 0.5),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Column(
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: VSPColors.textSecondary.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (showInfoIcon)
            const Positioned(
              top: 0,
              left: 4,
              child: Icon(Iconsax.info_circle_copy, size: 12, color: VSPColors.accent),
            ),
        ],
      ),
    );
  }

  void _showEloInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Row(
          children: [
            const Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isArabic ? 'ترتيب فريقك الرسمي' : 'Official Elo Rating',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          isArabic
              ? 'نقاط الترتيب تعبر عن الموقع الرسمي لفريقك بين كل فرق المحافظة. ترتفع النقاط وتتقدم في جدول الدوري عند الفوز في التحديات والبطولات.'
              : 'Elo Rating reflects your official team standing across the governorate. Earn points and climb the leaderboard by winning challenges.',
          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              isArabic ? 'حسناً، فهمت' : 'Got it',
              style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
