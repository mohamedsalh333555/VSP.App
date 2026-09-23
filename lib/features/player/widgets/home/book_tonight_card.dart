import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/stadium_provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import 'book_tonight_sheet.dart';

/// بطاقة الحجز السريع لليوم في الصفحة الرئيسية (Fast-Track Book Tonight)
class BookTonightCard extends StatelessWidget {
  final Function(int, {Map<String, dynamic>? arguments})? onNavigate;

  const BookTonightCard({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final stadiumProvider = context.watch<StadiumProvider>();
    final stadiums = stadiumProvider.stadiums;

    if (stadiums.isEmpty) return const SizedBox.shrink();

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        child: InkWell(
          borderRadius: BorderRadius.circular(VSPRadius.xl),
          onTap: () {
            HapticFeedback.lightImpact();
            BookTonightSheet.show(
              context,
              stadiums: stadiums,
              onNavigate: onNavigate,
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [VSPColors.cardDarkGreen, VSPColors.surface],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(VSPRadius.xl),
              border: Border.all(
                color: VSPColors.accent.withValues(alpha: 0.38),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: VSPColors.accent.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: VSPColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(VSPRadius.card),
                    border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: const Center(
                    child: Icon(Iconsax.flash_1_copy, color: VSPColors.accent, size: 24),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              isArabic ? 'جاهز تلعب الليلة؟' : 'Ready to play tonight?',
                              style: const TextStyle(
                                color: VSPColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: VSPColors.accent,
                              borderRadius: BorderRadius.circular(VSPRadius.full),
                            ),
                            child: Text(
                              isArabic ? 'سريع' : 'Fast',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isArabic
                            ? 'استكشف الملاعب المتاحة الليلة واحجز بضغطة واحدة'
                            : 'Explore open slots tonight & book with 1 tap',
                        style: const TextStyle(
                          color: VSPColors.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isArabic ? Iconsax.arrow_left_2_copy : Iconsax.arrow_right_3_copy,
                  color: VSPColors.accent,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
