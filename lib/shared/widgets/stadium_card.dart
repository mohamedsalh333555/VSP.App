import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/ui/tokens/vsp_tokens.dart';
import '../../data/models.dart';

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
        // Removed fixed width/margin to make it flexible in different layouts (ListView/GridView)
        // If used in horizontal list, wrap with SizedBox or Container with width
        height: 230,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(VSPRadius.lg),
          boxShadow: VSPShadow.subtle,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(VSPRadius.lg),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // REAL PHOTOGRAPHY BACKGROUND
              // REAL PHOTOGRAPHY BACKGROUND
              stadium.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: stadium.imageUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 600,
                      placeholder: (context, url) => Container(
                        color: VSPColors.surface,
                      ),
                      errorWidget: (context, url, error) => _buildVspLogoBackground(),
                    )
                  : _buildVspLogoBackground(),

              // DARK GRADIENT OVERLAY
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.5, 0.95],
                    colors: [
                      Colors.transparent,
                      VSPColors.background.withValues(alpha: 0.9),
                    ],
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.sm, vertical: 6),
                      decoration: BoxDecoration(
                        color: VSPColors.background.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(VSPRadius.xl),
                        border: Border.all(color: VSPColors.textPrimary.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: VSPColors.accent, size: 14),
                          const SizedBox(width: VSPSpacing.xs),
                          Text(
                            stadium.location,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: VSPColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: VSPColors.background.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                        border: Border.all(color: VSPColors.textPrimary.withValues(alpha: 0.1)),
                      ),
                      child: Icon(
                        stadium.isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: stadium.isFavorite ? VSPColors.error : VSPColors.textPrimary,
                        size: 18,
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
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: VSPSpacing.xs),
                    Row(
                      children: [
                        Text(
                          '${stadium.size} • ${stadium.type}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: VSPColors.textPrimary.withValues(alpha: 0.8),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.sm, vertical: VSPSpacing.xs),
                          decoration: BoxDecoration(
                            color: VSPColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(VSPRadius.xs),
                          ),
                          child: Text(
                            '${stadium.pricePerHour.toInt()} EG/hr',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: VSPColors.accent,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
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
