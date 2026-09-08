import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';

/// شريط كبسولات الملاعب الأفقي (يظهر عندما يمتلك المالك أكثر من ملعب)
class OwnerVenueFilterChips extends StatelessWidget {
  final List<Stadium> stadiums;
  final String selectedStadiumId;
  final ValueChanged<String> onStadiumSelected;
  final bool isArabic;

  const OwnerVenueFilterChips({
    super.key,
    required this.stadiums,
    required this.selectedStadiumId,
    required this.onStadiumSelected,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    if (stadiums.length <= 1) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildVenueChip(
            id: 'all',
            label: isArabic ? 'كافة الملاعب' : 'All Pitches',
            icon: Iconsax.buildings_copy,
          ),
          const SizedBox(width: 8),
          ...stadiums.map((s) => Padding(
            padding: const EdgeInsets.only(left: 8),
            child: _buildVenueChip(
              id: s.id,
              label: s.name,
              icon: Iconsax.location_copy,
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildVenueChip({required String id, required String label, required IconData icon}) {
    final isSelected = selectedStadiumId == id;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onStadiumSelected(id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? VSPColors.accent : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(VSPRadius.full),
          border: Border.all(
            color: isSelected ? VSPColors.accent : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.black : VSPColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
