import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/chat_model.dart';
import '../../../../core/repositories/chat_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final Booking booking;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.booking,
  });

  void _showEditDialog(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final editController = TextEditingController(text: message.text);

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isArabic ? 'تعديل الرسالة ' : 'Edit Message ',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: editController,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: isArabic ? 'اكتب الرسالة الجديدة...' : 'Enter new message...',
            hintStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text(isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: VSPColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final newText = editController.text.trim();
              if (newText.isEmpty || newText == message.text) {
                Navigator.pop(dlgCtx);
                return;
              }
              Navigator.pop(dlgCtx);
              await ChatRepository().editMessage(message.id, newText);
            },
            child: Text(isArabic ? 'حفظ التعديل' : 'Save', style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).then((_) => editController.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final isHost = message.senderId == booking.createdByUserId;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return GestureDetector(
      onLongPress: isMe ? () => _showEditDialog(context) : null,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? VSPColors.accent : VSPColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
            boxShadow: isHost
                ? [
                    BoxShadow(
                      color: VSPColors.accent.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isMe)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.senderName,
                      style: const TextStyle(
                        color: VSPColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isHost) ...[
                      const SizedBox(width: 4),
                      Text(
                        isArabic ? '[المُضيف ]' : '[HOST ]',
                        style: const TextStyle(
                          color: VSPColors.warning,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              if (!isMe) const SizedBox(height: 2),
              Text(
                message.text,
                style: TextStyle(
                  color: isMe ? VSPColors.background : VSPColors.textPrimary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.isEdited) ...[
                    Text(
                      isArabic ? '(مُعدلة) ' : '(edited) ',
                      style: TextStyle(
                        color: (isMe ? VSPColors.background : VSPColors.textSecondary).withValues(alpha: 0.65),
                        fontSize: 9,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  Text(
                    DateFormat('hh:mm a').format(message.timestamp),
                    style: TextStyle(
                      color: (isMe ? VSPColors.background : VSPColors.textSecondary).withValues(alpha: 0.6),
                      fontSize: 10,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.isRead ? Icons.done_all_rounded : Icons.check_rounded,
                      size: 14,
                      color: message.isRead ? Colors.blueAccent : VSPColors.background.withValues(alpha: 0.65),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
