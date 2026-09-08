import 'package:flutter/material.dart';
import '../../../../core/repositories/user_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';

class ChatAppBarTitle extends StatelessWidget {
  final Booking booking;
  final String currentUserId;

  const ChatAppBarTitle({
    super.key,
    required this.booking,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isSpecialChat = booking.stadiumId == 'support_chat' ||
        booking.stadiumId == 'chat_thread' ||
        booking.notes == 'chat_thread' ||
        booking.notes == 'support_chat' ||
        booking.id.startsWith('support_chat_') ||
        booking.id.startsWith('chat_');

    if (!isSpecialChat) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            booking.stadiumName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            '${booking.playerTeamName ?? "Public Match"} Chat',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
          ),
        ],
      );
    }

    final otherUserId = booking.joinedUserIds.firstWhere(
      (uid) => uid != currentUserId,
      orElse: () => 'vsp_support_admin',
    );

    if (otherUserId == 'vsp_support_admin') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? 'الدعم الفني VSP' : 'VSP Support',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            isArabic ? 'محادثة الدعم الفني' : 'Support Conversation',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
          ),
        ],
      );
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: UserRepository().getUserData(otherUserId),
      builder: (context, snap) {
        final name = snap.data?['name'] ?? (isArabic ? 'مستخدم VSP' : 'VSP User');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              isArabic ? 'محادثة مباشرة' : 'Direct Conversation',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
            ),
          ],
        );
      },
    );
  }
}
