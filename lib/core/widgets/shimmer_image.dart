import 'dart:io';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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

  Widget _buildErrorWidget() {
    return Container(
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      color: VSPColors.surface,
      child: Center(
        child: Icon(
          fit == BoxFit.cover ? LucideIcons.building : LucideIcons.trophy,
          color: VSPColors.textSecondary.withValues(alpha: 0.5),
          size: 32,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    int? resolvedCacheWidth = memCacheWidth;
    int? resolvedCacheHeight = memCacheHeight;

    if (resolvedCacheWidth == null && width != null && width! > 0 && width!.isFinite) {
      resolvedCacheWidth = (width! * devicePixelRatio).round();
    }
    if (resolvedCacheHeight == null && height != null && height! > 0 && height!.isFinite) {
      resolvedCacheHeight = (height! * devicePixelRatio).round();
    }

    if (resolvedCacheWidth == null && resolvedCacheHeight == null) {
      resolvedCacheWidth = 400;
    }

    // Check for local file / asset paths
    final cleanUrl = imageUrl.trim();
    final isNetwork = cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://');

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: () {
        if (!isNetwork) {
          if (cleanUrl.isEmpty) {
            return errorWidget ?? _buildErrorWidget();
          }
          if (cleanUrl.startsWith('assets/')) {
            return Image.asset(
              cleanUrl,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (context, error, stackTrace) => errorWidget ?? _buildErrorWidget(),
            );
          }
          try {
            final filePath = cleanUrl.replaceFirst('file://', '');
            final file = File(filePath);
            if (file.existsSync()) {
              return Image.file(
                file,
                width: width,
                height: height,
                fit: fit,
                errorBuilder: (context, error, stackTrace) => errorWidget ?? _buildErrorWidget(),
              );
            }
          } catch (_) {}
          return errorWidget ?? _buildErrorWidget();
        }

        return CachedNetworkImage(
          imageUrl: cleanUrl,
          width: width,
          height: height,
          fit: fit,
          memCacheWidth: resolvedCacheWidth,
          memCacheHeight: resolvedCacheHeight,
          placeholder: (context, url) => Shimmer.fromColors(
            baseColor: VSPColors.surface,
            highlightColor: VSPColors.surfaceAlt,
            child: Container(
              width: width ?? double.infinity,
              height: height ?? double.infinity,
              color: VSPColors.surface,
            ),
          ),
          errorWidget: (context, url, error) => errorWidget ?? _buildErrorWidget(),
        );
      }(),
    );
  }
}

