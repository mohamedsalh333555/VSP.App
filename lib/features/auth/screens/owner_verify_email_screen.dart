import '../../../core/ui/tokens/vsp_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import 'welcome_screen.dart';
import 'owner_set_password_screen.dart';

/// Owner Verify Email Screen - Step 2/3
class OwnerVerifyEmailScreen extends StatefulWidget {
  final String email;
  
  const OwnerVerifyEmailScreen({
    super.key,
    required this.email,
  });

  @override
  State<OwnerVerifyEmailScreen> createState() => _OwnerVerifyEmailScreenState();
}

class _OwnerVerifyEmailScreenState extends State<OwnerVerifyEmailScreen> {
  final List<TextEditingController> _controllers = List.generate(5, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(5, (index) => FocusNode());

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

  /// Aborts OTP — signs out the stale Firebase session and returns to Welcome.
  Future<void> _handleAbort(BuildContext ctx) async {
    final auth = Provider.of<AuthProvider>(ctx, listen: false);
    await auth.signOut();
    if (!ctx.mounted) return;
    Navigator.of(ctx).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  String _getCode() {
    return _controllers.map((c) => c.text).join();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleAbort(context);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
        backgroundColor: VSPColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                
                // Back Button
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: VSPColors.textPrimary),
                  onPressed: () => _handleAbort(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),

                const SizedBox(height: 40),

                // Title
                Center(
                  child: Text(
                    'Verify your email 2/3',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Progress Indicator
                _ProgressIndicator(currentStep: 2),

                const SizedBox(height: 32),

                // Instruction
                Center(
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: VSPColors.textSecondary,
                        height: 1.5,
                      ),
                      children: [
                        const TextSpan(text: 'We Just Sent 5-Digit Code To '),
                        TextSpan(
                          text: widget.email,
                          style: const TextStyle(
                            color: VSPColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const TextSpan(text: ', Enter It Bellow:'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Code Label
                Text(
                  'Code',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 12),

                // OTP Input
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(5, (index) {
                    return _OTPBox(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 4) {
                          _focusNodes[index + 1].requestFocus();
                        } else if (value.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                      },
                    );
                  }),
                ),

                const SizedBox(height: 32),

                // Create Account Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      final code = _getCode();
                      if (code.length == 5) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const OwnerSetPasswordScreen(),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VSPColors.accent,
                      foregroundColor: VSPColors.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Create New Account',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Wrong email link
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Wrong email? ',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: VSPColors.textSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _handleAbort(context),
                        child: Text(
                          'Send to different email',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: VSPColors.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Resend Code
                Center(
                  child: GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Code sent again!'),
                          backgroundColor: VSPColors.accent,
                        ),
                      );
                    },
                    child: Text(
                      'Send Code Again',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: VSPColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Bottom Indicator
                Center(
                  child: Container(
                    width: 134,
                    height: 5,
                    decoration: BoxDecoration(
                      color: VSPColors.divider,
                      borderRadius: BorderRadius.circular(VSPRadius.full),
                    ),
                  ),
                ),

                SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
              ],
            ),
          ),
        ),
      ),
    ),   // AnnotatedRegion
    );   // PopScope
  }
}

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
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
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

class _ProgressIndicator extends StatelessWidget {
  final int currentStep;

  const _ProgressIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStep(1),
        const SizedBox(width: 8),
        _buildStep(2),
        const SizedBox(width: 8),
        _buildStep(3),
      ],
    );
  }

  Widget _buildStep(int step) {
    final isActive = step <= currentStep;
    return Container(
      width: 60,
      height: 4,
      decoration: BoxDecoration(
        color: isActive ? VSPColors.accent : VSPColors.textSecondary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(VSPRadius.xs),
      ),
    );
  }
}

