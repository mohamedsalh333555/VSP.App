import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/auth_provider.dart';

import '../../../core/navigation/root_screen.dart';
import 'welcome_screen.dart';
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
      if (!mounted) return;

      if (code == AppConfig.mockOtpCode) {
        final auth = Provider.of<AuthProvider>(context, listen: false);

        // Mark registration as complete in Firestore
        await auth.updateProfile({'isRegistrationComplete': true});
        if (!mounted) return;
        
        // Role-based redirection
        if (auth.isOwner) {
          // Redirect to RootScreen which will decide the correct onboarding step
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const RootScreen()),
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
        setState(() => _isLoading = false);
        VSPFeedback.showError(context, 'رمز التحقق غير صحيح. جرب: ${AppConfig.mockOtpCode}');
      }
    } else {
      // NOTE: Real OTP is not activated for the current MVP release.
      // The app must be compiled with useMockOtp = true or this path will fail.
      await Future.delayed(const Duration(milliseconds: 800)); // Simulate network
      if (!mounted) return;
      setState(() => _isLoading = false);
      VSPFeedback.showError(context, 'Real OTP not activated yet.');
    }
  }

  // Removed _showError helper in favor of VSPFeedback

  /// Aborts OTP — signs out the stale Firebase session and returns to Welcome.
  /// Called by both the back button and hardware back gesture.
  Future<void> _handleAbort(BuildContext ctx) async {
    final auth = Provider.of<AuthProvider>(ctx, listen: false);
    await auth.signOut();
    if (!ctx.mounted) return;
    Navigator.of(ctx).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

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

    return PopScope(
      // Intercept hardware back — sign out instead of popping into dead state
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleAbort(context);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: VSPColors.background,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
        child: Scaffold(
        backgroundColor: VSPColors.background,
        body: Stack(
          children: [
            // 1. Background Glow
            Positioned(
              top: -100,
              right: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: VSPColors.accent.withValues(alpha: 0.05),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),

            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 12),
                    
                    // Header Nav
                    Row(
                      children: [
                        _buildNavCircle(
                          context, 
                          icon: Icons.arrow_back,
                          onTap: () => _handleAbort(context),
                        ),
                        const Spacer(),
                        Image.asset(
                          'assets/images/logo.png',
                          height: 24,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),

                    const SizedBox(height: 60),

                    // Verify Animation/Icon Header
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: VSPColors.accent.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.1)),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.verified_user_rounded,
                          size: 56,
                          color: VSPColors.accent,
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    Text(
                      'VERIFY ACCOUNT',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 42,
                        height: 0.9,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        auth.email.isNotEmpty
                            ? 'A 6-digit code was sent to \n${auth.email}'
                            : 'Enter the verification code sent to your device',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: VSPColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 60),

                    // OTP Boxes Container
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (index) {
                        return Container(
                          width: 45,
                          height: 60,
                          decoration: BoxDecoration(
                            color: VSPColors.surface,
                            borderRadius: BorderRadius.circular(VSPRadius.lg),
                            border: Border.all(
                              color: _focusNodes[index].hasFocus
                                  ? VSPColors.accent
                                  : Colors.white.withValues(alpha: 0.05),
                              width: 2,
                            ),
                          ),
                          child: TextField(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            maxLength: 1,
                            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              color: VSPColors.textPrimary,
                            ),
                            decoration: const InputDecoration(
                              counterText: '',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            onChanged: (value) => _onChanged(index, value),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 48),

                    // Verification Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleVerify,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VSPColors.accent,
                          foregroundColor: VSPColors.background,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(VSPRadius.lg),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: VSPColors.background,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                'CONTINUE',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Resend Action
                    _canResend
                        ? TextButton(
                            onPressed: _handleResend,
                            child: Text(
                              'RESEND CODE',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: VSPColors.accent,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                                letterSpacing: 1.2,
                              ),
                            ),
                          )
                        : Text(
                            'RESEND IN $_countdown SECONDS',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: VSPColors.textSecondary.withValues(alpha: 0.4),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildNavCircle(BuildContext context, {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: VSPColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Icon(icon, color: VSPColors.textPrimary, size: 20),
      ),
    );
  }
}

