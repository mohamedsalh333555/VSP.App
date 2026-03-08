import '../../../core/ui/tokens/vsp_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'success_modal.dart';

/// Owner Set Password Screen - Step 3/3
class OwnerSetPasswordScreen extends StatefulWidget {
  const OwnerSetPasswordScreen({super.key});

  @override
  State<OwnerSetPasswordScreen> createState() => _OwnerSetPasswordScreenState();
}

class _OwnerSetPasswordScreenState extends State<OwnerSetPasswordScreen> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _hasMinLength = false;
  bool _hasNumber = false;
  bool _hasSymbol = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _validatePassword(String value) {
    setState(() {
      _hasMinLength = value.length >= 8;
      _hasNumber = value.contains(RegExp(r'[0-9]'));
      _hasSymbol = value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  bool get _isValid => _hasMinLength && _hasNumber && _hasSymbol;

  Future<void> _handleCreateAccount() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.setPassword(_passwordController.text.trim());

    setState(() => _isLoading = true);

    final success = await authProvider.createAccount();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      showSuccessModal(context, isOwner: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Account creation failed'),
          backgroundColor: VSPColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
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
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),

                const SizedBox(height: 40),

                // Title
                Center(
                  child: Text(
                    'Verify your email 3/3',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Progress Indicator
                _ProgressIndicator(currentStep: 3),

                const SizedBox(height: 40),

                // Password Label
                Text(
                  'Password',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 12),

                // Password Input
                Container(
                  decoration: BoxDecoration(
                    color: VSPColors.surface,
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                  ),
                  child: TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: Theme.of(context).textTheme.bodyMedium,
                    onChanged: _validatePassword,
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: VSPColors.textSecondary,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Password Requirements Checklist
                _RequirementItem(
                  text: '8 Characters',
                  isValid: _hasMinLength,
                ),
                const SizedBox(height: 12),
                _RequirementItem(
                  text: 'A Number',
                  isValid: _hasNumber,
                ),
                const SizedBox(height: 12),
                _RequirementItem(
                  text: 'A Symbol',
                  isValid: _hasSymbol,
                ),

                const Spacer(),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (_isValid && !_isLoading)
                        ? () {
                            _handleCreateAccount();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VSPColors.accent,
                      foregroundColor: VSPColors.background,
                      disabledBackgroundColor: VSPColors.textSecondary.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(VSPColors.background),
                            ),
                          )
                        : Text(
                            'Continue',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
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

class _RequirementItem extends StatelessWidget {
  final String text;
  final bool isValid;

  const _RequirementItem({
    required this.text,
    required this.isValid,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isValid ? VSPColors.accent : Colors.transparent,
            border: Border.all(
              color: isValid ? VSPColors.accent : VSPColors.textSecondary.withValues(alpha: 0.3),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(VSPRadius.xs),
          ),
          child: isValid
              ? const Icon(
                  Icons.check,
                  color: VSPColors.background,
                  size: 16,
                )
              : null,
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isValid ? VSPColors.textPrimary : VSPColors.textSecondary.withValues(alpha: 0.6),
            fontWeight: isValid ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
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

