import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Captain-only response to an owner report. This never changes payment,
/// result points or player attendance; only the server may review appeals.
class ChallengeNonPlayedAppealDialog extends StatefulWidget {
  final bool isArabic;

  const ChallengeNonPlayedAppealDialog({
    super.key, required this.isArabic,
  });

  static Future<String?> show(BuildContext context, {
    required bool isArabic,
  }) => showDialog<String>(
        context: context,
        useSafeArea: true,
        builder: (context) => ChallengeNonPlayedAppealDialog(
          isArabic: isArabic,
        ),
      );

  @override
  State<ChallengeNonPlayedAppealDialog> createState() =>
      _ChallengeNonPlayedAppealDialogState();
}

class _ChallengeNonPlayedAppealDialogState
    extends State<ChallengeNonPlayedAppealDialog> {
  final _reason = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ar = widget.isArabic;
    return AlertDialog(
      scrollable: true,
      backgroundColor: VSPColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VSPRadius.md),
      ),
      title: Text(ar
          ? 'اعتراض على بلاغ عدم لعب المباراة'
          : 'Appeal the match-not-played report'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ar
                ? 'اكتب سبب اعتراضك أو دليل إقامة المباراة. يظل اللقاء مستبعدًا من الترتيب حتى انتهاء المراجعة، ولن يتغير أي مبلغ مدفوع.'
                : 'Explain why you believe the match was played. It stays excluded from standings until review; no payments are changed.',
            style: const TextStyle(
              color: VSPColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: VSPSpacing.md),
          TextField(
            controller: _reason,
            autofocus: true,
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            onChanged: (_) {
              if (_invalid) setState(() => _invalid = false);
            },
            decoration: InputDecoration(
              labelText: ar ? 'سبب الاعتراض' : 'Reason for appeal',
              hintText: ar
                  ? 'مثلاً: صورة أو شهادة بإقامة اللقاء'
                  : 'For example, match photos or witness information',
              errorText: _invalid
                  ? (ar
                      ? 'اكتب سببًا من 8 إلى 500 حرف.'
                      : 'Enter a reason between 8 and 500 characters.')
                  : null,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(ar ? 'إلغاء' : 'Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final reason = _reason.text.trim();
            if (reason.runes.length < 8 || reason.runes.length > 500) {
              setState(() => _invalid = true);
              return;
            }
            Navigator.pop(context, reason);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: VSPColors.warning,
            foregroundColor: VSPColors.black,
          ),
          child: Text(ar ? 'إرسال الاعتراض' : 'Submit appeal'),
        ),
      ],
    );
  }
}
