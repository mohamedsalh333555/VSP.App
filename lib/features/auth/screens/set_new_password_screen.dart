import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/custom_text_field.dart';

/// Screen shown when the user clicks a password-reset deep link.
/// Supabase has already established the recovery session before this screen
/// opens. The user enters (and confirms) their new password here.
class SetNewPasswordScreen extends StatefulWidget {
  const SetNewPasswordScreen({super.key});

  @override
  State<SetNewPasswordScreen> createState() => _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends State<SetNewPasswordScreen> {
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _showNew = false;
  bool _showConfirm = false;
  String? _errorMessage;
  String? _successMessage;

  // ── Password Strength ──────────────────────────────────────────────────────

  double get _strength {
    final p = _newPassController.text;
    if (p.isEmpty) return 0;
    double s = 0;
    if (p.length >= 8) s += 0.25;
    if (p.length >= 12) s += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(p)) s += 0.25;
    if (RegExp(r'[0-9!@#\$%^&*]').hasMatch(p)) s += 0.25;
    return s;
  }

  Color get _strengthColor {
    if (_strength <= 0.25) return Colors.redAccent;
    if (_strength <= 0.5) return Colors.orange;
    if (_strength <= 0.75) return Colors.yellow;
    return VSPColors.accent;
  }

  String _getStrengthLabel(bool isAr) {
    if (_strength <= 0.25) return isAr ? 'ضعيفة' : 'Weak';
    if (_strength <= 0.5) return isAr ? 'متوسطة' : 'Fair';
    if (_strength <= 0.75) return isAr ? 'جيدة' : 'Good';
    return isAr ? 'قوية' : 'Strong';
  }

  // ── Save Password ──────────────────────────────────────────────────────────

  Future<void> _save(bool isAr) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newPassController.text.trim()),
      );

      if (!mounted) return;
      setState(() {
        _successMessage = isAr ? '✅ تم تحديث كلمة المرور بنجاح!' : '✅ Password updated successfully!';
        _isLoading = false;
      });

      // Small delay then let GoRouter redirect (auth state refreshes)
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      // Sign out and back in to refresh session cleanly
      await Provider.of<AuthProvider>(context, listen: false).signOut();
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = isAr ? 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.' : 'An unexpected error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          isAr ? 'تعيين كلمة مرور جديدة' : 'Set New Password',
          style: const TextStyle(
            color: VSPColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(VSPSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: VSPSpacing.md),

                // ── Lock Icon ──────────────────────────────────────────────
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: VSPColors.accent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: VSPColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Iconsax.lock_1_copy,
                      color: VSPColors.accent,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: VSPSpacing.xl),

                Text(
                  isAr ? 'إنشاء كلمة مرور قوية' : 'Create a strong password',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: VSPSpacing.sm),
                Text(
                  isAr ? 'يجب أن لا تقل كلمة المرور الجديدة عن 8 أحرف أو أرقام.' : 'Your new password must be at least 8 characters long.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: VSPColors.textSecondary,
                        height: 1.5,
                      ),
                ),

                const SizedBox(height: VSPSpacing.xl),

                // ── New Password ───────────────────────────────────────────
                _buildLabel(context, isAr ? 'كلمة المرور الجديدة' : 'New Password'),
                _PasswordField(
                  controller: _newPassController,
                  hint: isAr ? 'أدخل كلمة المرور الجديدة' : 'Enter new password',
                  obscure: !_showNew,
                  textInputAction: TextInputAction.next,
                  onToggle: () => setState(() => _showNew = !_showNew),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.isEmpty) return isAr ? 'مطلوب' : 'Required';
                    if (v.length < 8) return isAr ? '8 أحرف على الأقل' : 'At least 8 characters';
                    return null;
                  },
                ),

                // ── Strength Meter ─────────────────────────────────────────
                if (_newPassController.text.isNotEmpty) ...[
                  const SizedBox(height: VSPSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _strength,
                            minHeight: 6,
                            backgroundColor:
                                VSPColors.divider.withValues(alpha: 0.3),
                            valueColor: AlwaysStoppedAnimation(_strengthColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _getStrengthLabel(isAr),
                        style: TextStyle(
                          color: _strengthColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: VSPSpacing.lg),

                // ── Confirm Password ───────────────────────────────────────
                _buildLabel(context, isAr ? 'تأكيد كلمة المرور' : 'Confirm New Password'),
                _PasswordField(
                  controller: _confirmPassController,
                  hint: isAr ? 'أعد كتابة كلمة المرور' : 'Repeat your password',
                  obscure: !_showConfirm,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (!_isLoading) _save(isAr);
                  },
                  onToggle: () => setState(() => _showConfirm = !_showConfirm),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v != _newPassController.text) {
                      return isAr ? 'كلمتا المرور غير متطابقتين' : 'Passwords do not match';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: VSPSpacing.xl),

                // ── Error / Success ────────────────────────────────────────
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(VSPSpacing.md),
                    decoration: BoxDecoration(
                      color: VSPColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      border: Border.all(
                          color: VSPColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                          color: VSPColors.error, fontSize: 13),
                    ),
                  ),
                if (_successMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(VSPSpacing.md),
                    decoration: BoxDecoration(
                      color: VSPColors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      border: Border.all(
                          color: VSPColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _successMessage!,
                      style: const TextStyle(
                          color: VSPColors.accent, fontSize: 13),
                    ),
                  ),

                const SizedBox(height: VSPSpacing.lg),

                // ── Save Button ────────────────────────────────────────────
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
                    onPressed: _isLoading ? null : () => _save(isAr),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            isAr ? 'حفظ كلمة المرور الجديدة' : 'Save New Password',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
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

  Widget _buildLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Password field widget
// ─────────────────────────────────────────────────────────────────────────────
class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final VoidCallback onToggle;
  final ValueChanged<String> onChanged;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  const _PasswordField({
    required this.controller,
    required this.hint,
    required this.obscure,
    required this.onToggle,
    required this.onChanged,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: controller,
      obscureText: obscure,
      onChanged: onChanged,
      validator: validator,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      hintText: hint,
      prefixIcon: Iconsax.lock_copy,
      suffixIcon: IconButton(
        icon: Icon(
          obscure ? Iconsax.eye_slash_copy : Iconsax.eye_copy,
          color: VSPColors.textSecondary,
          size: 20,
        ),
        onPressed: onToggle,
      ),
    );
  }
}
