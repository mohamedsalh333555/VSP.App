import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/repositories/report_repository.dart';
import '../../../../core/repositories/chat_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/ui/vsp_ui.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';

class ChatDialogs {
  static void showReportDialog(
    BuildContext context, {
    required String currentUserId,
    required String bookingId,
  }) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final reasonController = TextEditingController();
    final detailsController = TextEditingController();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: VSPDSSemanticColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VSPDSRadius.dialog),
        ),
        title: Text(
          isArabic ? 'إبلاغ عن المحادثة' : 'Report conversation',
          style: VSPDSTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: reasonController,
              style: VSPDSTypography.bodyMedium.copyWith(
                color: VSPDSSemanticColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: isArabic
                    ? 'سبب الإبلاغ'
                    : 'Reason for report',
                hintStyle: VSPDSTypography.bodyMedium.copyWith(
                  color: VSPDSSemanticColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: VSPDSSpacing.sm),
            TextField(
              controller: detailsController,
              maxLines: 3,
              style: VSPDSTypography.bodyMedium.copyWith(
                color: VSPDSSemanticColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: isArabic
                    ? 'تفاصيل إضافية (اختياري)'
                    : 'Additional details (optional)',
                hintStyle: VSPDSTypography.bodyMedium.copyWith(
                  color: VSPDSSemanticColors.textMuted,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text(
              isArabic ? 'إلغاء' : 'Cancel',
              style: VSPDSTypography.actionLabel.copyWith(
                color: VSPDSSemanticColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(dlgCtx);
              final success = await ReportRepository().reportEntity(
                reporterId: currentUserId,
                targetId: bookingId,
                targetType: 'chat',
                reason: reason,
                details: detailsController.text.trim(),
              );
              if (context.mounted) {
                if (success) {
                  VSPFeedback.showSuccess(
                    context,
                    isArabic
                        ? 'تم إرسال البلاغ بنجاح وسيتولى فريق VSP مراجعته.'
                        : 'Your report was submitted successfully.',
                  );
                } else {
                  VSPFeedback.showError(
                    context,
                    isArabic
                        ? 'تعذر إرسال البلاغ حالياً.'
                        : 'Unable to submit the report right now.',
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: VSPDSSemanticColors.error,
              foregroundColor: VSPDSColors.white,
              elevation: VSPDSElevation.none,
              minimumSize: const Size(0, VSPDSizes.buttonHeight),
              shape: const StadiumBorder(),
              textStyle: VSPDSTypography.compactButton,
            ),
            child: Text(isArabic ? 'إرسال البلاغ' : 'Submit report'),
          ),
        ],
      ),
    ).then((_) {
      reasonController.dispose();
      detailsController.dispose();
    });
  }

  static void showConfirmDeleteConversationDialog(
    BuildContext context, {
    required String currentUserId,
    required String conversationId,
  }) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    VSPConfirmationDialog.show(
      context: context,
      isDestructive: true,
      icon: Iconsax.trash_copy,
      title: isArabic ? 'حذف المحادثة' : 'Delete conversation',
      message: isArabic
          ? 'سيتم حذف المحادثة من قائمتك فقط، ولن تُحذف الرسائل من الطرف الآخر. هل تريد المتابعة؟'
          : 'The conversation will be removed from your list only. Messages will remain for the other participant. Continue?',
      confirmLabel: isArabic ? 'حذف' : 'Delete',
      cancelLabel: isArabic ? 'إلغاء' : 'Cancel',
    ).then((confirmed) async {
      if (!confirmed) return;
      await ChatRepository().deleteConversationForUser(
        conversationId,
        currentUserId,
      );
      if (context.mounted) {
        Navigator.pop(context, true);
        VSPFeedback.showSuccess(
          context,
          isArabic ? 'تم حذف المحادثة.' : 'Conversation deleted.',
        );
      }
    });
  }

  static void showConfirmDeleteDialog(
    BuildContext context, {
    required String currentUserId,
    required Booking booking,
  }) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.dialog)),
        title: Text(
          isArabic ? 'حذف المحادثة ' : 'Delete Conversation ',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isArabic ? 'هل أنت تأكد من رغبتك في حذف هذه المحادثة من طرفك؟' : 'Are you sure you want to delete this conversation?',
          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text(isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: VSPColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dlgCtx);

              String otherUserId = booking.joinedUserIds.firstWhere(
                (uid) => uid.isNotEmpty && uid != currentUserId,
                orElse: () => '',
              );

              if (otherUserId.isEmpty) {
                final isSupport = booking.stadiumId == 'support_chat' ||
                    booking.notes == 'support_chat' ||
                    booking.id.startsWith('support_chat_');
                if (isSupport) {
                  otherUserId = 'vsp_support_admin';
                } else if (booking.createdByUserId.isNotEmpty && booking.createdByUserId != currentUserId) {
                  otherUserId = booking.createdByUserId;
                } else if (booking.ownerId.isNotEmpty && booking.ownerId != currentUserId) {
                  otherUserId = booking.ownerId;
                }
              }

              final bool isValidUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(otherUserId);
              final String? sanitizedContactId = (otherUserId.isNotEmpty && otherUserId != 'vsp_support_admin' && isValidUuid) ? otherUserId : null;

              await ChatRepository().deleteConversationForUser(
                booking.id,
                currentUserId,
                contactId: sanitizedContactId,
              );

              if (context.mounted) {
                Navigator.pop(context, true);
                VSPFeedback.showSuccess(context, isArabic ? 'تم حذف المحادثة.' : 'Conversation deleted.');
              }
            },
            child: Text(isArabic ? 'حذف' : 'Delete', style: const TextStyle(color: VSPColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
