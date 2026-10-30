import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/ui/tokens/vsp_design_tokens.dart';

/// Global network banner wrapper that floats at the top of the entire application
/// whenever the device loses internet connection.
class VSPNetworkBanner extends StatelessWidget {
  final Widget child;

  const VSPNetworkBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.instance.isOnlineNotifier,
      builder: (context, isOnline, _) {
        final isArabic = Localizations.maybeLocaleOf(context)?.languageCode == 'ar';

        return Stack(
          children: [
            child,
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: isOnline,
                child: AnimatedSlide(
                  duration: VSPDSMotion.emphasis,
                  curve: Curves.easeInOutCubic,
                  offset: isOnline ? const Offset(0, -1.5) : Offset.zero,
                  child: AnimatedOpacity(
                    duration: VSPDSMotion.standard,
                    curve: Curves.easeInOut,
                    opacity: isOnline ? 0.0 : 1.0,
                    child: Material(
                      color: Colors.transparent,
                      child: SafeArea(
                        bottom: false,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: VSPDSSpacing.sm, vertical: VSPDSSpacing.xxs),
                          padding: const EdgeInsets.symmetric(horizontal: VSPDSSpacing.md, vertical: VSPDSSpacing.xs),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [VSPDSSemanticColors.error, VSPDSSemanticColors.error.withValues(alpha: 0.8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(VSPDSRadius.lg),
                            boxShadow: [
                              VSPDSComponentEffects.networkBannerShadow,
                            ],
                            border: Border.all(
                              color: VSPDSColors.white15,
                              width: VSPDSBorders.standard,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              const Icon(
                                Iconsax.wifi_square_copy,
                                color: VSPDSSemanticColors.textPrimary,
                                size: VSPDSizes.iconMd,
                              ),
                              const SizedBox(width: VSPDSSpacing.xs),
                              Expanded(
                                child: Text(
                                  isArabic
                                      ? 'لا يوجد اتصال بالإنترنت — البيانات قد تكون غير محدثة'
                                      : 'No internet connection — data may be outdated',
                                  style: VSPDSTypography.bodySmall.copyWith(
                                    color: VSPDSSemanticColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
