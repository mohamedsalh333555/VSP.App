import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/ui/tokens/vsp_tokens.dart';

class VspNavItem {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;

  VspNavItem({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
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
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        bottom: true,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          height: 68,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: VSPColors.glassSurface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: VSPColors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
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
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.elasticOut,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? VSPColors.accent.withValues(alpha: 0.12) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.activeIcon,
                              color: isSelected ? VSPColors.accent : VSPColors.textSecondary.withValues(alpha: 0.5),
                              size: 22,
                            ),
                            if (isSelected) ...[
                              const SizedBox(height: 4),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  color: VSPColors.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}