import 'package:flutter/material.dart';
import '../tokens/vsp_tokens.dart';

enum VSPBadgeVariant {
  accent,
  warning,
  success,
  error,
  neutral,
}

/// Unified Status Badge component adhering to the VSP Design System.
/// Used for verification statuses, subscription plans, and operational tags.
class VSPStatusBadge extends StatelessWidget {
  final String label;
  final VSPBadgeVariant variant;
  final IconData? icon;
  final VoidCallback? onTap;

  const VSPStatusBadge({
    super.key,
    required this.label,
    this.variant = VSPBadgeVariant.neutral,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color text;

    switch (variant) {
      case VSPBadgeVariant.accent:
        bg = VSPColors.accent.withValues(alpha: 0.12);
        border = VSPColors.accent.withValues(alpha: 0.35);
        text = VSPColors.accent;
        break;
      case VSPBadgeVariant.warning:
        bg = VSPColors.warning.withValues(alpha: 0.12);
        border = VSPColors.warning.withValues(alpha: 0.40);
        text = VSPColors.warning;
        break;
      case VSPBadgeVariant.success:
        bg = VSPColors.success.withValues(alpha: 0.12);
        border = VSPColors.success.withValues(alpha: 0.40);
        text = VSPColors.success;
        break;
      case VSPBadgeVariant.error:
        bg = VSPColors.error.withValues(alpha: 0.12);
        border = VSPColors.error.withValues(alpha: 0.40);
        text = VSPColors.error;
        break;
      case VSPBadgeVariant.neutral:
        bg = Colors.white.withValues(alpha: 0.05);
        border = Colors.white.withValues(alpha: 0.10);
        text = VSPColors.textSecondary;
        break;
    }

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(VSPRadius.full),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: text),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: text,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }
    return content;
  }
}
