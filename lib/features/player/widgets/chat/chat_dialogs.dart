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
    required String bookingId,
  }) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final reasonController = TextEditingController();
    final detailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isArabic ? 'إبلاغ عن المحادثة ' : 'Report Chat ',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: isArabic ? 'سبب الإبلاغ (مثال: سلوك غير لائق)' : 'Reason for report',
                hintStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: detailsController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: isArabic ? 'تفاصيل إضافية (اختياري)...' : 'Additional details...',
                hintStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text(isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: VSPColors.textSecondary)),
          ),
          TextButton(
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
                  VSPFeedback.showSuccess(context, isArabic ? 'تم إرسال بلاغك بنجاح وسيتولى الفريق مراجعته.' : 'Report submitted successfully.');
                } else {
                  VSPFeedback.showError(context, isArabic ? 'حدث خطأ أثناء إرسال البلاغ.' : 'Error submitting report.');
                }
              }
            },
            child: Text(isArabic ? 'إرسال البلاغ' : 'Submit Report', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).then((_) {
      reasonController.dispose();
      detailsController.dispose();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            child: Text(isArabic ? 'حذف' : 'Delete', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
