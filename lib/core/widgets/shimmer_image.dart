import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

class ShimmerImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final Widget? errorWidget;

  const ShimmerImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Shimmer.fromColors(
          baseColor: const Color(0xFF1E1E1E),
          highlightColor: const Color(0xFF2C2C2E),
          child: Container(
            width: width ?? double.infinity,
            height: height ?? double.infinity,
            color: const Color(0xFF1E1E1E),
          ),
        ),
        errorWidget: (context, url, error) => errorWidget ?? Container(
          width: width ?? double.infinity,
          height: height ?? double.infinity,
          color: const Color(0xFF1E1E1E),
          child: Center(
            child: Icon(
              fit == BoxFit.cover ? Icons.stadium_outlined : Icons.sports_soccer_outlined,
              color: AppTheme.textSecondary.withOpacity(0.5),
              size: 32,
            ),
          ),
        ),
      ),
    );
  }
}
