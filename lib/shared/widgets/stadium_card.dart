import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../core/ui/tokens/vsp_tokens.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/geo_helper.dart';
import '../../data/models.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../core/widgets/shimmer_image.dart';
import '../../core/constants/egypt_governorates.dart';

/// Stadium Card with Real Image Background and Glass Effect
/// Refactored from PlayerHomeScreen for reusability
class StadiumCard extends StatelessWidget {
 final Stadium stadium;
 final VoidCallback? onTap;
 final bool isOwnerView;
 final VoidCallback? onEditTap;

 const StadiumCard({
 super.key, 
 required this.stadium,
 this.onTap,
 this.isOwnerView = false,
 this.onEditTap,
 });

 @override
 Widget build(BuildContext context) {
 return RepaintBoundary(
 child: GestureDetector(
 onTap: () {
 HapticFeedback.lightImpact();
 onTap?.call();
 },
 child: Container(
 height: isOwnerView ? 260 : 210,
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(VSPRadius.xl),
 border: Border.all(color: VSPColors.divider, width: 1),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.3),
 blurRadius: 15,
 offset: const Offset(0, 8),
 ),
 ],
 ),
 child: ClipRRect(
 borderRadius: BorderRadius.circular(VSPRadius.xl),
 child: Stack(
 fit: StackFit.expand,
 children: [
 // REAL PHOTOGRAPHY BACKGROUND WITH HERO TRANSITION
 stadium.imageUrl.isNotEmpty
 ? Hero(
 tag: 'stadium-hero-${stadium.id}',
 child: ShimmerImage(
 imageUrl: stadium.imageUrl,
 fit: BoxFit.cover,
 memCacheWidth: 600,
 errorWidget: _buildVspLogoBackground(),
 ),
 )
 : _buildVspLogoBackground(),

 // IMPROVED GRADIENT OVERLAYS FOR READABILITY
 // Top subtle overlay for badges
 const Positioned.fill(
 child: DecoratedBox(
 decoration: BoxDecoration(
 gradient: LinearGradient(
 begin: Alignment.topCenter,
 end: Alignment.center,
 colors: [
 Colors.black54,
 Colors.transparent,
 ],
 ),
 ),
 ),
 ),
 
 // Bottom strong overlay for info (Protection Layer)
 Positioned.fill(
 child: DecoratedBox(
 decoration: BoxDecoration(
 gradient: LinearGradient(
 begin: Alignment.topCenter,
 end: Alignment.bottomCenter,
 stops: isOwnerView ? const [0.35, 1.0] : const [0.6, 1.0],
 colors: [
 Colors.transparent,
 VSPColors.background.withValues(alpha: 0.95),
 ],
 ),
 ),
 ),
 ),

 // TOP ACTIONS
 Positioned(
 top: 15,
 left: 15,
 right: 15,
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 // LOCATION BADGE (Clickable)
 Flexible(
 child: GestureDetector(
 onTap: () {
 if (stadium.lat != null && stadium.lng != null) {
 GeoHelper.openInMaps(stadium.lat!, stadium.lng!, stadium.name);
 }
 },
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: VSPColors.background.withValues(alpha: 0.7),
 borderRadius: BorderRadius.circular(VSPRadius.xl),
 border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(Iconsax.location_copy, color: VSPColors.accent, size: 14),
 const SizedBox(width: 4),
 Flexible(
 child: Text(
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
 overflow: TextOverflow.ellipsis,
 maxLines: 1,
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 const Spacer(),
 if (!stadium.isVerified) ...[
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: Colors.amber.withValues(alpha: 0.2),
 borderRadius: BorderRadius.circular(VSPRadius.md),
 border: Border.all(color: Colors.amber, width: 1),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(Iconsax.clock_copy, color: Colors.amber, size: 12),
 const SizedBox(width: 4),
 Text(
 Localizations.localeOf(context).languageCode == 'ar' ? 'قيد المراجعة ' : 'Under Review ',
 style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
 ),
 ],
 ),
 ),
 const SizedBox(width: 6),
 ],
 if (isOwnerView)
 GestureDetector(
 onTap: onEditTap,
 child: Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: VSPColors.background.withValues(alpha: 0.7),
 shape: BoxShape.circle,
 border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
 ),
 child: const Icon(
 Iconsax.edit_copy,
 color: VSPColors.accent,
 size: 18,
 ),
 ),
 )
 else ...[
 // FAVORITE BUTTON
 Consumer<AuthProvider>(
 builder: (context, auth, _) {
 final isFav = auth.userModel?.favoriteStadiums.contains(stadium.id) == true;
 return GestureDetector(
 behavior: HitTestBehavior.opaque,
 onTap: () {
 HapticFeedback.mediumImpact();
 auth.toggleFavoriteStadium(stadium.id);
 },
 child: Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: VSPColors.background.withValues(alpha: 0.7),
 shape: BoxShape.circle,
 border: Border.all(color: VSPColors.textPrimary.withValues(alpha: 0.1)),
 ),
 child: Icon(
 isFav ? Iconsax.heart : Iconsax.heart_copy,
 color: VSPColors.accent,
 size: 20,
 ),
 ),
 );
 },
 ),
 ],
 ],
 ),
 ),

 // BOTTOM INFO
 Positioned(
 bottom: 15,
 left: 15,
 right: 15,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (isOwnerView) ...[
 // Owner view details
 Text(
 '${stadium.name} ${_localizeSizeAndType(stadium.size, stadium.type, context)}',
 style: Theme.of(context).textTheme.titleLarge?.copyWith(
 color: VSPColors.textPrimary,
 fontWeight: FontWeight.w900,
 fontSize: 16,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 const SizedBox(height: 6),
 // Working Hours
 Text(
 Localizations.localeOf(context).languageCode == 'ar'
 ? 'ساعات العمل: ${stadium.openingTime} - ${stadium.closingTime}'
 : 'Working Hours: ${stadium.openingTime} - ${stadium.closingTime}',
 style: Theme.of(context).textTheme.bodySmall?.copyWith(
 color: VSPColors.accent,
 fontWeight: FontWeight.bold,
 fontSize: 12,
 ),
 ),
 const SizedBox(height: 6),
 // Amenities (Baths, Cafeteria, Garage, etc.)
 Builder(builder: (context) {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 final List<String> featuresList = stadium.features is List 
 ? List<String>.from(stadium.features)
 : Stadium.parseFeatures(stadium.features);
 
 final hasBaths = featuresList.any((f) => f.toLowerCase().contains('bath'));
 final hasCafe = featuresList.any((f) => f.toLowerCase().contains('cafe'));
 final hasGarage = featuresList.any((f) => f.toLowerCase().contains('garage'));
 
 return Row(
 children: [
 if (hasBaths) ...[
 const Icon(Iconsax.drop, color: VSPColors.accent, size: 14),
 const SizedBox(width: 4),
 Text(isArabic ? 'حمامات ' : 'Baths ', style: const TextStyle(color: Colors.white70, fontSize: 11)),
 ],
 if (hasCafe) ...[
 const Icon(Iconsax.coffee_copy, color: VSPColors.accent, size: 14),
 const SizedBox(width: 4),
 Text(isArabic ? 'كافتيريا ' : 'Cafeteria ', style: const TextStyle(color: Colors.white70, fontSize: 11)),
 ],
 if (hasGarage) ...[
 const Icon(Iconsax.car_copy, color: VSPColors.accent, size: 14),
 const SizedBox(width: 4),
 Text(isArabic ? 'جراج ' : 'Garage ', style: const TextStyle(color: Colors.white70, fontSize: 11)),
 ],
 if (!hasBaths && !hasCafe && !hasGarage)
 Text(isArabic ? 'لا توجد خدمات مضافة ' : 'No amenities listed ', style: const TextStyle(color: Colors.white38, fontSize: 11)),
 ],
 );
 }),
 const SizedBox(height: 8),
 // Price & Governorate
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(
 Localizations.localeOf(context).languageCode == 'ar'
 ? 'السعر ${stadium.pricePerHour.toInt()} ج.م'
 : 'Price ${stadium.pricePerHour.toInt()} EGP',
 style: Theme.of(context).textTheme.titleMedium?.copyWith(
 color: VSPColors.accent,
 fontWeight: FontWeight.w900,
 fontSize: 16,
 ),
 ),
 Text(
 stadium.governorate ?? stadium.location,
 style: Theme.of(context).textTheme.labelSmall?.copyWith(
 color: VSPColors.textSecondary,
 fontWeight: FontWeight.bold,
 ),
 ),
 ],
 ),
 ] else ...[
 // Player standard view details
 Text(
 Localizations.localeOf(context).languageCode == 'ar' ? stadium.formattedName : stadium.name,
 style: Theme.of(context).textTheme.titleLarge?.copyWith(
 color: VSPColors.textPrimary,
 fontWeight: FontWeight.w900,
 fontSize: 20,
 letterSpacing: 0.5,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 const SizedBox(height: 6),
 Row(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: Colors.white10,
 borderRadius: BorderRadius.circular(4),
 ),
 child: Text(
 _localizeSizeAndType(stadium.size, stadium.type, context),
 style: Theme.of(context).textTheme.labelSmall?.copyWith(
 color: Colors.white70,
 fontWeight: FontWeight.w600,
 ),
 ),
 ),
 const Spacer(),
 Column(
 crossAxisAlignment: CrossAxisAlignment.end,
 children: [
 Text(
 '${stadium.pricePerHour.toInt()} ${AppLocalizations.of(context)!.egCurrency}',
 style: Theme.of(context).textTheme.titleMedium?.copyWith(
 color: VSPColors.accent,
 fontWeight: FontWeight.w900,
 fontSize: 18,
 ),
 ),
                          Text(
                            AppLocalizations.of(context)!.perHour,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: VSPColors.textSecondary,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  ),
  ),
  );
}

 String _localizeSizeAndType(String size, String type, BuildContext context) {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 if (!isArabic) {
 final s = size.isNotEmpty ? size : '';
 final t = type.isNotEmpty ? type : '';
 if (s.isEmpty) return t;
 if (t.isEmpty) return s;
 return '$s • $t';
 }

 // Localize size (e.g., 'VS 5' -> '5 ضد 5', '5' -> '5 ضد 5')
 String locSize = size;
 final digits = RegExp(r'\d+').firstMatch(size)?.group(0);
 if (digits != null) {
 locSize = '$digits ضد $digits';
 }

 // Localize sport type
 String locType = type;
 final lowerType = type.toLowerCase();
 if (lowerType.contains('foot') || lowerType.contains('قدم')) {
 locType = 'كرة القدم';
 } else if (lowerType.contains('basket') || lowerType.contains('سلة')) {
 locType = 'كرة السلة';
 } else if (lowerType.contains('volley') || lowerType.contains('طائرة')) {
 locType = 'الكرة الطائرة';
 } else if (lowerType.contains('padel') || lowerType.contains('بادل')) {
 locType = 'بادل';
 } else if (lowerType.contains('hand') || lowerType.contains('يد')) {
 locType = 'كرة اليد';
 } else if (lowerType.contains('tennis') || lowerType.contains('تنس')) {
 locType = 'تنس';
 }

 if (locSize.isEmpty) return locType;
 if (locType.isEmpty) return locSize;
 return '$locSize • $locType';
 }

 Widget _buildVspLogoBackground() {
 return Container(
 color: VSPColors.surface,
 child: Center(
 child: Image.asset(
 'assets/images/logo.png', // VSP logo
 width: 80,
 height: 80,
 color: VSPColors.textPrimary.withValues(alpha: 0.06),
 colorBlendMode: BlendMode.modulate,
 ),
 ),
 );
 }
}



