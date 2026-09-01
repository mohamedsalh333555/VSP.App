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
      baseColor: const Color(0xFF1E1E22),
      highlightColor: const Color(0xFF2C2C32),
      period: const Duration(milliseconds: 1400),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E22),
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
      width: MediaQuery.of(context).size.width * 0.85,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 0.8),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              VSPSkeleton(width: 50, height: 50, borderRadius: 25),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VSPSkeleton(width: 120, height: 16),
                  SizedBox(height: 8),
                  VSPSkeleton(width: 80, height: 12),
                ],
              ),
            ],
          ),
          SizedBox(height: 24),
          VSPSkeleton(width: double.infinity, height: 40),
          SizedBox(height: 16),
          VSPSkeleton(width: 100, height: 12),
          SizedBox(height: 8),
          VSPSkeleton(width: double.infinity, height: 4),
        ],
      ),
    );
  }
}
