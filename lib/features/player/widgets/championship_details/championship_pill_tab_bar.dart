import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Pill-segmented switcher tabs for Championship Details (Matches, Scorers, Rules).
class ChampionshipPillTabBar extends StatelessWidget {
  final TabController tabController;

  const ChampionshipPillTabBar({super.key, required this.tabController});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.full),
        border: Border.all(color: VSPColors.divider, width: 0.5),
      ),
      child: AnimatedBuilder(
        animation: tabController,
        builder: (context, _) {
          final currentIndex = tabController.index;
          return Row(
            children: [
              _buildPillTabItem(
                index: 0,
                currentIndex: currentIndex,
                title: isArabic ? 'المباريات' : 'Matches',
                icon: Iconsax.calendar_1_copy,
              ),
              _buildPillTabItem(
                index: 1,
                currentIndex: currentIndex,
                title: isArabic ? 'الهدافين' : 'Scorers',
                icon: Iconsax.award_copy,
              ),
              _buildPillTabItem(
                index: 2,
                currentIndex: currentIndex,
                title: isArabic ? 'القواعد' : 'Rules',
                icon: Iconsax.document_text_copy,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPillTabItem({
    required int index,
    required int currentIndex,
    required String title,
    required IconData icon,
  }) {
    final isSelected = currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          tabController.animateTo(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? VSPColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(VSPRadius.full),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.black : VSPColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.black : VSPColors.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
