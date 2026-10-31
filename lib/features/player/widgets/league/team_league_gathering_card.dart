import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/repositories/league/team_league_repository.dart';
import '../../../../core/services/sharing_service.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';

class TeamLeagueGatheringCard extends StatelessWidget {
  final TeamLeagueData league;
  final VoidCallback onRefresh;
  final VoidCallback? onCancelLeague;
  final VoidCallback? onPayFee;
  final double? entryFee;

  const TeamLeagueGatheringCard({
    super.key,
    required this.league,
    required this.onRefresh,
    this.onCancelLeague,
    this.onPayFee,
    this.entryFee,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final joined = league.teams.length;
    final total = league.maxTeams;
    final progress = total > 0 ? (joined / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(VSPSpacing.lg),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: VSPColors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Iconsax.clock_copy, color: VSPColors.accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      league.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isArabic
                          ? 'مرحلة تجميع الفرق ($joined من $total فرق)'
                          : 'Team gathering ($joined of $total teams)',
                      style: const TextStyle(
                        color: VSPColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: VSPColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(VSPRadius.sm),
                ),
                child: Text(
                  '$joined/$total',
                  style: const TextStyle(
                    color: VSPColors.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: VSPSpacing.md),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: VSPColors.surfaceAlt,
              valueColor: const AlwaysStoppedAnimation<Color>(VSPColors.accent),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: VSPSpacing.lg),

          // Joined Teams List
          Text(
            isArabic ? 'الفرق المنضمة حتى الآن:' : 'Teams that have joined:',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: total,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final isFilled = index < league.teams.length;
              if (isFilled) {
                final team = league.teams[index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: VSPColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(color: VSPColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: VSPColors.accent.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: VSPColors.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          team.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Icon(Iconsax.tick_circle_copy, color: VSPColors.accent, size: 18),
                    ],
                  ),
                );
              } else {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: VSPColors.surfaceAlt.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(
                      color: VSPColors.borderLight.withValues(alpha: 0.4),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: VSPColors.surfaceAlt,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: VSPColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          isArabic ? 'في انتظار انضمام فريق منافس...' : 'Waiting for another team to join...', 
                          style: TextStyle(
                            color: VSPColors.textSecondary,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
          ),

          const SizedBox(height: VSPSpacing.lg),

          if (onPayFee != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VSPColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.accent.withValues(alpha: 0.25)),
              ),
              child: Text(
                isArabic
                    ? 'رسوم تنظيم الدوري ${entryFee?.toStringAsFixed(0) ?? '—'} جنيه لكل فريق. حجز ساعة الملعب لكل مباراة يتم بالتناصف بين الفريقين.'
                    : 'League organization fee: ${entryFee?.toStringAsFixed(0) ?? '—'} EGP per team. Stadium rental for each match is split equally between the two teams.', 
                textAlign: TextAlign.center,
                style: TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: onPayFee,
              style: ElevatedButton.styleFrom(
                backgroundColor: VSPColors.accent,
                foregroundColor: VSPColors.background,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
              ),
              child: Text(
                isArabic
                    ? 'دفع رسوم تنظيم الدوري — ${entryFee?.toStringAsFixed(0) ?? '—'} جنيه'
                    : 'Pay league fee — ${entryFee?.toStringAsFixed(0) ?? '—'} EGP',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],

          // Code & Share Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: VSPColors.surfaceAlt,
              borderRadius: BorderRadius.circular(VSPRadius.md),
              border: Border.all(color: VSPColors.borderLight),
            ),
            child: Row(
              children: [
                const Icon(Iconsax.key_copy, color: VSPColors.textSecondary, size: 18),
                const SizedBox(width: 8),
                Text(
                  isArabic ? 'كود الدوري:' : 'League code:', 
                  style: TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    league.id.substring(0, 8).toUpperCase(),
                    style: const TextStyle(
                      color: VSPColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Iconsax.copy_copy, size: 18, color: VSPColors.accent),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: league.id));
                    VSPFeedback.triggerSuccess();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isArabic ? 'تم نسخ كود الدوري' : 'League code copied')), 
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          ElevatedButton.icon(
            onPressed: () {
              final shareText = isArabic
                  ? '''
🏆 دعوة للمشاركة في ${league.name} على تطبيق VSP!
اجمع فريقك ونافس الفرق الأخرى على لقب الدوري.
رسوم تنظيم المنصة: ${entryFee?.toStringAsFixed(0) ?? '—'} جنيه لكل فريق.
حجز ساعة الملعب لكل مباراة يتم بالتناصف بين الفريقين.
كود الانضمام: ${league.id}
'''
                  : '''
🏆 Join ${league.name} on VSP!
Bring your team and compete for the league title.
Platform organization fee: ${entryFee?.toStringAsFixed(0) ?? '—'} EGP per team.
Stadium rental for each match is split equally between the two teams.
Join code: ${league.id}
''';
              SharingService().shareText(shareText);
            },
            icon: const Icon(Iconsax.share_copy, size: 18),
            label: Text(
              isArabic ? 'مشاركة الدعوة على واتساب' : 'Share invite on WhatsApp',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: VSPColors.whatsApp,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(VSPRadius.button),
              ),
            ),
          ),
          if (onCancelLeague != null) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: onCancelLeague,
                icon: const Icon(Iconsax.trash_copy, size: 16, color: VSPColors.error),
                label: Text(
                  isArabic ? 'إلغاء هذا الدوري' : 'Cancel this league',
                  style: TextStyle(color: VSPColors.error, fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
