import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/image_pick_service.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';

class OwnerAvatarHeader extends StatelessWidget {
  final AuthProvider auth;

  const OwnerAvatarHeader({
    super.key,
    required this.auth,
  });

  Widget _buildInitials(String name) {
    final initial = name.trim().isNotEmpty ? name.trim().substring(0, 1).toUpperCase() : 'M';
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: VSPColors.accent,
          fontSize: 28,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final photoUrl = auth.userModel?.profileImageUrl;
    final name = auth.userModel?.name ?? '';
    final bool isPro = auth.userModel?.isPro ?? false;

    return Center(
      child: GestureDetector(
        onTap: () async {
          HapticFeedback.lightImpact();
          final picked = await ImagePickService.pick(context, aspectRatio: CropAspectRatioPreset.square);
          if (picked != null && context.mounted) {
            try {
              await auth.updateProfilePhoto(picked);
              if (context.mounted) {
                VSPFeedback.showSuccess(context, isArabic ? 'تم تحديث الصورة بنجاح' : 'Photo updated');
              }
            } catch (_) {
              if (context.mounted) {
                VSPFeedback.showError(context, isArabic ? 'فشل تحديث الصورة' : 'Failed to update');
              }
            }
          }
        },
        child: Stack(
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isPro
                    ? const SweepGradient(
                        colors: [VSPColors.accent, Color(0xFF84CC16), Color(0xFF22C55E), VSPColors.accent],
                      )
                    : null,
                color: isPro ? null : const Color(0xFF1E1E24),
                border: isPro ? null : Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
                boxShadow: isPro
                    ? [
                        BoxShadow(color: VSPColors.accent.withValues(alpha: 0.3), blurRadius: 12),
                      ]
                    : null,
              ),
              padding: EdgeInsets.all(isPro ? 2.5 : 0),
              child: Container(
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF141417)),
                clipBehavior: Clip.antiAlias,
                child: (photoUrl != null && photoUrl.trim().isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: photoUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _buildInitials(name),
                      )
                    : _buildInitials(name),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: VSPColors.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: const Icon(Iconsax.camera_copy, size: 13, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
