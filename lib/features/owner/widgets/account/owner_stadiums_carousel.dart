import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../shared/widgets/stadium_card.dart';
import '../../screens/add_stadium_wizard.dart';

class OwnerStadiumsCarousel extends StatelessWidget {
  final Stream<List<Stadium>> stadiumsStream;

  const OwnerStadiumsCarousel({
    super.key,
    required this.stadiumsStream,
  });

  void _handleAddStadiumTap(BuildContext context, int currentCount) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddStadiumWizard(),
      ),
    );
  }

  Widget _buildAddStadiumCard(BuildContext context, int currentCount) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return GestureDetector(
      onTap: () => _handleAddStadiumTap(context, currentCount),
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.xl),
          border: Border.all(
            color: VSPColors.accent.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: VSPColors.accent.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: VSPColors.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: VSPColors.accent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: VSPColors.accent.withValues(alpha: 0.35),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Iconsax.add_circle_copy,
                color: VSPColors.accent,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isArabic ? 'إضافة ملعب آخر' : 'Add Another Stadium',
              style: const TextStyle(
                color: VSPColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            isArabic ? 'الملاعب المسجلة' : 'My Stadiums',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: VSPColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 215,
          child: StreamBuilder<List<Stadium>>(
            stream: stadiumsStream,
            builder: (context, snapshot) {
              final stadiums = snapshot.data ?? [];
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: 0),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: stadiums.length + 1,
                itemBuilder: (context, index) {
                  if (index < stadiums.length) {
                    return Container(
                      width: 260,
                      margin: const EdgeInsets.only(right: VSPSpacing.md),
                      child: StadiumCard(
                        stadium: stadiums[index],
                        isOwnerView: true,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AddStadiumWizard(stadiumId: stadiums[index].id)),
                          );
                        },
                        onEditTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AddStadiumWizard(stadiumId: stadiums[index].id)),
                          );
                        },
                      ),
                    );
                  } else {
                    return Container(
                      width: 240,
                      margin: const EdgeInsets.only(right: VSPSpacing.md),
                      child: _buildAddStadiumCard(context, stadiums.length),
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
