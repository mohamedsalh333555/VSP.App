import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/repositories/app_settings_repository.dart';
import '../../../../core/repositories/user_repository.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';

class ChatCallUtils {
  static Future<void> makeCall(
    BuildContext context, {
    required Booking booking,
    required String currentUserId,
  }) async {
    try {
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      String? targetPhone;

      final isSupportChat = booking.stadiumId == 'support_chat' ||
          booking.notes == 'support_chat' ||
          booking.id.startsWith('support_chat_');

      final isDirectChat = booking.stadiumId == 'chat_thread' ||
          booking.notes == 'chat_thread' ||
          booking.id.startsWith('chat_');

      if (isSupportChat) {
        final settings = await AppSettingsRepository().getSettings();
        targetPhone = settings.supportPhone;
      } else if (isDirectChat) {
        final otherUserId = booking.joinedUserIds.firstWhere(
          (uid) => uid != currentUserId,
          orElse: () => '',
        );
        if (otherUserId.isNotEmpty) {
          final userData = await UserRepository().getUserData(otherUserId);
          targetPhone = userData?['phone']?.toString().trim();
        }
      } else {
        final ownerId = booking.ownerId;
        if (ownerId.isNotEmpty) {
          final userData = await UserRepository().getUserData(ownerId);
          targetPhone = userData?['phone']?.toString().trim();
        }
      }

      if (targetPhone != null && targetPhone.isNotEmpty) {
        final cleanPhone = targetPhone.replaceAll(RegExp(r'\D'), '');
        final path = cleanPhone.startsWith('0') && cleanPhone.length == 11
            ? '+2$cleanPhone'
            : (cleanPhone.startsWith('2') ? '+$cleanPhone' : cleanPhone);
        final Uri launchUri = Uri(scheme: 'tel', path: path);
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          VSPFeedback.showError(
            context,
            isArabic ? 'رقم الهاتف غير متاح حالياً.' : 'Phone number is not available.',
          );
        }
      }
    } catch (e) {
      debugPrint('Could not launch phone call from chat: $e');
    }
  }
}
