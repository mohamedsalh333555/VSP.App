import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../core/ui/tokens/vsp_tokens.dart';
import '../../data/models.dart';

class TeamCardHero extends StatelessWidget {
  final Team team;
  final bool isScreenshotMode;

  const TeamCardHero({
    super.key,
    required this.team,
    this.isScreenshotMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final winRate = team.matchesPlayed > 0 
        ? (team.wins / team.matchesPlayed * 100).toStringAsFixed(0) 
        : '0';

    return Container(
      width: isScreenshotMode ? 350 : double.infinity,
      constraints: const BoxConstraints(minHeight: 440, maxHeight: 520),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1A1A),
            Color(0xFF0D0D0D),
            Color(0xFF1E3A1E), // Subtle dark emerald hint
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: VSPColors.accent.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(
          color: VSPColors.accent.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          // Background Design Elements
          Positioned(
            right: -50,
            top: -50,
            child: Icon(
              Iconsax.security_safe_copy,
              size: 250,
              color: VSPColors.white.withValues(alpha: 0.03),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(VSPSpacing.xl),
            child: Column(
              children: [
                // 1. Top Section: Rank & Points
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTopStat(AppLocalizations.of(context)!.ovrLabel, team.points.toString()),
                    _buildTopStat(AppLocalizations.of(context)!.gldLabel, team.championshipsWon.toString(), isGold: true),
                  ],
                ),
                
                const SizedBox(height: VSPSpacing.md),
                
                // 2. Center Section: Logo
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: VSPColors.accent, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: VSPColors.accent.withValues(alpha: 0.4),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: team.logoUrl.isNotEmpty 
                        ? Image.network(team.logoUrl, fit: BoxFit.cover)
                        : Icon(Iconsax.security_safe_copy, size: 80, color: VSPColors.white),
                  ),
                ),
                
                const SizedBox(height: VSPSpacing.md),
                
                // 3. Team Name
                Text(
                  team.name.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: VSPColors.textPrimary,
                    letterSpacing: 2,
                  ),
                ),
                
                // 4. Rank Title
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: VSPColors.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(VSPRadius.sm),
                  ),
                  child: Text(
                    team.rankTitle.toUpperCase(),
                    style: const TextStyle(
                      color: VSPColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                
                const Spacer(),
                const Divider(color: VSPColors.white12, thickness: 1),
                
                // 5. Grid Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildGridStat(AppLocalizations.of(context)!.winRateLabel, winRate),
                    _buildGridStat(AppLocalizations.of(context)!.winsLabel.toUpperCase(), team.wins.toString()),
                    _buildGridStat(AppLocalizations.of(context)!.strkLabel.toUpperCase(), team.currentWinningStreak.toString()),
                  ],
                ),
                
                const SizedBox(height: VSPSpacing.md),
                
                // Footer: Branding
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/logo.png', height: 20, errorBuilder: (_, __, ___) => const SizedBox()),
                    const SizedBox(width: 8),
                    const Text(
                      'VSP CHAMPIONSHIP',
                      style: TextStyle(
                        color: VSPColors.white38,
                        fontSize: 10,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopStat(String label, String value, {bool isGold = false}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: isGold ? Colors.amber : VSPColors.white38,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isGold ? Colors.amber : VSPColors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildGridStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: VSPColors.white38,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: VSPColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
