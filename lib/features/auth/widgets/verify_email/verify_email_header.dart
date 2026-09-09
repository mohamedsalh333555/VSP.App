import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Header for the verify email screen with SMS icon, title, and masked email address.
class VerifyEmailHeader extends StatelessWidget {
  final String? email;
  final bool isAr;

  const VerifyEmailHeader({
    super.key,
    required this.email,
    required this.isAr,
  });

  /// Masks email for privacy (e.g., j***e@example.com)
  static String maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final local = parts[0];
    final domain = parts[1];
    if (local.length <= 2) return '${'*' * local.length}@$domain';
    return '${local[0]}${'*' * (local.length - 2)}${local[local.length - 1]}@$domain';
  }

  @override
  Widget build(BuildContext context) {
    final displayEmail = email ?? '';
    final maskedEmail = displayEmail.isNotEmpty ? maskEmail(displayEmail) : '';

    return Column(
      children: [
        // ── Icon ───────────────────────────────────────────────────
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: VSPColors.accent.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: VSPColors.accent.withValues(alpha: 0.3),
            ),
          ),
          child: const Icon(
            Iconsax.sms_copy,
            color: VSPColors.accent,
            size: 36,
          ),
        ),

        const SizedBox(height: VSPSpacing.xl),

        // ── Title ──────────────────────────────────────────────────
        Text(
          isAr ? 'تأكيد البريد الإلكتروني' : 'Verify Your Email',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: VSPSpacing.sm),
        Text(
          isAr ? 'أرسلنا رمز تفعيل مكون من 6 أرقام إلى' : 'We sent a 6-digit code to',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: VSPColors.textSecondary),
        ),
        if (maskedEmail.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            maskedEmail,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: VSPColors.accent,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ],
    );
  }
}
