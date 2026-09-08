import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';

class ChatSystemBanner extends StatelessWidget {
  final Booking booking;
  final String currentUserId;

  const ChatSystemBanner({
    super.key,
    required this.booking,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final isSpecialChat = booking.stadiumId == 'support_chat' ||
        booking.stadiumId == 'chat_thread' ||
        booking.notes == 'chat_thread' ||
        booking.notes == 'support_chat' ||
        booking.id.startsWith('support_chat_') ||
        booking.id.startsWith('chat_');

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (isSpecialChat) {
      final otherUserId = booking.joinedUserIds.firstWhere(
        (uid) => uid != currentUserId,
        orElse: () => 'vsp_support_admin',
      );
      final text = otherUserId == 'vsp_support_admin'
          ? (isArabic
              ? ' مرحباً بك في الدعم الفني لـ VSP. كيف يمكننا مساعدتك اليوم؟'
              : ' Welcome to VSP Support. How can we help you today?')
          : (isArabic
              ? ' هذه محادثة مباشرة آمنة ومشفرة.'
              : ' This is a secure and encrypted direct chat.');

      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: VSPColors.surface.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(VSPRadius.lg),
          ),
          child: Text(
            text,
            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final text = isArabic
        ? ' تم تأكيد الحجز! الساحة بانتظاركم... من جاهز للتحدي؟ '
        : ' Booking Confirmed! The pitch is waiting... Who is ready? ';

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(VSPRadius.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(VSPRadius.lg),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: VSPColors.surface.withValues(alpha: 0.4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.cup_copy, color: VSPColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      text,
                      style: const TextStyle(
                        color: VSPColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
