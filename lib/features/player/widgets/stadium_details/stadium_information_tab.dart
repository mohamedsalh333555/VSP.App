import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/egypt_governorates.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';

class _FacilityItem {
  final IconData icon;
  final String label;
  final bool active;
  const _FacilityItem({required this.icon, required this.label, required this.active});
}

/// Grid showing active stadium amenities and services (Cafeteria, Garage, Showers, Changing Rooms, Stands).
class FacilitiesGrid extends StatelessWidget {
  final Stadium stadium;

  const FacilitiesGrid({super.key, required this.stadium});

  bool _getBool(String key) {
    final f = stadium.features;
    if (f is Map) return f[key] == true;
    return false;
  }

  String _getSeat() {
    final f = stadium.features;
    if (f is Map) return f['seats']?.toString() ?? '';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final hasCafeteria = _getBool('cafeteria');
    final hasGarage = _getBool('garage');
    final hasBathroom = stadium.features is Map ? (stadium.features as Map)['bathOption'] == 'Yes' : false;
    final hasChangingRoom = _getBool('changingRoom');
    final seats = _getSeat();
    final hasSeats = seats.isNotEmpty && seats != '0' && seats != 'null';

    final allFacilities = [
      _FacilityItem(icon: Iconsax.drop, label: isArabic ? 'دش وحمامات' : 'Showers & Bathrooms', active: hasBathroom),
      _FacilityItem(icon: Iconsax.car_copy, label: isArabic ? 'موقف سيارات' : 'Parking', active: hasGarage),
      _FacilityItem(icon: Iconsax.coffee_copy, label: isArabic ? 'كافتيريا' : 'Cafeteria', active: hasCafeteria),
      _FacilityItem(icon: Iconsax.shop_copy, label: isArabic ? 'غرف تبديل' : 'Changing Rooms', active: hasChangingRoom),
      _FacilityItem(icon: Iconsax.home_copy, label: isArabic ? 'مدرجات ومقاعد' : 'Seats & Stands', active: hasSeats),
    ];

    final activeFacilities = allFacilities.where((f) => f.active).toList();

    if (activeFacilities.isEmpty) {
      return Text(
        isArabic ? 'لا توجد مرافق مضافة لهذا الملعب' : 'No facilities listed for this pitch',
        style: TextStyle(color: VSPColors.textSecondary.withValues(alpha: 0.7), fontSize: 11),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 10,
          children: activeFacilities.map((f) {
            return SizedBox(
              width: itemWidth > 120 ? itemWidth : constraints.maxWidth,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: VSPColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(VSPRadius.sm),
                      border: Border.all(
                        color: VSPColors.divider.withValues(alpha: 0.6),
                        width: 0.8,
                      ),
                    ),
                    child: Icon(f.icon, color: VSPColors.accent, size: 14),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

/// Information tab in StadiumDetailsScreen displaying pitch name, location, rating, amenities, and ball rental.
class StadiumInformationTab extends StatelessWidget {
  final Stadium stadium;

  const StadiumInformationTab({super.key, required this.stadium});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final String displayName = stadium.name.trim().isNotEmpty
        ? (isArabic ? stadium.formattedName : stadium.name.trim())
        : (isArabic ? 'ملعب بدون اسم' : 'Unnamed Pitch');

    String rawDesc = stadium.description.isNotEmpty ? stadium.description : l10n.noDescription;
    if (!isArabic && rawDesc.isNotEmpty) {
      rawDesc = rawDesc
          .replaceAll('الالتزام بالمواعد', '• Punctuality')
          .replaceAll('الالتزام بالمواعيد', '• Punctuality')
          .replaceAll('الحفاظ على النظافة', '• Cleanliness')
          .replaceAll('ممنوع التدخين', '• No Smoking');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(VSPSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Stadium Name & Single Clean Rating Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  displayName,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: VSPColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  border: Border.all(color: VSPColors.divider.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Iconsax.star_copy, color: VSPColors.accent, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      stadium.rating.toStringAsFixed(1),
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${stadium.reviewsCount})',
                      style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: VSPSpacing.md),

          // Location Badge: Guaranteed working maps launch
          GestureDetector(
            onTap: () async {
              try {
                final String query = (stadium.lat != null && stadium.lng != null)
                    ? '${stadium.lat},${stadium.lng}'
                    : Uri.encodeComponent('${stadium.name} ${stadium.location} ${stadium.governorate ?? ''}'.trim());
                final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
                await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
              } catch (e) {
                debugPrint('Error launching maps: $e');
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.xl),
                border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.location_copy, color: VSPColors.accent, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    EgyptGovernorates.formatSmartLocation(
                      rawAddress: stadium.area.isNotEmpty
                          ? stadium.area
                          : (stadium.location.isNotEmpty ? stadium.location : stadium.address),
                      administrativeArea: stadium.governorate,
                    ),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: VSPColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: VSPSpacing.md),

          // Description Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(VSPSpacing.md),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.lg),
              border: Border.all(color: VSPColors.divider.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.informationStadium,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  rawDesc,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: VSPSpacing.md),

          // Merged Amenities & Add-ons Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.xl),
              border: Border.all(
                color: VSPColors.divider.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Iconsax.verify_copy, color: VSPColors.accent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      isArabic ? 'المرافق والخدمات' : 'Amenities & Services',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FacilitiesGrid(stadium: stadium),
                if (stadium.hasBall || stadium.ballPrice > 0) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(color: VSPColors.divider, height: 1),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: VSPColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      border: Border.all(
                        color: VSPColors.accent.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: VSPColors.accent.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Iconsax.activity_copy,
                            color: VSPColors.accent,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isArabic ? 'تأجير كرة مباراة' : 'Match Ball Rental',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                isArabic ? 'إضافة اختيارية عند الحجز' : 'Optional add-on upon booking',
                                style: TextStyle(
                                  color: VSPColors.textSecondary.withValues(alpha: 0.8),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: VSPColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(VSPRadius.sm),
                            border: Border.all(
                              color: VSPColors.accent.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            isArabic ? '+${stadium.ballPrice.toInt()} ج.م' : '+${stadium.ballPrice.toInt()} EGP',
                            style: const TextStyle(
                              color: VSPColors.accent,
                              fontWeight: FontWeight.w900,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: VSPSpacing.lg),
        ],
      ),
    );
  }
}
