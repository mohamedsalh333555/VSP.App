import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';

/// Starter Prompt Cards displayed when a conversation is empty.
/// Built strictly with the VSP Design System (Zinc surface, Electric Lime accent, 24px card radius).
class CopilotStarterPrompts extends StatelessWidget {
  final ValueChanged<String> onSelectPrompt;
  final bool isArabic;
  final String? userGovernorate;

  const CopilotStarterPrompts({
    super.key,
    required this.onSelectPrompt,
    this.isArabic = true,
    this.userGovernorate,
  });

  List<Map<String, dynamic>> _getPrompts(bool ar, String? gov) {
    if (ar) {
      return [
        {
          'title': 'فين ألعب النهارده؟',
          'subtitle': 'لاقيلي أقرب ملعب متاح دلوقتي',
          'icon': Icons.near_me_rounded,
        },
        {
          'title': 'في ماتش ناقص لاعيب؟',
          'subtitle': 'انضم لتقسيمة خماسي ناقصاها حريف',
          'icon': Icons.sports_soccer_rounded,
        },
        {
          'title': 'أرخص ملعب قريب مني',
          'subtitle': 'أحسن سعر مقابل أحسن ملعب',
          'icon': Icons.savings_rounded,
        },
        {
          'title': 'في بطولات أقدر أشترك فيها؟',
          'subtitle': 'بطولات وتحديات فردية متاحة دلوقتي',
          'icon': Icons.emoji_events_rounded,
        },
      ];
    }

    return [
      {
        'title': 'Where can I play today?',
        'subtitle': 'Find me the nearest available pitch now',
        'icon': Icons.near_me_rounded,
      },
      {
        'title': 'Any open matches nearby?',
        'subtitle': 'Join a pick-up game looking for players',
        'icon': Icons.sports_soccer_rounded,
      },
      {
        'title': 'Cheapest pitch near me',
        'subtitle': 'Best value for money venues around you',
        'icon': Icons.savings_rounded,
      },
      {
        'title': 'Any tournaments I can join?',
        'subtitle': 'Active leagues and 1v1 challenges available now',
        'icon': Icons.emoji_events_rounded,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final prompts = _getPrompts(isArabic, userGovernorate);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          // VSP Glowing Hero Badge
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: VSPColors.accent.withValues(alpha: 0.12),
              border: Border.all(color: VSPColors.accent.withValues(alpha: 0.35), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: VSPColors.accent.withValues(alpha: 0.15),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Iconsax.flash_copy, color: VSPColors.accent, size: 38),
          ),
          const SizedBox(height: 18),
          Text(
            isArabic ? 'كابتن VSP الذكي' : 'VSP Copilot',
            style: const TextStyle(
              color: VSPColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isArabic
                ? 'مساعدك الرياضي للبحث عن الملاعب، الماتشات، والبطولات المعتمدة'
                : 'Your football companion for pitches, open games, and tournaments',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: VSPColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: VSPColors.surfaceAlt,
              borderRadius: BorderRadius.circular(VSPRadius.md),
              border: Border.all(color: VSPColors.borderLight),
            ),
            child: Text(
              isArabic
                  ? 'يا كابتن! قولي إيه اللي في بالك — ملعب، ماتش، أو بطولة؟'
                  : 'Hey Captain! Tell me what you need — a pitch, a match, or a tournament?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: VSPColors.textPrimary,
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // VSP Design System Prompt Cards
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: prompts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final p = prompts[i];
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(VSPRadius.card),
                  gradient: const LinearGradient(
                    colors: [
                      VSPColors.surfaceAlt, // Zinc 800
                      VSPColors.surface,    // Zinc 900
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: VSPColors.borderLight,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(VSPRadius.card),
                  child: InkWell(
                    onTap: () => onSelectPrompt(p['title'] as String),
                    borderRadius: BorderRadius.circular(VSPRadius.card),
                    splashColor: VSPColors.accentSoft,
                    highlightColor: VSPColors.accent.withValues(alpha: 0.05),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          // Leading rounded icon container
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: VSPColors.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: VSPColors.accent.withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              p['icon'] as IconData,
                              color: VSPColors.accent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Text Column
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['title'] as String,
                                  style: const TextStyle(
                                    color: VSPColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  p['subtitle'] as String,
                                  style: const TextStyle(
                                    color: VSPColors.textSecondary,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Trailing Arrow
                          Icon(
                            isArabic ? Icons.arrow_back_ios_new_rounded : Icons.arrow_forward_ios_rounded,
                            size: 13,
                            color: VSPColors.accent.withValues(alpha: 0.7),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
