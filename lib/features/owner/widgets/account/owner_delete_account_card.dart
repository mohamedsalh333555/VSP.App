import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../shared/dialogs/account_deletion_dialog.dart';
import '../../../auth/screens/welcome_screen.dart';

class OwnerDeleteAccountCard extends StatefulWidget {
  const OwnerDeleteAccountCard({super.key});

  @override
  State<OwnerDeleteAccountCard> createState() => _OwnerDeleteAccountCardState();
}

class _OwnerDeleteAccountCardState extends State<OwnerDeleteAccountCard> {
  bool _dialogOpen = false;

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    if (_dialogOpen) return;
    final auth = context.read<AuthProvider>();
    final uid = auth.currentUser?.id;
    if (uid == null) return;
    setState(() => _dialogOpen = true);
    try {
      final deleted = await showAccountDeletionDialog(
        context,
        requirePassword: true,
        onDelete: (password) async {
          if (auth.currentUser?.id != uid) return false;
          final verified = await auth.reauthenticateWithPassword(password!);
          if (!verified || auth.currentUser?.id != uid) return false;
          return auth.deleteAccount();
        },
      );
      if (deleted == true && context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      }
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
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
                    isArabic ? 'حذف الحساب والبيانات المرتبطة به' : 'Delete your account and associated data',
                    style: TextStyle(
                      color: VSPColors.textSecondary.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _dialogOpen ? null : () => _showDeleteAccountDialog(context),
              style: TextButton.styleFrom(
                backgroundColor: VSPColors.error,
                foregroundColor: VSPColors.white,
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
