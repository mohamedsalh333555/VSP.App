import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/ui/tokens/vsp_tokens.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/geo_helper.dart';
import '../../data/models.dart';
import 'package:provider/provider.dart';

/// Stadium Card with Real Image Background and Glass Effect
/// Refactored from PlayerHomeScreen for reusability
class StadiumCard extends StatelessWidget {
  final Stadium stadium;
  final VoidCallback? onTap;

  const StadiumCard({
    super.key, 
    required this.stadium,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 230,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(VSPRadius.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(VSPRadius.lg),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // REAL PHOTOGRAPHY BACKGROUND
              stadium.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: stadium.imageUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 600,
                      maxHeightDiskCache: 1200,
                      placeholder: (context, url) => Container(
                        color: VSPColors.surface,
                      ),
                      errorWidget: (context, url, error) => _buildVspLogoBackground(),
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
              
              // Bottom strong overlay for info
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      stops: [0.2, 1.0],
                      colors: [
                        Colors.transparent,
                        VSPColors.background,
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
                    GestureDetector(
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
                            const Icon(Icons.location_on, color: VSPColors.accent, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              stadium.area.isNotEmpty ? stadium.area : stadium.location,
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
                    const Spacer(),
                    // DISTANCE BADGE
                    _buildDistanceBadge(context),
                    const SizedBox(width: VSPSpacing.sm),
                    // FAVORITE BUTTON
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: VSPColors.background.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                        border: Border.all(color: VSPColors.textPrimary.withValues(alpha: 0.1)),
                      ),
                      child: Icon(
                        stadium.isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: stadium.isFavorite ? VSPColors.error : VSPColors.textPrimary,
                        size: 20,
                      ),
                    ),
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
                              '${stadium.pricePerHour.toInt()} EGP',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: VSPColors.accent,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              'per hour',
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
          const Icon(Icons.directions_walk, color: Colors.black, size: 12),
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
