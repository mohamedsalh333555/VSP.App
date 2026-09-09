import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';

/// Starter Prompt Cards displayed when a conversation is empty.
class CopilotStarterPrompts extends StatelessWidget {
  final ValueChanged<String> onSelectPrompt;
  final bool isArabic;

  const CopilotStarterPrompts({
    super.key,
    required this.onSelectPrompt,
    this.isArabic = true,
  });

  static const List<Map<String, dynamic>> _promptsAr = [
    {
      'title': 'ملاعب 5 ضد 5 في القاهرة',
      'subtitle': 'استكشف ملاعب خماسي مميزة',
      'icon': Icons.sports_soccer,
    },
    {
      'title': 'ملاعب مفتوحة الليلة بعد 8 مساءً',
      'subtitle': 'احجز مباراة سريعة الليلة',
      'icon': Icons.nightlight_round,
    },
    {
      'title': 'أرخص الملاعب المتاحة حالياً',
      'subtitle': 'أسعار اقتصادية تبدأ من 200 ج.م',
      'icon': Icons.attach_money,
    },
    {
      'title': 'ملاعب تقييمها أعلى من 4.5 نجوم',
      'subtitle': 'أفضل جودة نجيل وخدمات ممتازة',
      'icon': Icons.star_rounded,
    },
  ];

  static const List<Map<String, dynamic>> _promptsEn = [
    {
      'title': '5v5 pitches in Cairo',
      'subtitle': 'Explore top 5-a-side venues',
      'icon': Icons.sports_soccer,
    },
    {
      'title': 'Open pitches tonight after 8 PM',
      'subtitle': 'Fast-track evening slot',
      'icon': Icons.nightlight_round,
    },
    {
      'title': 'Cheapest pitches available now',
      'subtitle': 'Budget friendly slots starting 200 EGP',
      'icon': Icons.attach_money,
    },
    {
      'title': 'Pitches rated 4.5+ stars',
      'subtitle': 'Premium grass quality & amenities',
      'icon': Icons.star_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final prompts = isArabic ? _promptsAr : _promptsEn;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: VSPColors.accent.withValues(alpha: 0.12),
              border: Border.all(color: VSPColors.accent.withValues(alpha: 0.25)),
            ),
            child: const Icon(Iconsax.flash_copy, color: VSPColors.accent, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            isArabic ? 'كابتن VSP الذكي' : 'VSP Copilot',
            style: const TextStyle(
              color: VSPColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isArabic
                ? 'مساعدك الشخصي للبحث الذكي عن الملاعب وأوقات اللعب'
                : 'Your personal AI assistant for pitches discovery',
            textAlign: TextAlign.center,
            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 28),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: prompts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final p = prompts[i];
              return InkWell(
                onTap: () => onSelectPrompt(p['title'] as String),
                borderRadius: BorderRadius.circular(VSPRadius.md),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF142019),
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: VSPColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(p['icon'] as IconData, color: VSPColors.accent, size: 18),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['title'] as String,
                              style: const TextStyle(
                                color: VSPColors.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              p['subtitle'] as String,
                              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.white38),
                    ],
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
