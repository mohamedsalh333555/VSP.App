import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/components/vsp_card.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/widgets/shimmer_image.dart';
import '../../../../data/models.dart';
import '../../../../shared/widgets/copyable_phone_text.dart';

class TeamProfileCaptainCard extends StatelessWidget {
  final Team team;
  final VoidCallback onContactCaptain;

  const TeamProfileCaptainCard({
    super.key,
    required this.team,
    required this.onContactCaptain,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isArabic ? 'كابتن الفريق' : 'Team Captain', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: VSPSpacing.sm),
        VSPCard(
          padding: const EdgeInsets.all(VSPSpacing.md),
          margin: EdgeInsets.zero,
          color: VSPColors.surface,
          child: Row(
            children: [
              ShimmerImage(
                imageUrl: team.captainImageUrl,
                width: 48,
                height: 48,
                borderRadius: 24,
                errorWidget: const CircleAvatar(
                  radius: 24,
                  backgroundColor: VSPColors.surfaceAlt,
                  child: Icon(Iconsax.user_copy, color: VSPColors.textSecondary),
                ),
              ),
              const SizedBox(width: VSPSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.captainName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isArabic ? 'المدير الفني / كابتن' : 'Manager / Captain',
                      style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                    ),
                    if (team.captainPhone != null && team.captainPhone!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      CopyablePhoneText(
                        phone: team.captainPhone!,
                        style: const TextStyle(
                          color: VSPColors.accent,
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (team.captainPhone != null && team.captainPhone!.isNotEmpty)
                IconButton(
                  icon: const Icon(Iconsax.messages_3_copy, color: VSPColors.accent),
                  onPressed: onContactCaptain,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
