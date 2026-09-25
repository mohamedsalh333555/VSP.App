import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/screens/welcome_screen.dart';

class OwnerDeleteAccountCard extends StatelessWidget {
  const OwnerDeleteAccountCard({super.key});

  void _showDeleteAccountDialog(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    bool isDeleting = false;
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: VSPColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
            title: Text(
              isArabic ? 'حذف حساب المالك نهائياً؟ ' : 'Delete Account?',
              style: const TextStyle(color: VSPColors.error, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic
                      ? 'هذا الإجراء نهائي. يجب أن تكون الحجوزات والتسويات المعلقة منتهية أولاً، ولن يتم حذف أي جزء من الحساب إذا تعذر الإتمام بأمان.'
                      : 'This action is permanent. Active bookings and pending settlements must be clear first. No partial deletion will occur if secure deletion cannot complete.',
                  style: const TextStyle(color: VSPColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 16),
                Text(
                  isArabic ? 'أدخل كلمة مرور الحساب للتأكيد' : 'Enter your account password to confirm',
                  style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  enabled: !isDeleting,
                  autofocus: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Iconsax.lock_1_copy, color: VSPColors.textSecondary),
                    hintText: isArabic ? 'كلمة مرور الحساب' : 'Account password',
                    filled: true,
                    fillColor: VSPColors.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      borderSide: const BorderSide(color: VSPColors.divider),
                    ),
                  ),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      text: isArabic ? 'إلغاء' : 'Cancel',
                      height: 48,
                      color: VSPColors.surfaceAlt,
                      textColor: VSPColors.textPrimary,
                      onPressed: isDeleting ? null : () => Navigator.pop(dialogCtx),
                    ),
                  ),
                  const SizedBox(width: VSPSpacing.md),
                  Expanded(
                    child: PrimaryButton(
                      text: isArabic ? 'حذف' : 'Delete',
                      height: 48,
                      color: VSPColors.error,
                      textColor: VSPColors.background,
                      isLoading: isDeleting,
                      onPressed: isDeleting
                          ? null
                          : () async {
                              if (passwordController.text.isEmpty) {
                                VSPFeedback.showWarning(
                                  dialogCtx,
                                  isArabic ? 'أدخل كلمة مرور الحساب أولاً.' : 'Enter your account password first.',
                                );
                                return;
                              }

                              setDialogState(() => isDeleting = true);
                              final authProvider = Provider.of<AuthProvider>(context, listen: false);
                              final verified = await authProvider.reauthenticateWithPassword(passwordController.text);
                              if (!dialogCtx.mounted) return;

                              if (!verified) {
                                setDialogState(() => isDeleting = false);
                                VSPFeedback.showError(
                                  dialogCtx,
                                  isArabic ? 'كلمة المرور غير صحيحة. لم يتم حذف الحساب.' : 'Incorrect password. The account was not deleted.',
                                );
                                return;
                              }

                              final success = await authProvider.deleteAccount();

                              if (!context.mounted) return;

                              if (success) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                                  (route) => false,
                                );
                              } else {
                                setDialogState(() => isDeleting = false);
                                VSPFeedback.showError(
                                  context,
                                  authProvider.errorMessage ??
                                      (isArabic ? 'فشل حذف الحساب' : 'Failed to delete account'),
                                );
                                Navigator.pop(dialogCtx);
                              }
                            },
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(VSPSpacing.md),
        decoration: BoxDecoration(
          color: VSPColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(VSPRadius.lg),
          border: Border.all(color: VSPColors.error.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: VSPColors.error.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.user_remove_copy, color: VSPColors.error, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? 'حذف الحساب نهائياً' : 'Delete Account',
                    style: const TextStyle(
                      color: VSPColors.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isArabic ? 'حذف كافة البيانات والملاعب السابقة' : 'Permanently remove profile & stadiums',
                    style: TextStyle(
                      color: VSPColors.textSecondary.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _showDeleteAccountDialog(context),
              style: TextButton.styleFrom(
                backgroundColor: VSPColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
              ),
              child: Text(
                isArabic ? 'حذف' : 'Delete',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
