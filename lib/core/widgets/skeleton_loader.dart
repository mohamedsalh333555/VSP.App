import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../ui/tokens/vsp_tokens.dart';

class VSPSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const VSPSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.white.withOpacity(0.05),
      highlightColor: Colors.white.withOpacity(0.1),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class CardSkeleton extends StatelessWidget {
  const CardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const VSPSkeleton(width: 50, height: 50, borderRadius: 25),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  VSPSkeleton(width: 120, height: 16),
                  SizedBox(height: 8),
                  VSPSkeleton(width: 80, height: 12),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const VSPSkeleton(width: double.infinity, height: 40),
          const SizedBox(height: 16),
          const VSPSkeleton(width: 100, height: 12),
          const SizedBox(height: 8),
          const VSPSkeleton(width: double.infinity, height: 4),
        ],
      ),
    );
  }
}
