import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/egypt_governorates.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../l10n/app_localizations.dart';

/// Translates filter items (governorates and sports) according to current locale.
String championTranslateItem(BuildContext context, String item) {
  final isArabic = AppLocalizations.of(context)!.localeName == 'ar';
  if (item == 'All') {
    return isArabic ? 'كل المحافظات' : 'All Governorates';
  }
  if (!isArabic) return item;
  if (EgyptGovernorates.sportsTranslations.containsKey(item)) {
    return EgyptGovernorates.getLocalizedSport(item, true);
  }
  return EgyptGovernorates.getLocalizedName(item, true);
}

/// Initial letter badge displayed when image is unavailable.
class ChampionInitialBadge extends StatelessWidget {
  final String letter;
  final Color accentColor;

  const ChampionInitialBadge({
    super.key,
    required this.letter,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VSPColors.surfaceAlt,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: accentColor,
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
      ),
    );
  }
}

/// Podium item widget for Top 3 ranks in Teams and 1v1 leaderboards.
class ChampionPodiumItem extends StatelessWidget {
  final int rank;
  final String name;
  final String logo;
  final int points;
  final IconData badgeIcon;
  final Color borderColor;
  final Color bgColor;
  final bool isCenter;
  final String? pointsLabel;

  const ChampionPodiumItem({
    super.key,
    required this.rank,
    required this.name,
    required this.logo,
    required this.points,
    required this.badgeIcon,
    required this.borderColor,
    required this.bgColor,
    this.isCenter = false,
    this.pointsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final height = isCenter ? 260.0 : 210.0;
    final initialLetter = name.trim().isNotEmpty
        ? name.trim().split(' ').last.substring(0, 1).toUpperCase()
        : 'V';
    final ptsText = pointsLabel ?? AppLocalizations.of(context)!.pts;

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(
          color: borderColor.withValues(alpha: isCenter ? 0.9 : 0.4),
          width: isCenter ? 2 : 1,
        ),
        boxShadow: isCenter
            ? [
                VSPShadow.strong,
                BoxShadow(
                  color: VSPColors.accent.withValues(alpha: 0.25),
                  blurRadius: 16,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                )
              ]
            : const [VSPShadow.subtle],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Crown / Medal Icon
          Icon(badgeIcon, color: borderColor, size: isCenter ? 24 : 18),

          // Logo / Initial Avatar
          Container(
            width: isCenter ? 62 : 48,
            height: isCenter ? 62 : 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: VSPColors.surfaceAlt,
              border: Border.all(color: borderColor, width: 2),
            ),
            child: ClipOval(
              child: logo.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: logo,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          ChampionInitialBadge(letter: initialLetter, accentColor: borderColor),
                    )
                  : ChampionInitialBadge(letter: initialLetter, accentColor: borderColor),
            ),
          ),

          // Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isCenter ? 13 : 11,
                  ),
            ),
          ),

          // Points Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: borderColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(VSPRadius.sm),
            ),
            child: Text(
              '$points $ptsText',
              style: VSPTypography.numericStyle.copyWith(
                color: isCenter ? VSPColors.accent : Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Rank Pill Badge at Bottom
          Container(
            width: isCenter ? 36 : 28,
            height: isCenter ? 36 : 28,
            decoration: BoxDecoration(
              color: isCenter ? VSPColors.accent : VSPColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: VSPTypography.numericStyle.copyWith(
                color: isCenter ? Colors.black : Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: isCenter ? 18 : 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
