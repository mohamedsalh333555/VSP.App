import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../core/ui/tokens/vsp_tokens.dart';
import '../../data/models.dart';
import '../../data/models/team_gamification_models.dart';
import 'shields/vsp_shield_badge.dart';

/// Displays the complete Season Progress, Shields, Immortal Reward Size Submission,
/// Monthly Free-Hour Awards, Progressive Missions, Unified Achievements,
/// Strongest Team Skill Results, and Season History for a team.
///
/// When [isPrivateView] is false (public [TeamProfileScreen]), private operational
/// details such as monthly mission targets, player jersey sizes, and delivery
/// controls are strictly hidden.
class TeamGamificationPanel extends StatefulWidget {
  final TeamGamificationProfile profile;
  final Team team;
  final bool isPrivateView;
  final String? currentUserId;
  final Future<bool> Function(
    String entitlementId,
    String targetUserId,
    String size,
  )? onSubmitImmortalSize;
  final VoidCallback? onRedeemFreeHour;

  const TeamGamificationPanel({
    super.key,
    required this.profile,
    required this.team,
    required this.isPrivateView,
    this.currentUserId,
    this.onSubmitImmortalSize,
    this.onRedeemFreeHour,
  });

  @override
  State<TeamGamificationPanel> createState() => _TeamGamificationPanelState();
}

class _TeamGamificationPanelState extends State<TeamGamificationPanel> {
  final Set<String> _savingSizeUsers = {};

  static const _jerseySizes = ['S', 'M', 'L', 'XL', 'XXL', '3XL'];

