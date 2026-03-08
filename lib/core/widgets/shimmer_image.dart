import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../ui/tokens/vsp_tokens.dart';

class ShimmerImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final Widget? errorWidget;
  final int? memCacheWidth;
  final int? memCacheHeight;

  const ShimmerImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
    this.errorWidget,
    this.memCacheWidth,
    this.memCacheHeight,
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
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        placeholder: (context, url) => Shimmer.fromColors(
          baseColor: VSPColors.surface,
          highlightColor: VSPColors.surfaceAlt,
          child: Container(
            width: width ?? double.infinity,
            height: height ?? double.infinity,
            color: VSPColors.surface,
          ),
        ),
        errorWidget: (context, url, error) => errorWidget ?? Container(
          width: width ?? double.infinity,
          height: height ?? double.infinity,
          color: VSPColors.surface,
          child: Center(
            child: Icon(
              fit == BoxFit.cover ? Icons.stadium_outlined : Icons.sports_soccer_outlined,
              color: VSPColors.textSecondary.withValues(alpha: 0.5),
              size: 32,
            ),
          ),
        ),
      ),
    );
  }
}

