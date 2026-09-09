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

    // بعد 18 ثانية في حال تأخر رد بوابة الدفع، نتحول لحالة التطمين الإيجابي بدلاً من إظهار أخطاء مرعبة
    _delayTimer = Timer(const Duration(seconds: 18), () {
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
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.circular(VSPRadius.lg),
            border: Border.all(
              color: _isProlongedWait
                  ? const Color(0xFF38BDF8).withValues(alpha: 0.4)
                  : VSPColors.accent.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (_isProlongedWait ? const Color(0xFF38BDF8) : VSPColors.accent)
                    .withValues(alpha: 0.2),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (_isProlongedWait ? const Color(0xFF38BDF8) : VSPColors.accent)
                        .withValues(alpha: 0.15),
                    border: Border.all(
                      color: _isProlongedWait ? const Color(0xFF38BDF8) : VSPColors.accent,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _isProlongedWait ? Iconsax.clock_copy : Iconsax.shield_tick_copy,
                    color: _isProlongedWait ? const Color(0xFF38BDF8) : VSPColors.accent,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _isProlongedWait
                    ? (widget.isArabic ? 'طلبك قيد المعالجة والتأكيد ⏳' : 'Processing Confirmation ⏳')
                    : (widget.isArabic ? 'جاري تأكيد حجزك رسمياً 🛡️' : 'Securing Your Booking 🛡️'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: VSPColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _isProlongedWait
                    ? (widget.isArabic
                        ? 'إذا تم خصم المبلغ من حسابك، حجزك مضمون ومحمي 100%. جاري استكمال الربط البنكي.'
                        : 'If payment was deducted, your booking is 100% secured. Bank sync is completing.')
                    : (widget.isArabic
                        ? 'مبلغك في أمان تام ومحمي 100%. جاري تثبيت حجزك في جدول الملعب...'
                        : 'Your money is 100% secure. Locking your slot in stadium calendar...'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: VSPColors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              _buildStepRow(
                icon: Iconsax.card_tick_copy,
                title: widget.isArabic ? 'استلام تفويض السداد من البنك' : 'Bank authorization received',
                isDone: true,
                isActive: false,
              ),
              const SizedBox(height: 12),
              _buildStepRow(
                icon: Iconsax.calendar_tick_copy,
                title: widget.isArabic ? 'تثبيت وحجز الساعة بجدول الملعب' : 'Locking pitch slot in calendar',
                isDone: false,
                isActive: !_isProlongedWait,
              ),
              const SizedBox(height: 12),
              _buildStepRow(
                icon: Iconsax.ticket_copy,
                title: widget.isArabic ? 'إصدار تذكرة الحجز الرسمية' : 'Issuing official match pass',
                isDone: false,
                isActive: false,
              ),
              const SizedBox(height: 24),
              if (_isProlongedWait) ...[
                PrimaryButton(
                  text: widget.isArabic ? 'متابعة في قائمة حجوزاتي 📋' : 'Go to My Bookings 📋',
                  height: 48,
                  onPressed: widget.onGoToBookings,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF25D366)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                    ),
                    icon: const Icon(Iconsax.message_copy, color: Color(0xFF25D366), size: 18),
                    label: Text(
                      widget.isArabic ? 'مساعدة فورية عبر واتساب' : 'WhatsApp Instant Support',
                      style: const TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.bold),
                    ),
                    onPressed: _contactSupport,
                  ),
                ),
              ] else ...[
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(VSPColors.accent),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow({
    required IconData icon,
    required String title,
    required bool isDone,
    required bool isActive,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? VSPColors.success.withValues(alpha: 0.15)
                : (isActive ? VSPColors.accent.withValues(alpha: 0.15) : VSPColors.surfaceAlt),
            border: Border.all(
              color: isDone
                  ? VSPColors.success
                  : (isActive ? VSPColors.accent : Colors.white24),
              width: 1.5,
            ),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 16, color: VSPColors.success)
                : (isActive
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.accent),
                      )
                    : Icon(icon, size: 14, color: VSPColors.textSecondary)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: (isDone || isActive) ? FontWeight.w600 : FontWeight.normal,
              color: (isDone || isActive) ? VSPColors.textPrimary : VSPColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
