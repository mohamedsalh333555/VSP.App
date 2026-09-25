import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Modal dialog/sheet to re-authenticate sensitive payout changes with the real account password.
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

class _OwnerPayoutOtpDialogState extends State<OwnerPayoutOtpDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isVerifying = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _verifyPassword() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال كلمة مرور الحساب');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final verified = await auth.reauthenticateWithPassword(password);

    if (!mounted) return;
    if (verified) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isVerifying = false;
        _errorMessage = 'كلمة المرور غير صحيحة. لم يتم حفظ أي تعديل مالي.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final email = Provider.of<AuthProvider>(context, listen: false).currentUser?.email ?? '';

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
        color: VSPColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
        border: Border(top: BorderSide(color: VSPColors.divider, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: VSPColors.divider, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: VSPColors.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
            ),
            child: const Icon(Iconsax.lock_copy, color: VSPColors.accent, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            isArabic ? 'تأكيد أمان البيانات المالية' : 'Verify Financial Security',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: VSPColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
                ? 'لتغيير وسيلة استلام المستحقات، أدخل كلمة مرور حسابك. هذا يمنع أي تعديل مالي من جهاز غير مصرح به.'
                : 'To change payout details, enter your account password. This prevents unauthorized financial changes.',
            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(email, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11)),
          ],
          const SizedBox(height: 18),
          TextField(
            controller: _passwordController,
            obscureText: true,
            enabled: !_isVerifying,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _verifyPassword(),
            decoration: InputDecoration(
              labelText: isArabic ? 'كلمة مرور الحساب' : 'Account password',
              prefixIcon: const Icon(Iconsax.lock_1_copy, color: VSPColors.textSecondary),
              filled: true,
              fillColor: VSPColors.surface,
              errorText: _errorMessage,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(VSPRadius.md), borderSide: const BorderSide(color: VSPColors.divider)),
            ),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            text: isArabic ? 'تحقق واحفظ' : 'Verify & Save',
            isLoading: _isVerifying,
            onPressed: _isVerifying ? null : _verifyPassword,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isVerifying ? null : () => Navigator.of(context).pop(false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: VSPColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
