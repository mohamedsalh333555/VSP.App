import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../data/models/team_gamification_models.dart';

/// Displays the team's annual shield crest.
/// Uses the official 3D PNG asset when bundled under assets/images/shields/
/// and falls back cleanly to a layered metallic frame when unavailable.
class VspShieldBadge extends StatefulWidget {
  final TeamShieldTier tier;
  final double size;
  final bool animateReveal;
  final bool showLabel;
  final bool showGlow;
  final bool isArabic;

  const VspShieldBadge({
    super.key,
    required this.tier,
    this.size = 56,
    this.animateReveal = false,
    this.showLabel = false,
    this.showGlow = true,
    this.isArabic = true,
  });

  @override
  State<VspShieldBadge> createState() => _VspShieldBadgeState();
}

class _VspShieldBadgeState extends State<VspShieldBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.animateReveal) {
      _ctrl.forward();
    }
  }

  @override
  void didUpdateWidget(covariant VspShieldBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animateReveal && oldWidget.tier != widget.tier) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnim = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final assetPath = widget.tier.assetPath;
    final color = widget.tier.primaryColor;

    Widget crest = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: widget.tier == TeamShieldTier.none ? 0.12 : 0.28),
            color.withValues(alpha: 0.04),
            Colors.transparent,
          ],
        ),
        border: Border.all(
          color: color.withValues(alpha: widget.tier == TeamShieldTier.none ? 0.25 : 0.7),
          width: widget.size >= 64 ? 2.0 : 1.2,
        ),
        boxShadow: (!widget.showGlow || widget.tier == TeamShieldTier.none)
            ? null
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: widget.size * 0.22,
                  spreadRadius: 1,
                ),
              ],
      ),
      child: Center(
        child: assetPath != null
            ? ClipOval(
                child: Image.asset(
                  assetPath,
                  width: widget.size * 0.86,
                  height: widget.size * 0.86,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => _FallbackMetallicCrest(
                    tier: widget.tier,
                    size: widget.size,
                  ),
                ),
              )
            : _FallbackMetallicCrest(
                tier: widget.tier,
                size: widget.size,
              ),
      ),
    );

    if (widget.animateReveal && !disableAnim && widget.tier != TeamShieldTier.none) {
      crest = ScaleTransition(
        scale: CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
        child: crest,
      );
    }

    if (!widget.showLabel) return crest;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        crest,
        const SizedBox(height: 6),
        Text(
          widget.tier.label(widget.isArabic),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _FallbackMetallicCrest extends StatelessWidget {
  final TeamShieldTier tier;
  final double size;

  const _FallbackMetallicCrest({required this.tier, required this.size});

  @override
  Widget build(BuildContext context) {
    final iconData = switch (tier) {
      TeamShieldTier.none => Iconsax.shield_tick_copy,
      TeamShieldTier.immortal => Iconsax.crown_1_copy,
      TeamShieldTier.legendary => Iconsax.award_copy,
      _ => Iconsax.shield_tick_copy,
    };
    return Icon(
      iconData,
      size: size * 0.52,
      color: tier.primaryColor,
    );
  }
}
