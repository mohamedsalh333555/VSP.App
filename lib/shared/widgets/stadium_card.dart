import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../core/ui/tokens/vsp_tokens.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/geo_helper.dart';
import '../../data/models.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../core/widgets/shimmer_image.dart';

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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: isOwnerView ? 240 : 210,
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
              // REAL PHOTOGRAPHY BACKGROUND
              stadium.imageUrl.isNotEmpty
                  ? ShimmerImage(
                      imageUrl: stadium.imageUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 600,
                      errorWidget: _buildVspLogoBackground(),
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
                              Icon(LucideIcons.mapPin, color: VSPColors.accent, size: 14),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  stadium.area.isNotEmpty ? stadium.area : stadium.location,
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
                          child: Icon(
                            LucideIcons.edit2,
                            color: VSPColors.accent,
                            size: 18,
                          ),
                        ),
                      )
                    else ...[
                      // DISTANCE BADGE
                      _buildDistanceBadge(context),
                      const SizedBox(width: VSPSpacing.sm),
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
                                isFav ? LucideIcons.heart : LucideIcons.heart,
                                color: isFav ? VSPColors.error : Colors.white,
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
                        '${stadium.name}  ${stadium.size} • ${stadium.type}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: VSPColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Seats
                      Text(
                        'Seats ${stadium.seatsCapacity} person',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Amenities (Baths, Cafeteria, Garage, etc.)
                      Builder(builder: (context) {
                        final List<String> featuresList = stadium.features is List 
                            ? List<String>.from(stadium.features)
                            : Stadium.parseFeatures(stadium.features);
                        
                        final hasBaths = featuresList.any((f) => f.toLowerCase().contains('bath'));
                        final hasCafe = featuresList.any((f) => f.toLowerCase().contains('cafe'));
                        final hasGarage = featuresList.any((f) => f.toLowerCase().contains('garage'));
                        
                        return Row(
                          children: [
                            if (hasBaths) ...[
                              Icon(LucideIcons.showerHead, color: VSPColors.accent, size: 14),
                              const SizedBox(width: 4),
                              const Text('Baths 🚻  ', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                            if (hasCafe) ...[
                              Icon(LucideIcons.coffee, color: VSPColors.accent, size: 14),
                              const SizedBox(width: 4),
                              const Text('Cafeteria  ', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                            if (hasGarage) ...[
                              Icon(LucideIcons.car, color: VSPColors.accent, size: 14),
                              const SizedBox(width: 4),
                              const Text('Garage  ', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                            if (!hasBaths && !hasCafe && !hasGarage)
                              const Text('No amenities listed  ', style: TextStyle(color: Colors.white38, fontSize: 11)),
                          ],
                        );
                      }),
                      const SizedBox(height: 8),
                      // Price & Governorate
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Price ${stadium.pricePerHour.toInt()} EGP',
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
                        stadium.name,
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
                              '${stadium.size} • ${stadium.type}',
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
    );
  }

  Widget _buildDistanceBadge(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userPos = auth.currentPosition;
    
    if (userPos == null || stadium.lat == null || stadium.lng == null) {
      return const SizedBox.shrink();
    }

    final distance = GeoHelper.calculateDistance(
      userPos.latitude, 
      userPos.longitude, 
      stadium.lat!, 
      stadium.lng!,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: VSPColors.accent.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(VSPRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.navigation, color: Colors.black, size: 12),
          const SizedBox(width: 4),
          Text(
            GeoHelper.formatDistance(distance),
            style: const TextStyle(
              color: Colors.black,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
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



