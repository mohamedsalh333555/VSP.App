import 'package:flutter/material.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';

/// Small reusable modal for a private collective-match invitation code.
///
/// The controller belongs to the dialog widget and is disposed only when the
/// reverse route transition unmounts it. Do not dispose a controller as soon
/// as showDialog() returns: TextField may still be in the transition tree.
class CollectiveCodeEntryDialog extends StatefulWidget {
  const CollectiveCodeEntryDialog({super.key});

  static Future<String?> show(BuildContext context) => showDialog<String>(
        context: context,
        useSafeArea: true,
        builder: (_) => const CollectiveCodeEntryDialog(),
      );

  @override
  State<CollectiveCodeEntryDialog> createState() =>
      _CollectiveCodeEntryDialogState();
}

class _CollectiveCodeEntryDialogState extends State<CollectiveCodeEntryDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return AlertDialog(
      backgroundColor: VSPColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VSPRadius.lg),
      ),
      title: Text(
        ar ? 'كود التجميعية' : 'Collective match code',
        style: const TextStyle(
          color: VSPColors.white, fontWeight: FontWeight.w800,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        style: const TextStyle(
          color: VSPColors.white,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
        decoration: InputDecoration(
          hintText: ar ? 'مثال: AB12CD34' : 'e.g. AB12CD34',
          hintStyle: const TextStyle(color: VSPColors.textSecondary),
          filled: true,
          fillColor: VSPColors.surfaceAlt,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(VSPRadius.md),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(ar ? 'إلغاء' : 'Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(_controller.text.trim().toUpperCase()),
          child: Text(ar ? 'فتح' : 'Open'),
        ),
      ],
    );
  }
}
