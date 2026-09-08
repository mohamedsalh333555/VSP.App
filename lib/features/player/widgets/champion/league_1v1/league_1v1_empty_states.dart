import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';
import '../champion_podium_components.dart';

/// Displayed when a user does not have a home governorate set in their profile.
class League1v1NoGovernorateState extends StatelessWidget {
  final bool isArabic;

  const League1v1NoGovernorateState({
    super.key,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
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
              child: const Icon(Iconsax.location_slash_copy, size: 38, color: VSPColors.accent),
            ),
            const SizedBox(height: 16),
            Text(
              isArabic ? 'يرجى تحديد محافظتك من الملف الشخصي' : 'Please set your governorate in profile',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isArabic
                  ? 'حدد محافظتك لمشاهدة بطولات منطقتك والمشاركة بها'
                  : 'Set your home governorate to view and join local 1v1 tournaments',
              textAlign: TextAlign.center,
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/edit-profile');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: VSPColors.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Iconsax.edit_2_copy, size: 16, color: Colors.black),
              label: Text(
                isArabic ? 'تحديد المحافظة الآن' : 'Set Governorate',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Displayed when there is no active 1v1 tournament in the selected location.
class League1v1NoTournamentState extends StatelessWidget {
  final String locationName;
  final bool isArabic;

  const League1v1NoTournamentState({
    super.key,
    required this.locationName,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
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
              isArabic
                  ? 'لا توجد بطولة فردية نشطة حالياً في $locationName'
                  : 'No active 1v1 tournament in $locationName',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isArabic
                  ? 'ترقبوا إعلان موعد وتفاصيل بطولة 1vs1 القادمة قريباً!'
                  : 'Stay tuned for upcoming 1v1 announcements!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner showing when a user is browsing 1v1 tournaments in a different governorate.
class League1v1GovernorateBanner extends StatelessWidget {
  final String selectedLocation;
  final String userGov;
  final bool isArabic;
  final VoidCallback onReturnToHomeGov;

  const League1v1GovernorateBanner({
    super.key,
    required this.selectedLocation,
    required this.userGov,
    required this.isArabic,
    required this.onReturnToHomeGov,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.location_copy, color: VSPColors.accent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isArabic
                  ? 'تتصفح بطولات: ${championTranslateItem(context, selectedLocation)}'
                  : 'Viewing: ${championTranslateItem(context, selectedLocation)}',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          InkWell(
            onTap: onReturnToHomeGov,
            borderRadius: BorderRadius.circular(VSPRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                isArabic ? 'بطولاتي ($userGov)' : 'My City ($userGov)',
                style: const TextStyle(color: VSPColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
