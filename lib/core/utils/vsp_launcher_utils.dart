import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'vsp_feedback.dart';

class VSPLauncherUtils {
  /// فتح محادثة واتساب أو مشاركة النص بشكل موحد وآمن
  static Future<void> openWhatsApp(
    BuildContext context, {
    required String phone,
    required String message,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final fullPhone = cleanPhone.startsWith('0') && cleanPhone.length == 11
        ? '20${cleanPhone.substring(1)}'
        : cleanPhone;

    final encodedMessage = Uri.encodeComponent(message);
    final url = fullPhone.isEmpty
        ? Uri.parse('https://api.whatsapp.com/send?text=$encodedMessage')
        : Uri.parse('https://wa.me/$fullPhone?text=$encodedMessage');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // إذا تعذر فتح تطبيق واتساب مباشرة، نستخدم نافذة المشاركة العامة للنظام
        await Share.share(message);
      }
    } catch (e) {
      try {
        await Share.share(message);
      } catch (shareErr) {
        if (context.mounted) {
          VSPFeedback.showError(context, 'خطأ في فتح الرابط: $e');
        }
      }
    }
  }

  /// إجراء مكالمة هاتفية
  static Future<void> makePhoneCall(BuildContext context, String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final Uri launchUri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        VSPFeedback.showError(context, 'تعذر إجراء المكالمة: $e');
      }
    }
  }
}
