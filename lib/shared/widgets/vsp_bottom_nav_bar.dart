import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/ui/tokens/vsp_tokens.dart';

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
    final useBlur = VSPGlass.shouldUseBlur;

    final navContent = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(VSPRadius.full),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
        boxShadow: VSPShadow.mediumList,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onItemTapped(index);
                },
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  height: 52,
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelected ? item.activeIcon : item.inactiveIcon,
                              color: isSelected
                                  ? VSPColors.accent
                                  : Colors.black.withValues(alpha: 0.48),
                              size: 22,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.label,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSelected
                                    ? VSPColors.accent
                                    : Colors.black.withValues(alpha: 0.58),
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 11,
                                height: 1.1,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                        if (item.hasNotification && !isSelected)
                          Positioned(
                            top: 0,
                            right: -2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: VSPColors.error,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: VSPColors.error.withValues(alpha: 0.35),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
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
      borderRadius: BorderRadius.circular(VSPRadius.full),
      child: useBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: navContent,
            )
          : navContent,
    );

    return Container(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        bottom: true,
        child: Container(
          margin: const EdgeInsets.fromLTRB(
            VSPSpacing.lg,
            0,
            VSPSpacing.lg,
            VSPBottomNavBarMetrics.bottomMargin,
          ),
          height: VSPBottomNavBarMetrics.height,
          child: navCard,
        ),
      ),
    );
  }
}
