import 'package:flutter/material.dart';
import '../../core/ui/tokens/vsp_tokens.dart';
import '../../core/utils/vsp_feedback.dart';
import '../widgets/primary_button.dart';

/// Confirmation owns its pending state, so closing the caller cannot reuse it.
Future<bool?> showAccountDeletionDialog(
  BuildContext context, {
  required Future<bool> Function(String? password) onDelete,
  bool requirePassword = false,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    useSafeArea: true,
    builder: (_) => AccountDeletionDialog(
      onDelete: onDelete,
      requirePassword: requirePassword,
    ),
  );
}

class AccountDeletionDialog extends StatefulWidget {
  const AccountDeletionDialog({
    super.key,
    required this.onDelete,
    this.requirePassword = false,
  });

  final Future<bool> Function(String? password) onDelete;
  final bool requirePassword;

  @override
  State<AccountDeletionDialog> createState() => _AccountDeletionDialogState();
}

class _AccountDeletionDialogState extends State<AccountDeletionDialog> {
  final _password = TextEditingController();
  bool _pending = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pending) return;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    if (widget.requirePassword && _password.text.isEmpty) {
      VSPFeedback.showWarning(context,
        isArabic ? 'أدخل كلمة مرور الحساب أولاً.' : 'Enter your account password first.');
      return;
    }
    setState(() => _pending = true);
    try {
      final success = await widget.onDelete(widget.requirePassword ? _password.text : null);
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop(true);
        return;
      }
    } catch (_) {
      // Provider/network errors must not expose backend messages or strand the dialog.
    }
    if (!mounted) return;
    setState(() => _pending = false);
    VSPFeedback.showError(context,
      isArabic ? 'تعذر تأكيد حذف الحساب. تحقق من بياناتك والاتصال وحاول مرة أخرى.'
        : 'Could not confirm account deletion. Check your details and connection, then try again.');
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    // AlertDialog measures actions intrinsically; a LayoutBuilder there cannot lay out.
    final actionWidth = (MediaQuery.sizeOf(context).width - 2 * VSPSpacing.lg - 2 * VSPSpacing.md)
        .clamp(0.0, 480.0).toDouble();
    final stackActions = actionWidth < 360 || MediaQuery.textScalerOf(context).scale(14) > 18;
    final cancel = PrimaryButton(
      text: isArabic ? 'إلغاء' : 'Cancel',
      height: 48,
      color: VSPColors.surfaceAlt,
      textColor: VSPColors.textPrimary,
      onPressed: _pending ? null : () => Navigator.of(context).pop(false),
    );
    final submit = PrimaryButton(
      text: isArabic ? 'حذف' : 'Delete',
      height: 48,
      color: VSPColors.error,
      textColor: VSPColors.background,
      isLoading: _pending,
      onPressed: _pending ? null : _submit,
    );
    return PopScope(
      canPop: !_pending,
      child: AlertDialog(
        insetPadding: const EdgeInsets.all(VSPSpacing.lg),
        scrollable: true,
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Text(isArabic ? 'حذف الحساب نهائياً؟' : 'Delete account permanently?',
          style: const TextStyle(color: VSPColors.error, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isArabic
              ? 'هذا الإجراء نهائي. قد يلزم إنهاء الحجوزات والتسويات المعلقة أولاً.'
              : 'This action is permanent. Active bookings and pending settlements may need to be resolved first.',
              style: const TextStyle(color: VSPColors.textSecondary, height: 1.5)),
            if (widget.requirePassword) ...[
              const SizedBox(height: VSPSpacing.md),
              TextField(
                controller: _password,
                obscureText: true,
                enabled: !_pending,
                autofocus: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: isArabic ? 'كلمة مرور الحساب' : 'Account password',
                ),
              ),
            ],
          ],
        ),
        actionsPadding: const EdgeInsets.all(VSPSpacing.md),
        actions: [
          SizedBox(
            width: actionWidth,
            child: stackActions
              ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                cancel, const SizedBox(height: VSPSpacing.sm), submit,
              ])
              : Row(children: [
              Expanded(child: cancel), const SizedBox(width: VSPSpacing.md), Expanded(child: submit),
              ]),
          ),
        ],
      ),
    );
  }
}
