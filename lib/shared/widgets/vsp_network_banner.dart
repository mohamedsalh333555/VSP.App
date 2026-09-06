import 'package:flutter/material.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/ui/tokens/vsp_tokens.dart';

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
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOutCubic,
                  offset: isOnline ? const Offset(0, -1.5) : Offset.zero,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    opacity: isOnline ? 0.0 : 1.0,
                    child: Material(
                      color: Colors.transparent,
                      child: SafeArea(
                        bottom: false,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(VSPRadius.lg),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              const Icon(
                                Icons.wifi_off_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  isArabic
                                      ? 'لا يوجد اتصال بالإنترنت — البيانات قد تكون غير محدثة'
                                      : 'No internet connection — data may be outdated',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
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
