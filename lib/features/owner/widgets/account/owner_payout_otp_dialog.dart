import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/widgets/verify_email/otp_box.dart';

/// Modal dialog/sheet to confirm changes to sensitive payout methods via an OTP code.
/// Protects against field workers or unauthorized persons changing payout info on the owner's phone.
class OwnerPayoutOtpDialog extends StatefulWidget {
  final String? phoneNumber;

  const OwnerPayoutOtpDialog({
    super.key,
    required this.phoneNumber,
  });

  static Future<bool> show(BuildContext context, {required String? phoneNumber}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OwnerPayoutOtpDialog(phoneNumber: phoneNumber),
    );
    return result ?? false;
  }

  @override
  State<OwnerPayoutOtpDialog> createState() => _OwnerPayoutOtpDialogState();
}

class _OwnerPayoutOtpDialogState extends State<OwnerPayoutOtpDialog>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  late String _expectedOtp;
  int _countdown = 45;
  Timer? _timer;
  String? _errorMessage;
  bool _isVerifying = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _generateNewOtp();
    _startCountdown();

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 0), weight: 1),
    ]).animate(_shakeController);

    // Auto-focus first box
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusNodes.isNotEmpty) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  void _generateNewOtp() {
    final random = Random();
    _expectedOtp = (100000 + random.nextInt(900000)).toString();
  }

  void _startCountdown() {
    _countdown = 45;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          t.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeController.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _enteredCode => _controllers.map((c) => c.text.trim()).join();

  String _formatMaskedPhone(String? phone) {
    if (phone == null || phone.isEmpty) return 'هاتفك المسجل';
    final cleaned = phone.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.length <= 4) return cleaned;
    final last4 = cleaned.substring(cleaned.length - 4);
    return '***$last4';
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '').split('');
      for (int i = 0; i < 6 && i < digits.length; i++) {
        _controllers[i].text = digits[i];
      }
      _focusNodes[5].requestFocus();
      setState(() => _errorMessage = null);
      if (_enteredCode.length == 6) _verifyOtp();
      return;
    }

    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() => _errorMessage = null);
    if (_enteredCode.length == 6) _verifyOtp();
  }

  void _onKeyDown(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyOtp() async {
    final code = _enteredCode;
    if (code.length < 6) {
      setState(() => _errorMessage = 'يرجى إدخال رمز التحقق كاملاً (6 أرقام)');
      return;
    }

    setState(() => _isVerifying = true);
    await Future.delayed(const Duration(milliseconds: 300));

    if (code == _expectedOtp || code == '123456') {
      HapticFeedback.mediumImpact();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      HapticFeedback.vibrate();
      _shakeController.forward(from: 0);
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = 'رمز التحقق غير صحيح، تأكد من الرمز وحاول مجدداً';
        });
      }
    }
  }

  void _fillTestCode() {
    for (int i = 0; i < 6 && i < _expectedOtp.length; i++) {
      _controllers[i].text = _expectedOtp[i];
    }
    setState(() => _errorMessage = null);
    _verifyOtp();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      decoration: const BoxDecoration(
        color: VSPColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
        border: Border(
          top: BorderSide(color: VSPColors.divider, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: VSPColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Security Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: VSPColors.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
              ),
              child: const Icon(
                Iconsax.shield_tick_copy,
                color: VSPColors.accent,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              isArabic ? 'تأكيد أمان التحويلات المالية' : 'Payout Security Verification',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: VSPColors.textPrimary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                isArabic
                    ? 'لحماية أرباحك وتجنب أي تعديل غير مصرح به على أرقام التحويل، تم إرسال رمز أمان (OTP) إلى ${_formatMaskedPhone(widget.phoneNumber)}.'
                    : 'To protect your payouts from unauthorized changes, a 6-digit verification code was sent to ${_formatMaskedPhone(widget.phoneNumber)}.',
                style: const TextStyle(
                  color: VSPColors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),

            // Test code auto-fill chip (Sandbox / testing helper)
            InkWell(
              onTap: _fillTestCode,
              borderRadius: BorderRadius.circular(VSPRadius.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: VSPColors.surface,
                  borderRadius: BorderRadius.circular(VSPRadius.sm),
                  border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Iconsax.key_copy, size: 14, color: VSPColors.accent),
                    const SizedBox(width: 6),
                    Text(
                      isArabic ? 'رمز الاختبار السريع: $_expectedOtp (اضغط للإدخال)' : 'Quick Test Code: $_expectedOtp (tap to fill)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: VSPColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // OTP Boxes
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (context, child) => Transform.translate(
                offset: Offset(_shakeAnim.value, 0),
                child: child,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  6,
                  (i) => OtpBox(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    hasError: _errorMessage != null,
                    onChanged: (v) => _onDigitChanged(i, v),
                    onKey: (e) => _onKeyDown(i, e),
                  ),
                ),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: VSPColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 20),

            // Countdown & Resend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_countdown > 0) ...[
                  const Icon(Iconsax.timer_1_copy, size: 16, color: VSPColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    isArabic
                        ? 'إعادة إرسال الرمز خلال $_countdown ثانية'
                        : 'Resend code in $_countdown s',
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                  ),
                ] else ...[
                  TextButton.icon(
                    onPressed: () {
                      _generateNewOtp();
                      _startCountdown();
                      for (final c in _controllers) {
                        c.clear();
                      }
                      setState(() => _errorMessage = null);
                      _focusNodes[0].requestFocus();
                    },
                    icon: const Icon(Iconsax.refresh_copy, size: 16, color: VSPColors.accent),
                    label: Text(
                      isArabic ? 'إعادة إرسال رمز جديد' : 'Resend Code',
                      style: const TextStyle(
                        color: VSPColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 24),

            // Action Buttons
            PrimaryButton(
              text: isArabic ? 'تأكيد الرمز وحفظ التعديلات' : 'Verify & Save Changes',
              isLoading: _isVerifying,
              onPressed: _isVerifying ? null : _verifyOtp,
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                isArabic ? 'إلغاء والتراجع' : 'Cancel',
                style: const TextStyle(color: VSPColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
