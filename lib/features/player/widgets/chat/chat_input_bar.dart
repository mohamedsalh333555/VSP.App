import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';

class ChatInputBar extends StatelessWidget {
  final Booking? booking;
  final bool canSend;
  final TextEditingController messageController;
  final bool isSending;
  final VoidCallback onSendMessage;

  const ChatInputBar({
    super.key,
    this.booking,
    this.canSend = true,
    required this.messageController,
    required this.isSending,
    required this.onSendMessage,
  });

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';

    if (!canSend) {
      return Container(
        padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.of(context).padding.bottom + 14),
        decoration: const BoxDecoration(
          color: VSPColors.surface,
          border: Border(top: BorderSide(color: VSPColors.divider, width: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Iconsax.lock_copy, color: VSPColors.textSecondary, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                ar
                    ? 'انتهت فترة الكتابة لهذه المحادثة. يمكنك قراءة الرسائل السابقة.'
                    : 'Messaging is closed for this conversation. Previous messages remain available.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      decoration: const BoxDecoration(
        color: VSPColors.surface,
        border: Border(top: BorderSide(color: VSPColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: VSPColors.surfaceAlt,
                borderRadius: BorderRadius.circular(VSPRadius.full),
                border: Border.all(color: VSPColors.accent.withValues(alpha: 0.4)),
              ),
              child: TextField(
                controller: messageController,
                style: const TextStyle(color: VSPColors.textPrimary, fontSize: 14),
                textAlign: ar ? TextAlign.right : TextAlign.left,
                decoration: InputDecoration(
                  hintText: ar ? 'اكتب رسالتك هنا...' : 'Type a message...',
                  hintStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                onSubmitted: (_) => isSending ? null : onSendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: isSending ? null : onSendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(color: VSPColors.accent, shape: BoxShape.circle),
              child: Center(
                child: Transform.rotate(
                  angle: ar ? 3.14159 : 0,
                  child: const Icon(Iconsax.send_1_copy, color: Colors.black, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
