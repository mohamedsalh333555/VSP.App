import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:safe_device/safe_device.dart';
import '../../core/ui/tokens/vsp_tokens.dart';

class VSPNativeAd extends StatefulWidget {
  const VSPNativeAd({super.key});

  @override
  State<VSPNativeAd> createState() => _VSPNativeAdState();
}

class _VSPNativeAdState extends State<VSPNativeAd> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _isRealDevice = false;
  bool _checkingDevice = true;

  @override
  void initState() {
    super.initState();
    _checkDeviceAndLoadAd();
  }

  Future<void> _checkDeviceAndLoadAd() async {
    if (kIsWeb) {
      if (mounted) setState(() => _checkingDevice = false);
      return;
    }

    try {
      final bool realDevice = await SafeDevice.isRealDevice;
      if (mounted) {
        setState(() {
          _isRealDevice = realDevice;
          _checkingDevice = false;
        });
      }
      
      // Only load Google Mobile Ads if we are on a real physical device to prevent Emulator Impeller deadlocks
      if (realDevice) {
        _loadAd();
      }
    } catch (e) {
      debugPrint('Error checking device status for ads: $e');
      if (mounted) {
        setState(() => _checkingDevice = false);
      }
    }
  }

  void _loadAd() {
    final String adUnitId = defaultTargetPlatform == TargetPlatform.android
        ? 'ca-app-pub-3940256099942544/2247696110'
        : 'ca-app-pub-3940256099942544/3986624511';

    _nativeAd = NativeAd(
      adUnitId: adUnitId,
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Ad failed to load: $error');
        },
      ),
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: VSPColors.surface,
        cornerRadius: VSPRadius.lg,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.black,
          backgroundColor: VSPColors.accent,
          style: NativeTemplateFontStyle.bold,
          size: 15.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: VSPColors.textPrimary,
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: VSPColors.textSecondary,
          style: NativeTemplateFontStyle.normal,
          size: 13.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: VSPColors.textSecondary.withValues(alpha: 0.7),
          style: NativeTemplateFontStyle.normal,
          size: 11.0,
        ),
      ),
    );

    _nativeAd?.load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const SizedBox.shrink();
    }

    if (_checkingDevice) {
      return Container(
        height: 240,
        width: 300,
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.lg),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: VSPColors.accent),
        ),
      );
    }

    if (!_isRealDevice || !_isAdLoaded || _nativeAd == null) {
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';

      return Container(
        width: 300,
        height: 240,
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.lg),
          border: Border.all(color: VSPColors.accent.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: VSPColors.accent.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: VSPColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(VSPRadius.xs),
                  ),
                  child: Text(
                    isArabic ? "إعلان ترويجي ممول" : "Promoted Ad",
                    style: const TextStyle(
                      color: VSPColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Icon(Icons.info_outline, color: VSPColors.textSecondary, size: 16),
              ],
            ),
            const Spacer(),
            Text(
              isArabic ? "بطولات VSP الكبرى 🏆" : "VSP Grand Championships 🏆",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isArabic
                  ? "نافس الآن مع فريقك في أكبر دوري خماسي واحصل على فرصة للفوز بجوائز قيمة تصل لـ 50,000 جنيه!"
                  : "Compete with your team in the biggest 5-a-side league and win cash prizes up to 50,000 EGP!",
              style: const TextStyle(
                color: VSPColors.textSecondary,
                fontSize: 11,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Align(
              alignment: isArabic ? Alignment.bottomLeft : Alignment.bottomRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: VSPColors.accent,
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                ),
                child: Text(
                  isArabic ? "سجل فريقك" : "Register Team",
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 240,
      width: 300,
      child: AdWidget(ad: _nativeAd!),
    );
  }
}
