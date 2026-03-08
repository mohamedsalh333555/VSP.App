import '../../../core/ui/tokens/vsp_tokens.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/widgets/primary_button.dart';
import 'set_password_screen.dart';

/// شاشة تأكيد البريد الإلكتروني - الخطوة 2
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );
  bool _isLoading = false;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String _getCode() {
    return _controllers.map((c) => c.text).join();
  }

  Future<void> _handleVerify() async {
    // 1. Check for Bypass Flag
    if (AppConfig.bypassOtp) {
      if (mounted) {
         Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SetPasswordScreen(),
          ),
        );
      }
      return;
    }

    final code = _getCode();
    
    if (code.length != 6) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the complete code'),
          backgroundColor: VSPColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.setVerificationCode(code);

    // محاكاة التحقق من الرمز
    final success = await authProvider.verifyCode(code);

    setState(() => _isLoading = false);

    if (!mounted) return;
    if (success) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SetPasswordScreen(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid code'),
          backgroundColor: VSPColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              VSPColors.background,
              VSPColors.accent.withValues(alpha: 0.1),
              VSPColors.background,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Back Button
                IconButton(
                  icon: Icon(
                    languageProvider.isArabic
                        ? Icons.arrow_forward
                        : Icons.arrow_back,
                    color: VSPColors.textPrimary,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),

                const SizedBox(height: 40),

                // Title
                Text(
                  languageProvider.getText(AppStrings.verifyEmail),
                  style: Theme.of(context).textTheme.displayLarge,
                ),

                const SizedBox(height: 12),

                // Step Indicator
                Text(
                  '2/4',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: VSPColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                // Subtitle
                RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: VSPColors.textSecondary,
                    ),
                    children: [
                      TextSpan(
                        text: languageProvider.getText(AppStrings.verificationCodeSent),
                      ),
                      const TextSpan(text: '\n'),
                      TextSpan(
                        text: authProvider.email,
                        style: const TextStyle(
                          color: VSPColors.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // OTP Input
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    return _OTPBox(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 5) {
                          _focusNodes[index + 1].requestFocus();
                        } else if (value.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                      },
                    );
                  }),
                ),

                const SizedBox(height: 24),

                // Resend Code
                Center(
                  child: GestureDetector(
                    onTap: () {
                      // TODO: Resend code
                    },
                    child: Text(
                      languageProvider.getText(AppStrings.resendCode),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: VSPColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Verify Button
                PrimaryButton(
                  text: languageProvider.getText(AppStrings.verify),
                  onPressed: _isLoading 
                      ? null 
                      : () {
                          _handleVerify();
                        },
                  isLoading: _isLoading,
                ),

                const SizedBox(height: 40),

                // Bottom Indicator
                Center(
                  child: Container(
                    width: 134,
                    height: 5,
                    decoration: BoxDecoration(
                      color: VSPColors.divider,
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

/// صندوق إدخال رقم واحد من OTP
class _OTPBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String) onChanged;

  const _OTPBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 60,
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(
          color: VSPColors.divider,
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
        ),
        onChanged: onChanged,
      ),
    );
  }
}

