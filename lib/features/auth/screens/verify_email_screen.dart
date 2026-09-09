import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/services/secure_storage_service.dart';
import '../widgets/verify_email/otp_box.dart';
import '../widgets/verify_email/otp_resend_section.dart';
import '../widgets/verify_email/verify_email_header.dart';

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

  Future<void> _loadEmailFromPrefs() async {
    final savedEmail = await SecureStorageService.readSecure('pending_verification_email');
    if (!mounted) return;
    if (savedEmail != null && savedEmail.isNotEmpty) {
      setState(() {
        _resolvedEmail = savedEmail;
      });
    }
  }

  // ── Verify OTP ─────────────────────────────────────────────────────────────

  String get _enteredCode => _controllers.map((c) => c.text.trim()).join();

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
      await SecureStorageService.deleteSecure('pending_verification_email');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_verification_email');
    } else {
      HapticFeedback.vibrate();
      _shakeController.forward(from: 0);
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      setState(() {
        _errorMessage = auth.errorMessage ??
            (isAr
                ? 'رمز التفعيل خاطئ أو انتهت صلاحيته. يرجى المحاولة مجدداً'
                : 'Invalid or expired code. Please try again.');
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
          content: Text(isAr
              ? ' تم إرسال رمز تفعيل جديد إلى بريدك الإلكتروني.'
              : ' A new code has been sent to your email.'),
          backgroundColor: VSPColors.accent,
        ),
      );
    } else {
      setState(() => _errorMessage = isAr
          ? 'فشل إعادة إرسال الرمز. يرجى المحاولة لاحقاً.'
          : 'Failed to resend OTP. Try again.');
    }
  }

  // ── OTP Input helper ───────────────────────────────────────────────────────

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
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

                // ── Header (Icon, Title, Subtitle, Masked Email) ───────────
                VerifyEmailHeader(
                  email: _resolvedEmail,
                  isAr: isAr,
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
                    onPressed: (_enteredCode.length == 6 && !_isVerifying)
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

                // ── Resend row & Change email ──────────────────────────────
                OtpResendSection(
                  countdown: _countdown,
                  isResending: _isResending,
                  isAr: isAr,
                  onResend: _resend,
                  onChangeEmail: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('pending_verification_email');
                    if (context.mounted) {
                      await Provider.of<AuthProvider>(context, listen: false).signOut();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
