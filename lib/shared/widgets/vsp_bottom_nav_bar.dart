import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/ui/tokens/vsp_design_tokens.dart';

class VspNavItem {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  final bool hasNotification;

  VspNavItem({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
    this.hasNotification = false,
  });
}

/// Canonical VSP bottom navigation.
///
/// Navigation visual contract:
/// - selected item: bold/filled active glyph, accent color, stronger scale and bold label;
/// - unselected item: outline/inactive glyph, secondary color and regular label.
/// Call sites must provide the matching active/inactive Iconsax variants.
class VspBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final List<VspNavItem> items;

  const VspBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final useBlur = VSPDSGlass.shouldUseBlur;

    final navContent = Container(
      decoration: BoxDecoration(
        color: useBlur
            ? VSPDSColors.glassSurface.withValues(
                alpha: VSPDSOpacity.navigationGlass,
              )
            : VSPDSSemanticColors.surface,
        border: const Border(
          top: BorderSide(
            color: VSPDSColors.white08,
            width: VSPDSBorders.standard,
          ),
        ),
        boxShadow: const <BoxShadow>[
          VSPDSElevation.medium,
        ],
      ),
      padding: const EdgeInsets.fromLTRB(
        VSPDSSpacing.xs,
        VSPDSSpacing.xs,
        VSPDSSpacing.xs,
        VSPDSSpacing.navigationBottomPadding,
      ),
      child: Row(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isSelected = index == selectedIndex;

          return Expanded(
            child: Semantics(
              button: true,
              selected: isSelected,
              label: item.label,
              child: InkWell(
                borderRadius: BorderRadius.circular(VSPDSRadius.md),
                onTap: () {
                  HapticFeedback.lightImpact();
                  onItemTapped(index);
                },
                child: SizedBox(
                  height: VSPDSizes.navigationItemHeight,
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSwitcher(
                              duration: VSPDSMotion.navigationSwitch,
                              child: Icon(
                                isSelected
                                    ? item.activeIcon
                                    : item.inactiveIcon,
                                key: ValueKey(isSelected),
                                color: isSelected
                                    ? VSPDSSemanticColors.accent
                                    : VSPDSSemanticColors.textSecondary,
                                size: isSelected ? VSPDSizes.navigationIconSelected : VSPDSizes.navigationIcon,
                              ),
                            ),
                            const SizedBox(height: VSPDSSpacing.xxs),
                            Text(
                              item.label,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: (isSelected
                                      ? VSPDSTypography.navigationSelected
                                      : VSPDSTypography.navigationUnselected)
                                  .copyWith(
                                color: isSelected
                                    ? VSPDSSemanticColors.accent
                                    : VSPDSSemanticColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        if (item.hasNotification && !isSelected)
                          Positioned(
                            top: VSPDSizes.navigationNotificationTop,
                            right: VSPDSizes.navigationNotificationRight,
                            child: Container(
                              width: VSPDSizes.notificationDot,
                              height: VSPDSizes.notificationDot,
                              decoration: const BoxDecoration(
                                color: VSPDSSemanticColors.error,
                                shape: BoxShape.circle,
                                boxShadow: <BoxShadow>[
                                  VSPDSComponentEffects
                                      .navigationNotificationGlow,
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );

    final navCard = ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(VSPDSRadius.xl),
      ),
      child: useBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: VSPDSBlur.navigationGlassSigma,
                sigmaY: VSPDSBlur.navigationGlassSigma,
              ),
              child: navContent,
            )
          : navContent,
    );

    return Container(
      color: VSPDSColors.transparent,
      child: SafeArea(
        top: false,
        bottom: true,
        child: SizedBox(
          width: double.infinity,
          height: VSPBottomNavMetrics.height,
          child: navCard,
        ),
      ),
    );
  }
}
