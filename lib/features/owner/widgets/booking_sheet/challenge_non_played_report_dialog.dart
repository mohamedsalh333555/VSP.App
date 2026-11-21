import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Explains the neutral match-validity report and collects an evidence reason.
/// Financial player no-show is a different action and is never called here.
class ChallengeNonPlayedReportDialog extends StatefulWidget {
  final bool isArabic;
  const ChallengeNonPlayedReportDialog({
    super.key, required this.isArabic,
  });

  static Future<String?> show(BuildContext context, {
    required bool isArabic,
  }) => showDialog<String>(
        context: context,
        useSafeArea: true,
        builder: (context) =>
            ChallengeNonPlayedReportDialog(isArabic: isArabic),
      );

  @override
  State<ChallengeNonPlayedReportDialog> createState() =>
      _ChallengeNonPlayedReportDialogState();
}

class _ChallengeNonPlayedReportDialogState
    extends State<ChallengeNonPlayedReportDialog> {
  final TextEditingController _reason = TextEditingController();
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
          ? 'الإبلاغ أن المباراة لم تُلعب'
          : 'Report match not played'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ar
                ? 'هذا بلاغ عن صحة المباراة، وليس غياب لاعب. يستبعد النتيجة من ترتيب الفريقين حتى المراجعة، ولا يغيّر المدفوعات أو يفرض عقوبة.'
                : 'This is a match-validity report, not an individual no-show. It excludes the result from standings pending review, without changing payments or imposing penalties.',
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
            minLines: 2,
            maxLines: 4,
            maxLength: 500,
            onChanged: (_) {
              if (_invalid) setState(() => _invalid = false);
            },
            decoration: InputDecoration(
              labelText: ar ? 'سبب البلاغ' : 'Reason for report',
              hintText: ar
                  ? 'اذكر سبب تأكدك أن المباراة لم تُلعب'
                  : 'Explain why you believe the match was not played',
              errorText: _invalid
                  ? (ar
                      ? 'اكتب سببًا واضحًا من 8 إلى 500 حرف.'
                      : 'Enter a clear reason (8–500 characters).')
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
            final text = _reason.text.trim();
            if (text.runes.length < 8 || text.runes.length > 500) {
              setState(() => _invalid = true);
              return;
            }
            Navigator.pop(context, text);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: VSPColors.warning,
            foregroundColor: VSPColors.black,
          ),
          child: Text(ar ? 'تسجيل البلاغ' : 'Submit report'),
        ),
      ],
    );
  }
}
