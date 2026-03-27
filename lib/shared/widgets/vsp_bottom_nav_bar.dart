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
      color: Colors.transparent, // Ensures no black background behind the nav bar
      child: SafeArea(
        bottom: false, // Prevents forced black gap on modern notched devices
        child: Container(
          margin: EdgeInsets.only(
            left: 20, 
            right: 20, 
            bottom: MediaQuery.of(context).padding.bottom + 10, // Optimized floating height
          ),
          height: 65,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: VSPColors.surface.withValues(alpha: 0.85),
                padding: const EdgeInsets.symmetric(horizontal: 12),
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
                        curve: Curves.easeInOut,
                        padding: EdgeInsets.symmetric(
                          horizontal: isSelected ? 16 : 12,
                          vertical: isSelected ? 10 : 0,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? VSPColors.accent.withValues(alpha: 0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelected ? item.activeIcon : item.inactiveIcon,
                              color: isSelected ? VSPColors.accent : VSPColors.textSecondary,
                              size: 24,
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              Text(
                                item.label,
                                style: const TextStyle(
                                  color: VSPColors.accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
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
