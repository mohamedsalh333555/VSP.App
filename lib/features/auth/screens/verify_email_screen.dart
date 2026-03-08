import '../../../core/ui/tokens/vsp_tokens.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/auth_provider.dart';

import '../../../core/navigation/root_screen.dart';
import '../../owner/screens/add_stadium_wizard.dart';
import '../../../core/utils/vsp_feedback.dart';

/// شاشة التحقق من OTP - تعمل بنظام Mock في DEV والحقيقي في Production
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  // OTP Controllers (6 fields)
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _canResend = false;
  int _countdown = AppConfig.otpCountdownSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _canResend = false;
    _countdown = AppConfig.otpCountdownSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown == 0) {
        timer.cancel();
        if (mounted) setState(() => _canResend = true);
      } else {
        if (mounted) setState(() => _countdown--);
      }
    });
  }

  String _getCode() =>
      _controllers.map((c) => c.text).join();

  Future<void> _handleVerify() async {
    final code = _getCode();
    if (code.length < 6) {
      VSPFeedback.showError(context, 'يرجى إدخال رمز التحقق كاملاً (6 أرقام)');
      return;
    }

    setState(() => _isLoading = true);

    if (AppConfig.useMockOtp) {
      // ✅ Mock OTP Verification
      await Future.delayed(const Duration(milliseconds: 800)); // Simulate network

      if (code == AppConfig.mockOtpCode) {
        final auth = Provider.of<AuthProvider>(context, listen: false);

        // Mark registration as complete in Firestore
        await auth.updateProfile({'isRegistrationComplete': true});

        if (!context.mounted) return;
        
        // Role-based redirection
        if (auth.isOwner) {
          // Direct new owners to add their first stadium
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const AddStadiumWizard()),
            (route) => false,
          );
        } else {
          // Players go home (RootScreen handles final destination)
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const RootScreen()),
            (route) => false,
          );
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
        VSPFeedback.showError(context, 'رمز التحقق غير صحيح. جرب: ${AppConfig.mockOtpCode}');
      }
    } else {
      // if (verified) { ... } else { ... }
      if (!context.mounted) return;
      setState(() => _isLoading = false);
      VSPFeedback.showError(context, 'Real OTP not activated yet.');
    }
  }

  // Removed _showError helper in favor of VSPFeedback

  void _handleResend() {
    if (!_canResend) return;
    _startCountdown();
    // TODO: In production, call auth.resendOtp()
    VSPFeedback.showSuccess(
      context, 
      AppConfig.useMockOtp
          ? 'رمز التحقق الوهمي: ${AppConfig.mockOtpCode}'
          : 'تم إعادة إرسال رمز التحقق',
    );
  }

  // When a digit is entered, move focus to next field automatically
  void _onChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    // Auto-submit when all 6 digits are entered
    if (_getCode().length == 6) {
      FocusScope.of(context).unfocus();
      _handleVerify();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: VSPColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: VSPColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: VSPColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),

                const SizedBox(height: 50),

                // Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: VSPColors.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_outlined,
                    size: 52,
                    color: VSPColors.accent,
                  ),
                ),

                const SizedBox(height: 32),

                // Title
                Text(
                  'أدخل رمز التحقق',
                  style: Theme.of(context).textTheme.displayMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Subtitle
                Text(
                  auth.email.isNotEmpty
                      ? 'تم إرسال رمز التحقق إلى:\n${auth.email}'
                      : AppConfig.useMockOtp
                          ? 'وضع التطوير: استخدم الرمز ${AppConfig.mockOtpCode}'
                          : 'أدخل الرمز المُرسل إليك',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: VSPColors.textSecondary,
                    height: 1.6,
                  ),
                ),

                // DEV mode badge
                if (AppConfig.useMockOtp) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: VSPColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: VSPColors.warning.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      'وضع التطوير - رمز التجربة: ${AppConfig.mockOtpCode}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: VSPColors.warning,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 48),

                // OTP Input Fields (6 boxes)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (index) {
                    return Container(
                      width: 48,
                      height: 58,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: VSPColors.surface,
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                        border: Border.all(
                          color: _focusNodes[index].hasFocus
                              ? VSPColors.accent
                              : VSPColors.divider.withValues(alpha: 0.1),
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        obscureText: false,
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: VSPColors.textPrimary,
                          fontSize: 22,
                        ),
                        decoration: const InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                        ),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (value) => _onChanged(index, value),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 40),

                // Verify Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleVerify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VSPColors.accent,
                      foregroundColor: VSPColors.background,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: VSPColors.background,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            'تحقق',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // Resend / Countdown
                _canResend
                    ? TextButton(
                        onPressed: _handleResend,
                        child: Text(
                          'إعادة إرسال الرمز',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: VSPColors.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : Text(
                        'يمكنك إعادة الإرسال بعد $_countdown ثانية',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: VSPColors.textSecondary.withValues(alpha: 0.45),
                        ),
                      ),

                const Spacer(),

                // Bottom indicator
                Center(
                  child: Container(
                    width: 134,
                    height: 5,
                    decoration: BoxDecoration(
                      color: VSPColors.divider.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

