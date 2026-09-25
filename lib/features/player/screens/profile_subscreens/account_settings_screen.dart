import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../shared/widgets/vsp_back_button.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VSPRadius.lg),
        ),
        title: Row(
          children: [
            const Icon(Iconsax.warning_2_copy, color: VSPColors.error, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isArabic ? 'حذف الحساب نهائياً؟' : 'Delete Account?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          isArabic
              ? 'تحذير: سيتم حذف جميع بياناتك وسجل حجوزاتك بشكل دائم ولا يمكن استرجاع الحساب بعد الحذف.'
              : 'Warning: All your data and booking history will be permanently deleted and cannot be recovered.',
          style: const TextStyle(
            color: VSPColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              isArabic ? 'تراجع' : 'Cancel',
              style: const TextStyle(color: VSPColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: VSPColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(isArabic ? 'تأكيد الحذف' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final success = await context.read<AuthProvider>().deleteAccount();
    if (!success && context.mounted) {
      VSPFeedback.showError(
        context,
        isArabic
            ? 'تعذر حذف الحساب، يرجى التواصل مع الدعم الفني.'
            : 'Failed to delete account, please contact support.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const VSPBackButton(),
        centerTitle: true,
        title: Text(
          isArabic ? 'إعدادات الحساب' : 'Account Settings',
          style: const TextStyle(
            color: VSPColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Container(
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.card),
                border: Border.all(color: VSPColors.divider),
              ),
              child: VSPMenuItem(
                icon: Iconsax.trash_copy,
                title: isArabic ? 'حذف الحساب نهائياً' : 'Delete Account',
                subtitle: isArabic
                    ? 'حذف حسابك وجميع بياناتك بشكل دائم'
                    : 'Permanently delete your account and data',
                isLogout: true,
                onTap: () => _confirmDeleteAccount(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
