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
/// owner name and notification button.
/// Note: isProOwner kept for backward compatibility but subscription badges removed.
class OwnerDashboardHeader extends StatelessWidget {
  final AuthProvider auth;
  final bool isArabic;
  // isProOwner kept for compat — no longer renders Pro/Free badge
  final bool isProOwner;
  final VoidCallback? onUpgrade;

  const OwnerDashboardHeader({
    super.key,
    required this.auth,
    required this.isArabic,
    this.isProOwner = false,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final user = auth.userModel;
    final rawName = user?.name?.trim();
    final String name = (rawName != null && rawName.isNotEmpty)
        ? rawName
        : (isArabic ? 'كابتن الملعب' : 'Pitch Owner');
    final photoUrl = user?.profileImageUrl;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Owner Identity with Glow Avatar & Name
        Expanded(
          child: Row(
            children: [
              // 1. Avatar with Quick Edit Badge
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
                        color: VSPColors.surfaceAlt,
                        border: Border.all(
                          color: VSPColors.divider,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: VSPColors.background.withValues(alpha: 0.15),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(0),
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
                                      color: VSPColors.textPrimary,
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

              // 2. Owner Name
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
                              color: VSPColors.textPrimary,
                              size: 16,
                            ),
                          ),
                        ],
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
      ],
    );
  }

  Widget _buildAvatarFallback(String name) {
    final initials = name.trim().isNotEmpty ? name.trim().substring(0, 1).toUpperCase() : 'M';
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: VSPColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
