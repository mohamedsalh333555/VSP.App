import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../shared/widgets/primary_button.dart';

Future<void> showDocUnderReviewDialog(BuildContext context) async {
  final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: VSPColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VSPRadius.lg),
      ),
      icon: const Icon(
        Iconsax.clock_copy,
        color: VSPColors.accent,
        size: 48,
      ),
      title: Text(
        isArabic ? ' قيد المراجعة' : ' Under Review',
        style: Theme.of(ctx).textTheme.titleLarge,
        textAlign: TextAlign.center,
      ),
      content: Text(
        isArabic
            ? "لقد تم استلام بياناتك بنجاح! \n\nنحن الآن نقوم بمراجعتها. يمكنك الانتقال لاستكشاف لوحة التحكم الخاصة بك الآن، ولكن يرجى العلم أن ملاعبك ستظل مخفية عن اللاعبين حتى يتم التوثيق من الإدارة."
            : "Your data has been successfully received! \n\nWe are reviewing it now. You can explore your dashboard, but your stadiums will remain hidden from players until verified by admin.",
        style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
              color: VSPColors.textSecondary,
              height: 1.6,
            ),
        textAlign: TextAlign.center,
      ),
      actionsPadding: const EdgeInsets.symmetric(
        horizontal: VSPSpacing.md,
        vertical: VSPSpacing.md,
      ),
      actions: [
        PrimaryButton(
          text: isArabic ? 'الذهاب إلى لوحة التحكم' : 'Go to Dashboard',
          height: 48,
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ],
    ),
  );
}
