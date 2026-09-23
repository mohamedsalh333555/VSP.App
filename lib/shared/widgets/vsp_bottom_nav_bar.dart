import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/ui/tokens/vsp_tokens.dart';

class VspNavItem {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  final bool hasNotification; // نقطة الإشعار

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
            ? VSPColors.glassSurface.withValues(alpha: 0.9)
            : VSPColors.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(VSPRadius.full),
        border: Border.all(
          color: VSPColors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: VSPShadow.mediumList,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isSelected = index == selectedIndex;

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onItemTapped(index);
            },
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: isSelected ? 16.0 : 12.0,
                vertical: 10.0,
              ),
              decoration: BoxDecoration(
                color: isSelected ? VSPColors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(VSPRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // الأيقونة مع النقطة الحمراء
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        isSelected ? item.activeIcon : item.inactiveIcon,
                        color: isSelected ? Colors.black : VSPColors.textSecondary,
                        size: 20,
                      ),
                      // نقطة الإشعار
                      if (item.hasNotification && !isSelected)
                        Positioned(
                          top: -3,
                          right: -3,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.elasticOut,
                            builder: (ctx, val, _) => Transform.scale(
                              scale: val,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: VSPColors.error,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: VSPColors.error.withValues(alpha: 0.6),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 8),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: isSelected ? 1.0 : 0.0,
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );

    return Container(
      color: Colors.transparent,
      child: SafeArea(
        bottom: true,
        child: Container(
          margin: const EdgeInsets.fromLTRB(VSPSpacing.lg, 0, VSPSpacing.lg, VSPSpacing.md),
          height: 64,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(VSPRadius.full),
            child: useBlur
                ? BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: navContent,
                  )
                : navContent,
          ),
        ),
      ),
    );
  }
}