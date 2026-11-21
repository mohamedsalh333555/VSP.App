import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Keeps displayed/copyable challenge codes scoped to the authorized viewer.
/// [authorizationChanges] should notify when the active account or team changes.
/// The caller remains responsible for rechecking server-side captain privileges.
Future<void> showTeamMatchupInviteModal(
  BuildContext context,
  String code, {
  bool Function()? canReveal,
  Listenable? authorizationChanges,
}) async {
  bool isStillAuthorized() {
    try {
      return canReveal?.call() ?? true;
    } catch (_) {
      return false;
    }
  }

  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: VSPColors.transparent,
    builder: (ctx) {
      Widget buildScopedSheet(BuildContext ctx) {
        final isArabic = Localizations.localeOf(ctx).languageCode == 'ar';
        if (!isStillAuthorized()) {
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(VSPSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isArabic ? 'كود الدعوة لم يعد متاحًا' : 'Invite code unavailable',
                    style: const TextStyle(
                      color: VSPColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: VSPSpacing.md),
                  PrimaryButton(
                    text: isArabic ? 'إغلاق' : 'Close',
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
          );
        }
        return SingleChildScrollView(
          child: Container(
        padding: EdgeInsets.fromLTRB(
          VSPSpacing.xl,
          VSPSpacing.xl,
          VSPSpacing.xl,
          MediaQuery.of(ctx).viewPadding.bottom + VSPSpacing.xl,
        ),
        decoration: const BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(VSPRadius.xl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: VSPColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: VSPSpacing.lg),
            const Icon(
              Iconsax.key_copy,
              color: VSPColors.accent,
              size: 40,
            ),
            const SizedBox(height: VSPSpacing.md),
            Text(
              isArabic
                  ? 'كود دعوة مؤقت للمواجهة'
                  : 'Temporary matchup invite code',
              style: const TextStyle(
                color: VSPColors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isArabic
                  ? 'شارك الكود مع كابتن الفريق المنافس لإضافة الفريق للمواجهة. هذا الكود الحالي صالح لمدة ساعة وقد يتغير عند إنشاء كود جديد.'
                  : 'Share this code with the opposing captain to add the team to the matchup. This current code is valid for one hour and may change when a new code is generated.',
              style: const TextStyle(
                color: VSPColors.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VSPSpacing.xl),
            Semantics(
              label: isArabic
                  ? 'كود دعوة المواجهة $code'
                  : 'Matchup invite code $code',
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: VSPColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  border: Border.all(
                    color: VSPColors.accent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: SelectableText(
                        code,
                        style: const TextStyle(
                          color: VSPColors.accent,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      tooltip: isArabic ? 'نسخ الكود' : 'Copy code',
                      icon: const Icon(
                        Iconsax.copy_copy,
                        color: VSPColors.white,
                      ),
                      onPressed: () async {
                        // Copy is a new privileged action: recheck authorization
                        // even before a queued account-change repaint arrives.
                        if (!isStillAuthorized()) {
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          return;
                        }
                        try {
                          await Clipboard.setData(ClipboardData(text: code));
                        } catch (_) {
                          if (!ctx.mounted) return;
                          if (!isStillAuthorized()) {
                            Navigator.of(ctx).pop();
                            return;
                          }
                          VSPFeedback.showError(
                            ctx,
                            isArabic
                                ? 'تعذر نسخ الكود. حاول مرة أخرى.'
                                : 'Could not copy the code. Please try again.',
                          );
                          return;
                        }
                        if (!ctx.mounted) return;
                        // An account/team change can happen while the
                        // platform clipboard request is in flight. Never
                        // announce success to the newly signed-in viewer.
                        if (!isStillAuthorized()) {
                          Navigator.of(ctx).pop();
                          return;
                        }
                        VSPFeedback.showSuccess(
                          ctx,
                          isArabic
                              ? 'تم نسخ كود المواجهة'
                              : 'Matchup code copied',
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: VSPSpacing.xl),
            PrimaryButton(
              text: isArabic ? 'تم' : 'Done',
              onPressed: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: VSPSpacing.md),
          ],
        ),
          ),
        );
      }
      if (authorizationChanges == null) return buildScopedSheet(ctx);
      return AnimatedBuilder(
        animation: authorizationChanges,
        builder: (context, _) => buildScopedSheet(context),
      );
    },
  );
}
