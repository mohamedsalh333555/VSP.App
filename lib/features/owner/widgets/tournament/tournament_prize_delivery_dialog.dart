import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/repositories/tournament_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';
import '../../../../shared/widgets/custom_text_field.dart';

/// Dialog allowing tournament owner to record prize delivery and handover notes.
Future<void> showTournamentPrizeDeliveryDialog(
  BuildContext context, {
  required Championship championship,
  VoidCallback? onDelivered,
}) async {
  final isAr = Localizations.localeOf(context).languageCode == 'ar';
  final notesController = TextEditingController();
  bool isSubmitting = false;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final prizeAmount =
              championship.prizePool > 0 ? championship.prizePool : championship.grandPrize;
          return AlertDialog(
            backgroundColor: VSPColors.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
            title: Row(
              children: [
                const Icon(Iconsax.award_copy, color: VSPColors.success, size: 22),
                const SizedBox(width: 8),
                Text(
                  isAr ? 'توثيق تسليم الجائزة للبطل' : 'Record Prize Handover',
                  style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: VSPColors.background,
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      border: Border.all(color: VSPColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          championship.name,
                          style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isAr ? 'مبلغ الجائزة (الوعاء الفعلي):' : 'Prize Pool:',
                              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                            ),
                            Text(
                              '${prizeAmount.toInt()} ${isAr ? "ج.م" : "EGP"}',
                              style: const TextStyle(
                                  color: VSPColors.success, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isAr ? 'ملاحظات التسليم / وسيلة التحويل:' : 'Handover Notes / Method:',
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  CustomTextField(
                    controller: notesController,
                    hintText: isAr
                        ? 'مثال: تم التحويل بنكياً أو تسليم نقدي بحضور الإدارة'
                        : 'e.g. Bank transfer / Cash in stadium',
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: Text(isAr ? 'إلغاء' : 'Cancel', style: const TextStyle(color: VSPColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: VSPColors.success,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setDialogState(() => isSubmitting = true);
                        try {
                          await TournamentRepository().markChampionshipPrizeDelivered(
                            championship.id,
                            notes: notesController.text.trim(),
                          );
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            VSPFeedback.showSuccess(
                              context,
                              isAr
                                  ? 'تم توثيق تسليم الجائزة المالية وإدراجها في السجل المالي بنجاح'
                                  : 'Prize delivery officially recorded in ledger',
                            );
                            onDelivered?.call();
                          }
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          if (context.mounted) {
                            VSPFeedback.showError(context, e.toString());
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : Text(isAr ? 'تأكيد التسليم' : 'Confirm Handover',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
    },
  );
}
