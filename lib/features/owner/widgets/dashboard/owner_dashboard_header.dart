import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/image_pick_service.dart';
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
                                  Color(0xFF84CC16),
                                  Color(0xFF22C55E),
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
                      bottom: -1,
                      right: isArabic ? null : -1,
                      left: isArabic ? -1 : null,
                      child: Container(
                        width: 19,
                        height: 19,
                        decoration: BoxDecoration(
                          color: VSPColors.surfaceAlt,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
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
                          size: 10,
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
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: VSPColors.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(VSPRadius.full),
                              border: Border.all(
                                color: VSPColors.success.withValues(alpha: 0.25),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Iconsax.verify_copy,
                                  color: VSPColors.success,
                                  size: 11,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  isArabic ? 'معتمد' : 'Verified',
                                  style: const TextStyle(
                                    color: VSPColors.success,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
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

        const SizedBox(width: 10),

        // Notifications Button
        OwnerNotificationButton(userId: auth.currentUser?.uid ?? ''),
      ],
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
