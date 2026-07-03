import 'package:flutter/material.dart';
import '../tokens/vsp_tokens.dart';

class VSPStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final String? trend;
  final bool isTrendPositive;
  final Color? color;

  const VSPStatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.trend,
    this.isTrendPositive = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(
          color: color?.withValues(alpha: 0.3) ?? VSPColors.accent.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: VSPColors.textSecondary,
                      ),
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 4),
                Icon(
                  icon,
                  color: color ?? VSPColors.accent,
                  size: 20,
                ),
              ],
            ],
          ),
          const SizedBox(height: VSPSpacing.xs),
          Text(
            value,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color ?? VSPColors.textPrimary,
                ),
          ),
          if (trend != null) ...[
            const SizedBox(height: VSPSpacing.xs),
            Row(
              children: [
                Icon(
                  isTrendPositive ? Icons.trending_up : Icons.trending_down,
                  color: isTrendPositive ? Colors.green : Colors.red,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  trend!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isTrendPositive ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