  String _fmtNum(num v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final p = widget.profile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSeasonAndShieldCard(context, p, isArabic),
        const SizedBox(height: VSPSpacing.md),
        if (widget.isPrivateView &&
            (p.immortalReward != null ||
                p.currentShield == TeamShieldTier.immortal)) ...[
          _buildImmortalRewardCard(context, p, isArabic),
          const SizedBox(height: VSPSpacing.md),
        ],
        if (widget.isPrivateView && p.freeHourAwards.isNotEmpty) ...[
          _buildFreeHourAwardsCard(context, p, isArabic),
          const SizedBox(height: VSPSpacing.md),
        ],
        if (widget.isPrivateView && p.missions != null) ...[
          _buildMonthlyMissionsCard(context, p.missions!, isArabic),
          const SizedBox(height: VSPSpacing.md),
        ],
        if (p.achievements.isNotEmpty) ...[
          _buildUnifiedAchievementsCard(context, p.achievements, isArabic),
          const SizedBox(height: VSPSpacing.md),
        ],
        if (p.strongestTeamResults.isNotEmpty) ...[
          _buildStrongestTeamResultsCard(context, p.strongestTeamResults, isArabic),
          const SizedBox(height: VSPSpacing.md),
        ],
        if (p.seasonHistory.isNotEmpty) ...[
          _buildSeasonHistoryCard(context, p.seasonHistory, isArabic),
        ],
      ],
    );
  }

  Widget _buildSeasonAndShieldCard(
    BuildContext context,
    TeamGamificationProfile p,
    bool isArabic,
  ) {
    final nextTier = p.currentShield.nextTier;
    final currentReq = p.currentShield.requiredXp;
    final nextReq = nextTier?.requiredXp ?? p.currentShield.requiredXp;
    final xpProgress = nextTier == null
        ? 1.0
        : ((p.seasonXp - currentReq) / (nextReq - currentReq).clamp(1, 999999))
            .clamp(0.0, 1.0);
    final remainingXp = nextTier == null
        ? 0.0
        : (nextTier.requiredXp - p.seasonXp).clamp(0.0, 999999.0);

    final immortalChallengePct = (p.weightedChallenges / 60.0).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(
          color: p.currentShield.primaryColor.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              VspShieldBadge(
                tier: p.currentShield,
                size: 62,
                showGlow: true,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          isArabic ? p.seasonNameAr : p.seasonNameEn,
                          style: const TextStyle(
                            color: VSPColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (!p.isOfficialLive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: VSPColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isArabic ? 'قبل الإطلاق' : 'Pre-launch',
                              style: const TextStyle(
                                color: VSPColors.warning,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      p.currentShield.label(isArabic),
                      style: TextStyle(
                        color: p.currentShield.primaryColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isArabic
                          ? 'خبرة الموسم: ${_fmtNum(p.seasonXp)} XP  •  التراكمية: ${_fmtNum(p.lifetimeXp)} XP'
                          : 'Season XP: ${_fmtNum(p.seasonXp)}  •  Lifetime: ${_fmtNum(p.lifetimeXp)} XP',
                      style: const TextStyle(
                        color: VSPColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (nextTier != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isArabic
                      ? 'الدرع التالي: ${nextTier.label(true)}'
                      : 'Next Shield: ${nextTier.label(false)}',
                  style: const TextStyle(
                    color: VSPColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  isArabic
                      ? 'متبقي ${_fmtNum(remainingXp)} XP'
                      : '${_fmtNum(remainingXp)} XP left',
                  style: TextStyle(
                    color: nextTier.primaryColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: xpProgress,
                minHeight: 7,
                backgroundColor: VSPColors.surfaceAlt,
                valueColor: AlwaysStoppedAnimation<Color>(nextTier.primaryColor),
              ),
            ),
          ],
          if (p.currentShield == TeamShieldTier.legendary ||
              p.currentShield == TeamShieldTier.immortal ||
              p.weightedChallenges > 0) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isArabic
                      ? 'شرط Immortal (تحديات موزونة): ${_fmtNum(p.weightedChallenges)} / 60'
                      : 'Immortal Weighted Challenges: ${_fmtNum(p.weightedChallenges)} / 60',
                  style: const TextStyle(
                    color: VSPColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
                Text(
                  isArabic
                      ? 'إجمالي التحديات: ${p.approvedChallenges}'
                      : 'Total: ${p.approvedChallenges}',
                  style: const TextStyle(
                    color: VSPColors.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: immortalChallengePct,
                minHeight: 6,
                backgroundColor: VSPColors.surfaceAlt,
                valueColor: AlwaysStoppedAnimation<Color>(
                  TeamShieldTier.immortal.primaryColor,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: VSPColors.surfaceAlt,
              borderRadius: BorderRadius.circular(VSPRadius.md),
              border: Border.all(color: VSPColors.divider),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic
                          ? 'الترتيب الشهري (${p.monthKey.isEmpty ? "الحالي" : p.monthKey})'
                          : 'Monthly Rank (${p.monthKey.isEmpty ? "Current" : p.monthKey})',
                      style: const TextStyle(
                        color: VSPColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.monthlyRank != null
                          ? '#${p.monthlyRank}  •  ${p.monthlyRankingPoints} ${isArabic ? "نقطة" : "pts"}'
                          : (isArabic ? 'غير مصنف بعد هذا الشهر' : 'Unranked this month'),
                      style: const TextStyle(
                        color: VSPColors.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${p.monthlyWins}W-${p.monthlyDraws}D-${p.monthlyLosses}L',
                  style: const TextStyle(
                    color: VSPColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImmortalRewardCard(
    BuildContext context,
    TeamGamificationProfile p,
    bool isArabic,
  ) {
    final reward = p.immortalReward;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: TeamShieldTier.immortal.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(
          color: TeamShieldTier.immortal.primaryColor.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.crown_1_copy, color: VSPColors.accent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic ? 'جائزة خاصة من VSP' : 'Special VSP Reward',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (reward != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: VSPColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    reward.deliveryStatus,
                    style: const TextStyle(
                      color: VSPColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isArabic
                ? 'تأهل فريقك في درع Immortal للحصول على جائزة خاصة من VSP. يرجى تحديد المقاس المطلوب لكل لاعب.'
                : 'Your team qualified at Immortal Shield for a Special VSP Reward. Please select a size for each roster member.',
            style: const TextStyle(
              color: VSPColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (reward != null && reward.players.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...reward.players.map((snap) {
              final canEdit = !reward.sizesLocked &&
                  !snap.duplicateSeasonBlocked &&
                  (p.isCaptain || snap.userId == widget.currentUserId) &&
                  widget.onSubmitImmortalSize != null;
              final isSaving = _savingSizeUsers.contains(snap.userId);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: VSPColors.surface,
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  border: Border.all(color: VSPColors.divider),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            snap.playerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          if (snap.duplicateSeasonBlocked)
                            Text(
                              isArabic
                                  ? 'حصل على جائزة شخصية مسبقاً هذا الموسم مع فريق آخر'
                                  : 'Already claimed personal reward this season with another team',
                              style: const TextStyle(
                                color: VSPColors.warning,
                                fontSize: 10.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isSaving)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: VSPColors.accent,
                        ),
                      )
                    else if (canEdit)
                      DropdownButton<String>(
                        dropdownColor: VSPColors.surfaceAlt,
                        underline: const SizedBox.shrink(),
                        value: _jerseySizes.contains(snap.jerseySize)
                            ? snap.jerseySize
                            : null,
                        hint: Text(
                          isArabic ? 'المقاس' : 'Size',
                          style: const TextStyle(
                            color: VSPColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        items: _jerseySizes
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    s,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ))
                            .toList(),
                        onChanged: (val) async {
                          if (val == null) return;
                          setState(() => _savingSizeUsers.add(snap.userId));
                          try {
                            await widget.onSubmitImmortalSize!(
                              reward.id,
                              snap.userId,
                              val,
                            );
                          } finally {
                            if (mounted) {
                              setState(() => _savingSizeUsers.remove(snap.userId));
                            }
                          }
                        },
                      )
                    else
                      Text(
                        snap.jerseySize ?? (isArabic ? 'غير محدد' : 'Not set'),
                        style: const TextStyle(
                          color: VSPColors.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildFreeHourAwardsCard(
    BuildContext context,
    TeamGamificationProfile p,
    bool isArabic,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.gift_copy, color: VSPColors.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                isArabic
                    ? 'جوائز بطل الشهر (ساعات مجانية)'
                    : 'Monthly Champion Free Hours',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...p.freeHourAwards.map((award) {
            final isIssued = award.status == 'issued';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: VSPColors.surfaceAlt,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.divider),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic
                              ? 'شهر ${award.monthKey} • ${award.governorate}'
                              : '${award.monthKey} • ${award.governorate}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isIssued
                              ? (isArabic
                                  ? 'متاحة للاستبدال على أي ملعب في المحافظة بدون تاريخ انتهاء'
                                  : 'Available to redeem at any pitch in governorate — never expires')
                              : (isArabic ? 'تم الاستبدال' : 'Redeemed'),
                          style: TextStyle(
                            color: isIssued ? VSPColors.accent : VSPColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isIssued && p.isCaptain && widget.onRedeemFreeHour != null)
                    TextButton(
                      onPressed: widget.onRedeemFreeHour,
                      child: Text(isArabic ? 'احجز الآن' : 'Redeem'),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMonthlyMissionsCard(
    BuildContext context,
    TeamMissionSummary m,
    bool isArabic,
  ) {
    final nextCh = m.nextChallengeStage;
    final nextWin = m.nextWinStage;
    final nextOpp = m.nextOpponentStage;

    Widget row(String title, int current, (int, int)? next) {
      final target = next?.$1 ?? current;
      final reward = next?.$2;
      final pct = target > 0 ? (current / target).clamp(0.0, 1.0) : 1.0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: VSPColors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  next != null
                      ? '$current/$target (+$reward XP)'
                      : (isArabic ? 'مكتمل ✓' : 'Done ✓'),
                  style: TextStyle(
                    color: next != null ? VSPColors.accent : VSPColors.success,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 5,
                backgroundColor: VSPColors.surfaceAlt,
                valueColor: AlwaysStoppedAnimation<Color>(
                  next != null ? VSPColors.accent : VSPColors.success,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'المهام الشهرية المتدرجة' : 'Progressive Monthly Missions',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              Text(
                widget.profile.monthKey,
                style: const TextStyle(
                  color: VSPColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          row(
            isArabic ? 'التحديات المكتملة' : 'Completed Challenges',
            m.challengesCompleted,
            nextCh,
          ),
          row(
            isArabic ? 'الانتصارات' : 'Challenge Wins',
            m.challengeWins,
            nextWin,
          ),
          row(
            isArabic ? 'مواجهة فرق مختلفة' : 'Unique Opponents',
            m.uniqueOpponents,
            nextOpp,
          ),
          row(
            isArabic ? 'المشاركة في بطولة واحدة' : 'Tournament Participation',
            m.tournamentsCompleted >= 1 ? 1 : 0,
            m.tournamentsCompleted >= 1 ? null : (1, 150),
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedAchievementsCard(
    BuildContext context,
    List<TeamAchievementEntry> items,
    bool isArabic,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic
                ? 'الأوسمة والإنجازات الموثقة (${items.length})'
                : 'Verified Achievements (${items.length})',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((a) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: VSPColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: VSPColors.divider),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? a.titleAr : a.titleEn,
                      style: const TextStyle(
                        color: VSPColors.medalGold,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    if ((isArabic ? a.descriptionAr : a.descriptionEn).isNotEmpty)
                      Text(
                        isArabic ? a.descriptionAr : a.descriptionEn,
                        style: const TextStyle(
                          color: VSPColors.textSecondary,
                          fontSize: 10.5,
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStrongestTeamResultsCard(
    BuildContext context,
    List<StrongestTeamParticipationResult> results,
    bool isArabic,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? 'سجل بطولة أقوى فريق' : 'Strongest Team Results',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          ...results.map((r) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: VSPColors.surfaceAlt,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isArabic ? r.titleAr : r.titleEn,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (r.finalRank != null)
                        Text(
                          '#${r.finalRank} • +${_fmtNum(r.xpAwarded)} XP',
                          style: const TextStyle(
                            color: VSPColors.accent,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  if (r.scores.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: r.scores
                          .map((s) => Text(
                                '${isArabic ? s.titleAr : s.titleEn}: ${_fmtNum(s.weightedPoints)}',
                                style: const TextStyle(
                                  color: VSPColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSeasonHistoryCard(
    BuildContext context,
    List<TeamSeasonHistoryEntry> history,
    bool isArabic,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? 'تاريخ المواسم السابقة' : 'Season History',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          ...history.map((h) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: VspShieldBadge(tier: h.finalShield, size: 38),
                title: Text(
                  isArabic
                      ? 'موسم ${h.yearNumber} — ${h.finalShield.label(true)}'
                      : 'Season ${h.yearNumber} — ${h.finalShield.label(false)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  isArabic
                      ? '${_fmtNum(h.finalXp)} XP  •  ${h.wins} فوز / ${h.draws} تعادل / ${h.losses} خسارة'
                      : '${_fmtNum(h.finalXp)} XP  •  ${h.wins}W / ${h.draws}D / ${h.losses}L',
                  style: const TextStyle(
                    color: VSPColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
