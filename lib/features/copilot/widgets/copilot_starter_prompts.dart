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
    final govLabel = (gov != null && gov.trim().isNotEmpty) ? gov.trim() : null;

    if (ar) {
      return [
        {
          'title': govLabel != null ? 'ملاعب قريبة مني في $govLabel' : 'ملاعب قريبة مني الآن',
          'subtitle': 'أفضل الملاعب المتاحة بالقرب منك للحجز الفوري',
          'icon': Icons.near_me_rounded,
        },
        {
          'title': 'ماتشات خماسية ناقصها لاعيبة',
          'subtitle': 'انضم لمباراة مفتوحة وتقسيمة محتاجة حريفة',
          'icon': Icons.sports_soccer_rounded,
        },
        {
          'title': 'ملاعب فاضية للحجز الليلة',
          'subtitle': 'احجز مباراة سريعة في الساعات المسائية',
          'icon': Icons.nightlight_round,
        },
        {
          'title': 'البطولات والتحديات المتاحة حالياً',
          'subtitle': 'جوائز مالية وتنافس خماسي ودوري الحريفة 1v1',
          'icon': Icons.emoji_events_rounded,
        },
      ];
    }

    return [
      {
        'title': govLabel != null ? 'Pitches near me in $govLabel' : 'Pitches near me now',
        'subtitle': 'Best verified venues available for instant booking',
        'icon': Icons.near_me_rounded,
      },
      {
        'title': 'Open matches looking for players',
        'subtitle': 'Join open pick-up games looking for teammates',
        'icon': Icons.sports_soccer_rounded,
      },
      {
        'title': 'Available pitches tonight',
        'subtitle': 'Fast-track evening slots for quick matches',
        'icon': Icons.nightlight_round,
      },
      {
        'title': 'Active tournaments & 1v1 challenges',
        'subtitle': 'Explore cash prize leagues and individual rankings',
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
          const SizedBox(height: 28),

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
                      Color(0xFF162414), // Subtle dark green tint
                      VSPColors.surface, // Zinc 900
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
