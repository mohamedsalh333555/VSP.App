import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/stadium_provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../screens/global_search_screen.dart';
import '../filter_bottom_sheet.dart';
import 'home_feed_sections.dart';

/// الشريط العلوي للشاشة الرئيسية للاعب (الصورة الشخصية، الترحيب، شارة الإشعارات، وشريط البحث مع الفلتر)
class HomeTopBar extends StatelessWidget {
  final Function(int, {Map<String, dynamic>? arguments}) onNavigate;

  const HomeTopBar({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return SafeArea(
      top: true,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onNavigate(4); // الانتقال المباشر لتبويب الملف الشخصي
                  },
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: (auth.userModel?.isPro == true)
                          ? const SweepGradient(
                              colors: [VSPColors.accent, VSPColors.accent, VSPColors.success, VSPColors.accent],
                            )
                          : null,
                      color: (auth.userModel?.isPro == true) ? null : VSPColors.surface,
                      border: (auth.userModel?.isPro == true)
                          ? null
                          : Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
                      boxShadow: (auth.userModel?.isPro == true)
                          ? [
                              BoxShadow(
                                color: VSPColors.accent.withValues(alpha: 0.35),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    padding: EdgeInsets.all((auth.userModel?.isPro == true) ? 2.5 : 0),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: VSPColors.surface,
                      backgroundImage: auth.userModel?.profileImageUrl != null
                          ? NetworkImage(auth.userModel!.profileImageUrl!)
                          : null,
                      child: auth.userModel?.profileImageUrl == null
                          ? const Icon(Iconsax.user_copy, color: VSPColors.textSecondary, size: 20)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${AppLocalizations.of(context)!.hi} ${auth.userModel?.name?.split(' ').first ?? AppLocalizations.of(context)!.playerDefaultName}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        auth.userModel?.position ?? "ST",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                HomeNotificationBadge(userId: auth.currentUser?.uid ?? ''),
              ],
            ),
            const SizedBox(height: 16),
            _buildSearchBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    const double barHeight = 52.0;
    final borderRadius = BorderRadius.circular(VSPRadius.lg);

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
            ),
            child: Container(
              height: barHeight,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: borderRadius,
                border: Border.all(color: VSPColors.divider, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.search_normal_copy, color: VSPColors.accent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.searchStadiums,
                      style: const TextStyle(
                        color: VSPColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: () async {
              final result = await showModalBottomSheet<Map<String, dynamic>>(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (context) => FilterBottomSheet(
                  initialFilters: context.read<StadiumProvider>().currentFilters,
                ),
              );
              if (result != null && context.mounted) {
                context.read<StadiumProvider>().applyFilters(result);
              }
            },
            child: Container(
              width: barHeight,
              height: barHeight,
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: borderRadius,
                border: Border.all(color: VSPColors.divider, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Iconsax.filter_copy, color: VSPColors.accent, size: 20),
            ),
          ),
        ),
      ],
    );
  }
}
