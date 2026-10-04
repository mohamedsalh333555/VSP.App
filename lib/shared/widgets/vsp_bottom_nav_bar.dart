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
        color: useBlur
            ? VSPColors.glassSurface.withValues(alpha: 0.94)
            : VSPColors.surface,
        border: Border(
          top: BorderSide(
            color: VSPColors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        boxShadow: VSPShadow.mediumList,
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
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
                  height: 58,
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: Icon(
                                isSelected ? item.activeIcon : item.inactiveIcon,
                                key: ValueKey(isSelected),
                                color: isSelected
                                    ? VSPColors.accent
                                    : VSPColors.textSecondary,
                                size: 23,
                              ),
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
                                    : VSPColors.textSecondary,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                fontSize: 11,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                        if (item.hasNotification && !isSelected)
                          Positioned(
                            top: -1,
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
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(VSPRadius.xl),
      ),
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
        child: SizedBox(
          width: double.infinity,
          height: VSPBottomNavBarMetrics.height,
          child: navCard,
        ),
      ),
    );
  }
}
