import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/image_pick_service.dart';
import '../../../../core/services/remote_config_service.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../owner_notification_button.dart';

/// Sleek header for Owner Dashboard with glow avatar, profile edit badge,
/// owner name, subscription plan badge, and notification button.
class OwnerDashboardHeader extends StatelessWidget {
  final AuthProvider auth;
  final bool isProOwner;
  final bool isArabic;
  final VoidCallback onUpgrade;

  const OwnerDashboardHeader({
    super.key,
    required this.auth,
    required this.isProOwner,
    required this.isArabic,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final user = auth.userModel;
    final rawName = user?.name?.trim();
    final String name = (rawName != null && rawName.isNotEmpty)
        ? rawName
        : (isArabic ? 'كابتن الملعب' : 'Pitch Owner');
    final isTrial = user?.isInActiveTrial == true;
    final photoUrl = user?.profileImageUrl;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Owner Identity with Glow Avatar, Name & Pro Badge
        Expanded(
          child: Row(
            children: [
              // 1. Avatar with Neon Green Glow Ring & Quick Edit Badge
              GestureDetector(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  final picked = await ImagePickService.pick(
                    context,
                    aspectRatio: CropAspectRatioPreset.square,
                  );
                  if (picked != null && context.mounted) {
                    try {
                      await auth.updateProfilePhoto(picked);
                      if (context.mounted) {
                        VSPFeedback.showSuccess(
                          context,
                          isArabic ? 'تم تحديث الصورة بنجاح' : 'Photo updated',
                        );
                      }
                    } catch (_) {
                      if (context.mounted) {
                        VSPFeedback.showError(
                          context,
                          isArabic ? 'فشل تحديث الصورة' : 'Failed to update photo',
                        );
                      }
                    }
                  }
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isProOwner
                            ? const SweepGradient(
                                colors: [
                                  VSPColors.accent,
                                  VSPColors.accent,
                                  VSPColors.success,
                                  VSPColors.accent,
                                ],
                              )
                            : null,
                        color: isProOwner ? null : VSPColors.surfaceAlt,
                        border: isProOwner
                            ? null
                            : Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                                width: 1.5,
                              ),
                        boxShadow: isProOwner
                            ? [
                                BoxShadow(
                                  color: VSPColors.accent.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      padding: EdgeInsets.all(isProOwner ? 2.5 : 0),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: VSPColors.surface,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: (photoUrl != null && photoUrl.trim().isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: photoUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: VSPColors.accent,
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => _buildAvatarFallback(name),
                              )
                            : _buildAvatarFallback(name),
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      right: isArabic ? null : -2,
                      left: isArabic ? -2 : null,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: VSPColors.surfaceAlt,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Iconsax.edit_2_copy,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // 2. Name & Status Badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: VSPColors.textPrimary,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        if (user?.isIdentityVerified == true || user?.verificationStatus == 'approved') ...[
                          const SizedBox(width: 5),
                          const Tooltip(
                            message: 'حساب موثق ومعتمد',
                            child: Icon(
                              Icons.verified,
                              color: Color(0xFF1DA1F2),
                              size: 16,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Badge Pill (Pro / Basic / Free Trial)
                    Row(
                      children: [
                        GestureDetector(
                          onTap: onUpgrade,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isProOwner
                                  ? VSPColors.accent.withValues(alpha: 0.14)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(VSPRadius.full),
                              border: Border.all(
                                color: isProOwner
                                    ? VSPColors.accent.withValues(alpha: 0.35)
                                    : Colors.white.withValues(alpha: 0.08),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              isProOwner
                                  ? 'PRO'
                                  : (isTrial ? (isArabic ? 'فترة مجانية' : 'Free Trial') : 'Basic'),
                              style: TextStyle(
                                color: isProOwner ? VSPColors.accent : VSPColors.textSecondary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Notifications Button
        OwnerNotificationButton(userId: auth.currentUser?.uid ?? ''),

        if (Provider.of<RemoteConfigService>(context).copilotEnabled) ...[
          const SizedBox(width: 4),

          // VSP Copilot (AI) Button - Exclusive to Pro Plan (1000 EGP)
          IconButton(
            icon: const Icon(Iconsax.flash_copy, color: VSPColors.accent, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            tooltip: 'VSP Copilot',
            onPressed: () => _handleCopilotTap(context),
          ),
        ],
      ],
    );
  }

  void _handleCopilotTap(BuildContext context) {
    HapticFeedback.lightImpact();
    final bool hasPro = isProOwner || (auth.userModel?.isProPlan == true);

    if (hasPro) {
      context.push('/copilot');
    } else {
      _showCopilotUpgradeModal(context);
    }
  }

  void _showCopilotUpgradeModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(VSPRadius.lg)),
          border: Border.all(color: VSPColors.accent.withValues(alpha: 0.25), width: 1),
          boxShadow: [
            BoxShadow(
              color: VSPColors.accent.withValues(alpha: 0.1),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(VSPRadius.xs),
                ),
              ),
              const SizedBox(height: 20),

              // Glowing AI Flash Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: VSPColors.accentSoft,
                  border: Border.all(color: VSPColors.accent.withValues(alpha: 0.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: VSPColors.accent.withValues(alpha: 0.2),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Iconsax.flash_1_copy, color: VSPColors.accent, size: 32),
                ),
              ),
              const SizedBox(height: 16),

              // Pro Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: VSPColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(VSPRadius.full),
                  border: Border.all(color: VSPColors.accent.withValues(alpha: 0.35), width: 0.8),
                ),
                child: Text(
                  isArabic ? 'باقة 1000 ج.م الاحترافية (PRO)' : 'PRO Plan Exclusive (1000 EGP)',
                  style: const TextStyle(
                    color: VSPColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                isArabic ? 'مساعد الذكاء الاصطناعي VSP Copilot' : 'VSP AI Copilot for Owners',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                isArabic
                    ? 'الذكاء الاصطناعي ميزة حصرية لمشتركي باقة 1000 ج.م الاحترافية.\nاحصل على تحليلات ذكية لحجوزات ملعبك، اقتراحات تسعير فترات الذروة، ودعم إداري فوري على مدار الساعة.'
                    : 'AI Copilot is an exclusive feature for 1000 EGP Pro Plan subscribers.\nUnlock intelligent booking forecasts, peak-hour pricing suggestions, and 24/7 automated pitch management.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: VSPColors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // CTA Button (Upgrade)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onUpgrade();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VSPColors.accent,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Iconsax.crown_1_copy, color: Colors.black, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        isArabic ? 'ترقية لباقة 1000 ج.م الآن' : 'Upgrade to Pro Plan (1000 EGP)',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Dismiss Button
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  isArabic ? 'لاحقاً' : 'Maybe Later',
                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(String name) {
    final initials = name.trim().isNotEmpty ? name.trim().substring(0, 1).toUpperCase() : 'M';
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: VSPColors.accent,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
