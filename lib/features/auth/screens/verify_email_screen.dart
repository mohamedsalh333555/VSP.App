import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/services/secure_storage_service.dart';

/// Screen shown after email signup (when bypassOtp == false).
/// Allows the user to enter their 6-digit OTP, resend it (with a 60-second
/// cooldown), and automatically routes them to the dashboard on success.
class VerifyEmailScreen extends StatefulWidget {
  final String? email;

  const VerifyEmailScreen({super.key, this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with SingleTickerProviderStateMixin {
  // ── OTP controllers (one per digit) ───────────────────────────────────────
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  // ── State ──────────────────────────────────────────────────────────────────
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;
  String? _resolvedEmail;

  // ── Countdown for resend ───────────────────────────────────────────────────
  int _countdown = 60;
  Timer? _timer;

  // ── Animation ─────────────────────────────────────────────────────────────
  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _resolvedEmail = widget.email;
    if (_resolvedEmail == null || _resolvedEmail!.isEmpty) {
      _loadEmailFromPrefs();
    }
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

  // ── Countdown ──────────────────────────────────────────────────────────────

  void _startCountdown() {
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          t.cancel();
        }
      });
    });
  }

  Future<void> _loadEmailFromPrefs() async {
    final savedEmail = await SecureStorageService.readSecure('pending_verification_email');
    if (savedEmail != null && savedEmail.isNotEmpty) {
      setState(() {
        _resolvedEmail = savedEmail;
      });
    }
  }

  // ── Verify OTP ─────────────────────────────────────────────────────────────

  String get _enteredCode =>
      _controllers.map((c) => c.text.trim()).join();

  Future<void> _verify() async {
    final code = _enteredCode;
    if (code.length < 6) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.verifyOtp(
      email: _resolvedEmail ?? '',
      token: code,
    );

    if (!mounted) return;

    if (success) {
      HapticFeedback.lightImpact();
      // Clear pending verification email from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_verification_email');
      // GoRouter will redirect automatically via authStateChanges
    } else {
      HapticFeedback.vibrate();
      _shakeController.forward(from: 0);
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      setState(() {
        _errorMessage = auth.errorMessage ??
            (isAr ? 'رمز التفعيل خاطئ أو انتهت صلاحيته. يرجى المحاولة مجدداً' : 'Invalid or expired code. Please try again.');
        _isVerifying = false;
      });
    }
  }

  // ── Resend OTP ─────────────────────────────────────────────────────────────

  Future<void> _resend() async {
    if (_countdown > 0 || _isResending) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.resendOtp();

    if (!mounted) return;
    setState(() => _isResending = false);

    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    if (success) {
      _startCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAr ? '✅ تم إرسال رمز تفعيل جديد إلى بريدك الإلكتروني.' : '✅ A new code has been sent to your email.'),
          backgroundColor: VSPColors.accent,
        ),
      );
    } else {
      setState(() => _errorMessage = isAr ? 'فشل إعادة إرسال الرمز. يرجى المحاولة لاحقاً.' : 'Failed to resend OTP. Try again.');
    }
  }

  // ── OTP Input helper ───────────────────────────────────────────────────────

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // Handle paste: distribute digits across all boxes
      final digits = value.replaceAll(RegExp(r'\D'), '').split('');
      for (int i = 0; i < 6 && i < digits.length; i++) {
        _controllers[i].text = digits[i];
      }
      _focusNodes[5].requestFocus();
      setState(() {});
      if (_enteredCode.length == 6) _verify();
      return;
    }

    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() {});
    if (_enteredCode.length == 6) _verify();
  }

  void _onKeyDown(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final displayEmail = _resolvedEmail ?? '';
    final maskedEmail = displayEmail.isNotEmpty ? _maskEmail(displayEmail) : '';
    final canResend = _countdown == 0 && !_isResending;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: VSPColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(VSPSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // ── Icon ───────────────────────────────────────────────────
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: VSPColors.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: VSPColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(
                    Iconsax.sms_copy,
                    color: VSPColors.accent,
                    size: 36,
                  ),
                ),

                const SizedBox(height: VSPSpacing.xl),

                // ── Title ──────────────────────────────────────────────────
                Text(
                  isAr ? 'تأكيد البريد الإلكتروني' : 'Verify Your Email',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: VSPSpacing.sm),
                Text(
                  isAr ? 'أرسلنا رمز تفعيل مكون من 6 أرقام إلى' : 'We sent a 6-digit code to',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: VSPColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  maskedEmail,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: VSPColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                ),

                const SizedBox(height: VSPSpacing.xxl),

                // ── OTP boxes ─────────────────────────────────────────────
                AnimatedBuilder(
                  animation: _shakeAnim,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(_shakeAnim.value, 0),
                    child: child,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (i) => _OtpBox(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      hasError: _errorMessage != null,
                      onChanged: (v) => _onDigitChanged(i, v),
                      onKey: (e) => _onKeyDown(i, e),
                    )),
                  ),
                ),

                // ── Error ─────────────────────────────────────────────────
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: _errorMessage != null
                      ? Padding(
                          padding: const EdgeInsets.only(top: VSPSpacing.md),
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: VSPColors.error,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

                const SizedBox(height: VSPSpacing.xl),

                // ── Verify Button ─────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VSPColors.accent,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor:
                          VSPColors.accent.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                      ),
                      elevation: 0,
                    ),
                    onPressed:
                        (_enteredCode.length == 6 && !_isVerifying)
                            ? _verify
                            : null,
                    child: _isVerifying
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            isAr ? 'تأكيد الرمز' : 'Verify Code',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: VSPSpacing.lg),

                // ── Resend row ────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isAr ? 'لم يصلك الرمز؟ ' : "Didn't receive it? ",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: VSPColors.textSecondary,
                          ),
                    ),
                    GestureDetector(
                      onTap: canResend ? _resend : null,
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          color: canResend
                              ? VSPColors.accent
                              : VSPColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        child: Text(
                          canResend
                              ? (isAr ? 'إعادة إرسال الرمز' : 'Resend Code')
                              : (isAr ? 'إعادة إرسال خلال $_countdown ثانية' : 'Resend in ${_countdown}s'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('pending_verification_email');
                    if (context.mounted) {
                      await Provider.of<AuthProvider>(context, listen: false).signOut();
                    }
                  },
                  child: const Text(
                    'أدخلت البريد بالخطأ؟ تغيير البريد وتسجيل الخروج',
                    style: TextStyle(
                      color: VSPColors.error,
                      decoration: TextDecoration.underline,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final local = parts[0];
    final domain = parts[1];
    if (local.length <= 2) return '${'*' * local.length}@$domain';
    return '${local[0]}${'*' * (local.length - 2)}${local[local.length - 1]}@$domain';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single OTP digit box
// ─────────────────────────────────────────────────────────────────────────────
class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final void Function(KeyEvent) onKey;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.onChanged,
    required this.onKey,
  });

  @override
  Widget build(BuildContext context) {
    final isFilled = controller.text.isNotEmpty;
    return Container(
      width: 46,
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(
          color: hasError
              ? VSPColors.error
              : (isFilled ? VSPColors.accent : VSPColors.divider),
          width: isFilled || hasError ? 2 : 1,
        ),
        boxShadow: isFilled
            ? [
                BoxShadow(
                  color: VSPColors.accent.withValues(alpha: 0.15),
                  blurRadius: 8,
                )
              ]
            : [],
      ),
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: onKey,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          maxLength: 6, // allow paste of full code
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: VSPColors.textPrimary,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            counterText: '',
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}



