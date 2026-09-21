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
    final confirmationWord = isArabic ? 'حذف' : 'DELETE';
    final TextEditingController confirmController = TextEditingController();
    bool isDeleting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isMatched = confirmController.text.trim() == confirmationWord;

          return AlertDialog(
            backgroundColor: VSPColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.dialog)),
            title: Row(
              children: [
                const Icon(Iconsax.warning_2_copy, color: VSPColors.error, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isArabic ? 'حذف حساب المالك نهائياً؟' : 'Delete Account Permanently?',
                    style: const TextStyle(color: VSPColors.error, fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic
                        ? 'تحذير: هذا الإجراء نهائي ولا يمكن التراجع عنه مطلقاً.\nسيتم حذف حسابك وجميع ملاعبك المسجلة وسجل الحجوزات والبيانات المالية فوراً.'
                        : 'Warning: This action is permanent and cannot be undone.\nYour account, all registered stadiums, bookings, and ledger records will be deleted immediately.',
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.55),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isArabic
                        ? 'لتأكيد الحذف، يرجى كتابة كلمة "$confirmationWord" أدناه:'
                        : 'To confirm deletion, please type "$confirmationWord" below:',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmController,
                    onChanged: (_) => setDialogState(() {}),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: VSPColors.error, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    decoration: InputDecoration(
                      hintText: confirmationWord,
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.3),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(VSPRadius.input),
                        borderSide: BorderSide(color: VSPColors.error.withValues(alpha: 0.4)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(VSPRadius.input),
                        borderSide: const BorderSide(color: VSPColors.error, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
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
                      text: isArabic ? 'تأكيد الحذف' : 'Confirm Delete',
                      height: 48,
                      color: isMatched ? VSPColors.error : VSPColors.surfaceAlt,
                      textColor: isMatched ? Colors.white : VSPColors.textSecondary,
                      isLoading: isDeleting,
                      onPressed: (!isMatched || isDeleting)
                          ? null
                          : () async {
                              setDialogState(() => isDeleting = true);
                              final authProvider = Provider.of<AuthProvider>(context, listen: false);
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
