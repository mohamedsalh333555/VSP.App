import 'package:flutter/material.dart';
import '../../../../core/repositories/report_repository.dart';
import '../../../../core/repositories/chat_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';

class ChatDialogs {
  static void showReportDialog(
    BuildContext context, {
    required String currentUserId,
    required String targetUserId,
    required String contextId,
    required String contextType,
    String? bookingId,
    String? conversationId,
  }) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final reasonController = TextEditingController();
    final detailsController = TextEditingController();

    showDialog(
      context: context,
      useSafeArea: true,
      builder: (dlgCtx) => AlertDialog(
        scrollable: true,
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.dialog)),
        title: Text(
          ar ? 'إبلاغ عن المستخدم' : 'Report User',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ar ? 'سيتم ربط البلاغ بالمحادثة والحجز/المباراة كدليل سياقي. لن يتم حظر الطرف الآخر تلقائيًا.' : 'The report will include the chat and booking/match context. The other user will not be auto-blocked.',
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: ar ? 'سبب الإبلاغ' : 'Reason for report',
                hintStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: detailsController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: ar ? 'تفاصيل إضافية (اختياري)' : 'Additional details (optional)',
                hintStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(64, 48),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text(ar ? 'إلغاء' : 'Cancel', style: const TextStyle(color: VSPColors.textSecondary)),
          ),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(64, 48),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(dlgCtx);
              final success = await ReportRepository().reportEntity(
                reporterId: currentUserId,
                targetId: targetUserId,
                targetType: 'user',
                reason: reason,
                details: detailsController.text.trim(),
                contextType: contextType,
                contextId: contextId,
                bookingId: bookingId,
                conversationId: conversationId,
              );
              if (context.mounted) {
                success
                    ? VSPFeedback.showSuccess(context, ar ? 'تم إرسال البلاغ للمراجعة الإدارية.' : 'The report was submitted for administrative review.')
                    : VSPFeedback.showError(context, ar ? 'تعذر إرسال البلاغ.' : 'Could not submit the report.');
              }
            },
            child: Text(ar ? 'إرسال البلاغ' : 'Submit Report', style: const TextStyle(color: VSPColors.error, fontWeight: FontWeight.bold)),
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
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    showDialog(
      context: context,
      useSafeArea: true,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.dialog)),
        title: Text(ar ? 'حذف المحادثة' : 'Delete Conversation', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(ar ? 'ستختفي المحادثة من صندوقك فقط، ولن تُحذف من الطرف الآخر.' : 'The conversation will be hidden from your inbox only.', style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 48), tapTargetSize: MaterialTapTargetSize.padded),
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text(ar ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(64, 48),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            onPressed: () async {
              Navigator.pop(dlgCtx);
              try {
                await ChatRepository().deleteConversationForUser(conversationId, currentUserId);
                if (context.mounted) {
                  Navigator.pop(context, true);
                  VSPFeedback.showSuccess(context, ar ? 'تم حذف المحادثة.' : 'Conversation removed.');
                }
              } catch (_) {
                if (context.mounted) VSPFeedback.showError(context, ar ? 'تعذر حذف المحادثة.' : 'Could not remove conversation.');
              }
            },
            child: Text(ar ? 'حذف' : 'Delete', style: const TextStyle(color: VSPColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static void showConfirmDeleteDialog(
    BuildContext context, {
    required String currentUserId,
    required Booking booking,
    required String conversationId,
  }) {
    showConfirmDeleteConversationDialog(
      context,
      currentUserId: currentUserId,
      conversationId: conversationId,
    );
  }
}
