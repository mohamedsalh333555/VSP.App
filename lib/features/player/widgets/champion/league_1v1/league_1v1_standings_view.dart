import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../../data/models.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/vsp_error_state.dart';
import '../../../../../shared/widgets/vsp_fade_in_item.dart';
import '../champion_podium_components.dart';

/// شاشة عرض الترتيب والمنصة الرسمية لمواجهات 1v1 وفقاً لمنظومة الـ 32 لاعب
class League1v1StandingsView extends StatefulWidget {
  final Stream<List<VSP1v1Player>> standingsStream;
  final VoidCallback onRetry;

  const League1v1StandingsView({
    super.key,
    required this.standingsStream,
    required this.onRetry,
  });

  @override
  State<League1v1StandingsView> createState() => _League1v1StandingsViewState();
}

class _League1v1StandingsViewState extends State<League1v1StandingsView> {
  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return StreamBuilder<List<VSP1v1Player>>(
      stream: widget.standingsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
        }
        if (snapshot.hasError) {
          return VSPErrorState(
            customMessage: snapshot.error?.toString(),
            onRetry: () => setState(() {}),
          );
        }
        final players = snapshot.data ?? [];
        if (players.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: VSPColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: VSPColors.divider.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Iconsax.cup_copy, size: 38, color: VSPColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.noOneVsOneRanked,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }

        final top3 = players.take(3).toList();
        final rest = players.skip(3).toList();

        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: VSPScrollPadding.forList(context, hasFloatingNavBar: true, top: 12),
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // ── شريط قواعد ورصد البطولة الميدانية (بدون كلمة لجنة) ──
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: VSPColors.surface,
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  border: Border.all(color: VSPColors.divider),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.info_circle_copy, color: VSPColors.accent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isArabic
                            ? 'مباريات إقصائية من 6 جولات • نقطة للدفاع، الهدف، والمهارة • المجموع تراكمي لمشوار البطولة'
                            : '6-Round Knockout Matches • Points for Defense, Goals & Skill • Cumulative Total',
                        style: const TextStyle(
                          color: VSPColors.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ── منصة التتويج Top 3 Podium ──
              if (players.length >= 3)
                SizedBox(
                  height: 290,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // المركز الثاني (الوصيف)
                      Expanded(
                        child: VSPFadeInItem(
                          index: 1,
                          child: ChampionPodiumItem(
                            rank: 2,
                            name: top3[1].name,
                            logo: top3[1].avatarUrl,
                            points: top3[1].totalPoints,
                            badgeIcon: Iconsax.medal_star_copy,
                            borderColor: VSPColors.medalSilver,
                            bgColor: VSPColors.surface,
                            pointsLabel: isArabic ? 'نقطة' : 'PTS',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // المركز الأول (البطل)
                      Expanded(
                        child: VSPFadeInItem(
                          index: 0,
                          child: ChampionPodiumItem(
                            rank: 1,
                            name: top3[0].name,
                            logo: top3[0].avatarUrl,
                            points: top3[0].totalPoints,
                            badgeIcon: Iconsax.crown_copy,
                            borderColor: VSPColors.accent,
                            bgColor: VSPColors.surfaceAlt,
                            isCenter: true,
                            pointsLabel: isArabic ? 'نقطة' : 'PTS',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // المركز الثالث (نصف النهائي)
                      Expanded(
                        child: VSPFadeInItem(
                          index: 2,
                          child: ChampionPodiumItem(
                            rank: 3,
                            name: top3[2].name,
                            logo: top3[2].avatarUrl,
                            points: top3[2].totalPoints,
                            badgeIcon: Iconsax.award_copy,
                            borderColor: VSPColors.medalBronze,
                            bgColor: VSPColors.surface,
                            pointsLabel: isArabic ? 'نقطة' : 'PTS',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // ── قائمة الترتيب التفصيلية لباقي اللاعبين (#4 وما بعده) ──
              ...List.generate(rest.length, (index) {
                final player = rest[index];
                final rank = index + 4;
                return VSPFadeInItem(
                  index: index + 3,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: League1v1RankListItem(
                      player: player,
                      rank: rank,
                      isArabic: isArabic,
                    ),
                  ),
                );
              }),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

/// بطاقة تفاصيل اللاعب الفردي مع إبراز الدور الإقصائي وتفصيل (دفاع • أهداف • مهارة)
class League1v1RankListItem extends StatelessWidget {
  final VSP1v1Player player;
  final int rank;
  final bool isArabic;

  const League1v1RankListItem({
    super.key,
    required this.player,
    required this.rank,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final initialLetter =
        player.name.trim().isNotEmpty ? player.name.trim().split(' ').last.substring(0, 1).toUpperCase() : 'P';
    final stageTitle = player.getStageTitle();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Row(
        children: [
          // رقم الترتيب
          SizedBox(
            width: 28,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: rank <= 3 ? VSPColors.accent : VSPColors.textSecondary,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),

          // الصورة الرمزية
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: VSPColors.surfaceAlt,
              border: Border.all(color: VSPColors.divider, width: 1),
            ),
            child: ClipOval(
              child: player.avatarUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: player.avatarUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          ChampionInitialBadge(letter: initialLetter, accentColor: VSPColors.accent),
                    )
                  : ChampionInitialBadge(letter: initialLetter, accentColor: VSPColors.accent),
            ),
          ),
          const SizedBox(width: 12),

          // اسم اللاعب وشارة الدور وتفصيل الدرجات
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        player.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: VSPColors.textPrimary,
                          fontSize: 13.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (stageTitle.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: VSPColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(VSPRadius.xs),
                          border: Border.all(color: VSPColors.divider, width: 0.8),
                        ),
                        child: Text(
                          stageTitle,
                          style: const TextStyle(
                            color: VSPColors.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                // تفصيل الدرجات الصريح: دفاع • أهداف • مهارة
                Text(
                  isArabic
                      ? 'دفاع: ${player.tackles}  •  أهداف: ${player.goals}  •  مهارة: ${player.skillPoints}'
                      : 'Defense: ${player.tackles}  •  Goals: ${player.goals}  •  Skill: ${player.skillPoints}',
                  style: const TextStyle(
                    color: VSPColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // المجموع التراكمي
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: VSPColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(VSPRadius.md),
              border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
            ),
            child: Text(
              '${player.totalPoints} ${isArabic ? "نقطة" : "PTS"}',
              style: const TextStyle(
                color: VSPColors.accent,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
