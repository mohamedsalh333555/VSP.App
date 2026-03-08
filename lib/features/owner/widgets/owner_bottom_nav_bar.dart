import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../../core/ui/tokens/vsp_tokens.dart';

class NavItem {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;

  NavItem({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
  });
}

class OwnerBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  OwnerBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final List<NavItem> _navItems = [
    NavItem(
      activeIcon: Icons.home_filled,
      inactiveIcon: Icons.home_outlined,
      label: 'Home',
    ),
    NavItem(
      activeIcon: Icons.emoji_events,
      inactiveIcon: Icons.emoji_events_outlined,
      label: 'Cup',
    ),
    NavItem(
      activeIcon: Icons.work,
      inactiveIcon: Icons.work_outline,
      label: 'Booked',
    ),
    NavItem(
      activeIcon: Icons.person,
      inactiveIcon: Icons.person_outline,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: 20, 
        right: 20, 
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      height: 65,
      decoration: BoxDecoration(
        color: VSPColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _navItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isSelected = index == currentIndex;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onTap(index);
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
    );
  }
}
