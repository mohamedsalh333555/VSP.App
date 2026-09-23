import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_launcher_utils.dart';
import '../../../../shared/widgets/primary_button.dart';

/// شاشة طمأنة وتأكيد الدفع الحركية - متوافقة 100% مع نظام تصميم VSP
class PaymentVerificationModal extends StatefulWidget {
  final String bookingId;
  final bool isArabic;
  final VoidCallback onGoToBookings;

  const PaymentVerificationModal({
    super.key,
    required this.bookingId,
    required this.isArabic,
    required this.onGoToBookings,
  });

  static Future<void> show({
    required BuildContext context,
    required String bookingId,
    required bool isArabic,
    required VoidCallback onGoToBookings,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => PaymentVerificationModal(
        bookingId: bookingId,
        isArabic: isArabic,
        onGoToBookings: onGoToBookings,
      ),
    );
  }

  @override
  State<PaymentVerificationModal> createState() => _PaymentVerificationModalState();
}

class _PaymentVerificationModalState extends State<PaymentVerificationModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _delayTimer;
  bool _isProlongedWait = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // بعد 38 ثانية في حال تأخر رد بوابة الدفع لأسباب شبكة، نتحول لحالة التطمين الإيجابي بدلاً من إظهار أخطاء مرعبة
    _delayTimer = Timer(const Duration(seconds: 38), () {
      if (mounted) setState(() => _isProlongedWait = true);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _delayTimer?.cancel();
    super.dispose();
  }

  void _contactSupport() {
    final cleanRef = widget.bookingId.length >= 8
        ? widget.bookingId.substring(0, 8).toUpperCase()
        : widget.bookingId.toUpperCase();
    final msg = widget.isArabic
        ? 'مرحباً، قمت بسداد الحجز رقم #$cleanRef عبر التطبيق ومحتاج تأكيد الدعم.'
        : 'Hello, I completed payment for booking #$cleanRef and need quick confirmation.';
    VSPLauncherUtils.openWhatsApp(context, phone: '201100229462', message: msg);
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = _isProlongedWait ? VSPColors.warning : VSPColors.accent;

    return PopScope(
      canPop: false,
      child: Center(
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.dialog),
              border: Border.all(
                color: VSPColors.borderLight,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.65),
                  blurRadius: 36,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Sleek Pulsing Header Icon
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: iconColor.withValues(alpha: 0.12),
                      border: Border.all(
                        color: iconColor.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        _isProlongedWait ? Iconsax.clock_copy : Iconsax.security_safe_copy,
                        color: iconColor,
                        size: 30,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // 2. Title & Subtitle
                Text(
                  _isProlongedWait
                      ? (widget.isArabic ? 'طلبك قيد المعالجة والتأكيد' : 'Processing Confirmation')
                      : (widget.isArabic ? 'تأكيد حجز الملعب' : 'Securing Stadium Booking'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: VSPColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isProlongedWait
                      ? (widget.isArabic
                          ? 'إذا تم خصم المبلغ من حسابك، حجزك مضمون ومحمي بنجاح. جاري استكمال التأكيد البنكي.'
                          : 'If payment was deducted, your booking is safe. Bank sync is completing.')
                      : (widget.isArabic
                          ? 'لحظات ويتم قفل الساعة بجدول الملعب وإصدار تذكرتك فورياً...'
                          : 'Locking your slot in the stadium calendar and issuing your ticket...'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: VSPColors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Elegant Inner Steps Container (VSP SurfaceAlt)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: VSPColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(color: VSPColors.borderLight),
                  ),
                  child: Column(
                    children: [
                      _buildStepRow(
                        title: widget.isArabic ? 'استلام تفويض السداد البنكي' : 'Bank payment authorized',
                        isDone: true,
                        isActive: false,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, color: VSPColors.borderLight),
                      ),
                      _buildStepRow(
                        title: widget.isArabic ? 'تثبيت وحجز الساعة بجدول الملعب' : 'Locking pitch slot in calendar',
                        isDone: false,
                        isActive: !_isProlongedWait,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, color: VSPColors.borderLight),
                      ),
                      _buildStepRow(
                        title: widget.isArabic ? 'إصدار تذكرة الحجز الرسمية' : 'Issuing official match pass',
                        isDone: false,
                        isActive: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // 4. Bottom Action / Progress
                if (_isProlongedWait) ...[
                  PrimaryButton(
                    text: widget.isArabic ? 'متابعة في قائمة حجوزاتي' : 'Go to My Bookings',
                    height: 50,
                    onPressed: widget.onGoToBookings,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: VSPColors.whatsApp.withValues(alpha: 0.08),
                        side: BorderSide(color: VSPColors.whatsApp.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.button)),
                      ),
                      icon: const Icon(Iconsax.message_copy, color: VSPColors.whatsApp, size: 18),
                      label: Text(
                        widget.isArabic ? 'مساعدة فورية عبر واتساب' : 'WhatsApp Instant Support',
                        style: const TextStyle(
                          color: VSPColors.whatsApp,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      onPressed: _contactSupport,
                    ),
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(VSPColors.accent),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.isArabic ? 'جاري التحقق الفوري مع البنك...' : 'Verifying transaction...',
                        style: const TextStyle(
                          fontSize: 13,
                          color: VSPColors.textSecondary,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow({
    required String title,
    required bool isDone,
    required bool isActive,
  }) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? VSPColors.accent.withValues(alpha: 0.18)
                : (isActive ? VSPColors.accent.withValues(alpha: 0.15) : VSPColors.surface),
            border: Border.all(
              color: isDone
                  ? VSPColors.accent
                  : (isActive ? VSPColors.accent : VSPColors.borderLight),
              width: 1.4,
            ),
          ),
          child: Center(
            child: isDone
                ? const Icon(Iconsax.tick_circle_copy, size: 14, color: VSPColors.accent)
                : (isActive
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.accent),
                      )
                    : const SizedBox.shrink()),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: (isDone || isActive) ? FontWeight.w600 : FontWeight.normal,
              color: isDone
                  ? VSPColors.textPrimary
                  : (isActive ? VSPColors.textPrimary : VSPColors.textMuted),
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }
}
