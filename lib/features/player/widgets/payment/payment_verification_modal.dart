import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_launcher_utils.dart';
import '../../../../shared/widgets/primary_button.dart';

/// شاشة طمأنة وتأكيد الدفع الحركية - تقضي على قلق الانتظار وتوفر طمأنة نفسية فورية للاعب
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

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
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
    return PopScope(
      canPop: false,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
          decoration: BoxDecoration(
            color: const Color(0xFF14171E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 32,
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
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (_isProlongedWait ? const Color(0xFF38BDF8) : VSPColors.accent)
                        .withValues(alpha: 0.1),
                    border: Border.all(
                      color: (_isProlongedWait ? const Color(0xFF38BDF8) : VSPColors.accent)
                          .withValues(alpha: 0.28),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      _isProlongedWait ? Iconsax.clock_copy : Iconsax.security_safe_copy,
                      color: _isProlongedWait ? const Color(0xFF38BDF8) : VSPColors.accent,
                      size: 28,
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
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isProlongedWait
                    ? (widget.isArabic
                        ? 'إذا تم خصم المبلغ من حسابك، حجزك مضمون ومحمي. جاري استكمال التأكيد البنكي.'
                        : 'If payment was deducted, your booking is safe. Bank sync is completing.')
                    : (widget.isArabic
                        ? 'لحظات ويتم قفل الساعة بجدول الملعب وإصدار تذكرتك فورياً...'
                        : 'Locking your slot in the stadium calendar and issuing your ticket...'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: VSPColors.textSecondary,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),

              // 3. Elegant Inner Steps Container
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  children: [
                    _buildStepRow(
                      title: widget.isArabic ? 'استلام تفويض السداد البنكي' : 'Bank payment authorized',
                      isDone: true,
                      isActive: false,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    _buildStepRow(
                      title: widget.isArabic ? 'تثبيت وحجز الساعة بجدول الملعب' : 'Locking pitch slot in calendar',
                      isDone: false,
                      isActive: !_isProlongedWait,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    _buildStepRow(
                      title: widget.isArabic ? 'إصدار تذكرة الحجز الرسمية' : 'Issuing official match pass',
                      isDone: false,
                      isActive: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 4. Bottom Action / Progress
              if (_isProlongedWait) ...[
                PrimaryButton(
                  text: widget.isArabic ? 'متابعة في قائمة حجوزاتي' : 'Go to My Bookings',
                  height: 46,
                  onPressed: widget.onGoToBookings,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.02),
                      side: BorderSide(color: const Color(0xFF25D366).withValues(alpha: 0.6)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                    ),
                    icon: const Icon(Iconsax.message_copy, color: Color(0xFF25D366), size: 17),
                    label: Text(
                      widget.isArabic ? 'مساعدة فورية عبر واتساب' : 'WhatsApp Instant Support',
                      style: const TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: _contactSupport,
                  ),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(VSPColors.accent),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.isArabic ? 'جاري التحقق الفوري مع البنك...' : 'Verifying transaction...',
                      style: TextStyle(
                        fontSize: 12,
                        color: VSPColors.textSecondary.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
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
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                : (isActive ? VSPColors.accent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04)),
            border: Border.all(
              color: isDone
                  ? const Color(0xFF10B981)
                  : (isActive ? VSPColors.accent : Colors.white.withValues(alpha: 0.12)),
              width: 1.2,
            ),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 13, color: Color(0xFF10B981))
                : (isActive
                    ? const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.8, color: VSPColors.accent),
                      )
                    : const SizedBox.shrink()),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: (isDone || isActive) ? FontWeight.w600 : FontWeight.normal,
              color: isDone
                  ? VSPColors.textPrimary
                  : (isActive ? VSPColors.textPrimary : VSPColors.textSecondary.withValues(alpha: 0.6)),
            ),
          ),
        ),
      ],
    );
  }
}
