import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
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
          borderRadius: BorderRadius.circular(15), // Unified 15px
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15), // Unified 15px
          child: Stack(
            fit: StackFit.expand,
            children: [
              // REAL PHOTOGRAPHY BACKGROUND
              // REAL PHOTOGRAPHY BACKGROUND
              stadium.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: stadium.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: const Color(0xFF1E1E1E),
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
                      Colors.black.withValues(alpha: 0.9),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: AppTheme.neonGreen, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            stadium.location,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Icon(
                        stadium.isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: stadium.isFavorite ? Colors.red : Colors.white,
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${stadium.size} • ${stadium.type}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.neonGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${stadium.pricePerHour.toInt()} EG/hr',
                            style: const TextStyle(
                              color: AppTheme.neonGreen,
                              fontSize: 13,
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
      color: const Color(0xFF1E1E1E),
      child: Center(
        child: Image.asset(
          'assets/images/logo.png', // VSP logo
          width: 80,
          height: 80,
          color: Colors.white.withValues(alpha: 0.06),
          colorBlendMode: BlendMode.modulate,
        ),
      ),
    );
  }
}
