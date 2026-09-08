import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';

class ChatInputBar extends StatelessWidget {
  final Booking booking;
  final TextEditingController messageController;
  final bool isSending;
  final VoidCallback onSendMessage;

  const ChatInputBar({
    super.key,
    required this.booking,
    required this.messageController,
    required this.isSending,
    required this.onSendMessage,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final now = DateTime.now();

    final isSpecialChat = booking.stadiumId == 'support_chat' ||
        booking.stadiumId == 'chat_thread' ||
        booking.notes == 'chat_thread' ||
        booking.notes == 'support_chat' ||
        booking.id.startsWith('support_chat_') ||
        booking.id.startsWith('chat_');

    final bool isExpired = isSpecialChat ? false : booking.endTime.isBefore(now);
    final bool isCancelled = isSpecialChat ? false : booking.status == BookingStatus.cancelled;

    if (isExpired || isCancelled) {
      return Container(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
        decoration: const BoxDecoration(
          color: VSPColors.surface,
          border: Border(top: BorderSide(color: VSPColors.divider, width: 0.5)),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Iconsax.lock_copy, color: VSPColors.textSecondary, size: 18),
              const SizedBox(width: 8),
              Text(
                isCancelled
                    ? (isArabic ? 'هذه المحادثة مغلقة لإلغاء الحجز.' : 'This chat is closed due to cancellation.')
                    : (isArabic ? 'المحادثة مغلقة لانتهاء وقت الحجز.' : 'This chat is closed as the booking time expired.'),
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
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
                border: Border.all(color: VSPColors.accent.withValues(alpha: 0.4), width: 1),
              ),
              child: TextField(
                controller: messageController,
                style: const TextStyle(color: VSPColors.textPrimary, fontSize: 14),
                textAlign: isArabic ? TextAlign.right : TextAlign.left,
                decoration: InputDecoration(
                  hintText: isArabic ? 'اكتب رسالتك هنا...' : 'Type a message...',
                  hintStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                onSubmitted: (_) => onSendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: isSending ? null : onSendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: VSPColors.accent,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Transform.rotate(
                  angle: isArabic ? 3.14159 : 0,
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
