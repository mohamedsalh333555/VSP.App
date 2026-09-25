import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/utils/app_date_formatter.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';

/// Utilities for launching WhatsApp support and generating official digital booking receipts.
class BookingSheetWhatsAppUtils {
  const BookingSheetWhatsAppUtils._();

  /// Launches WhatsApp support chat to report player no-show or disputes.
  static Future<void> launchWhatsAppSupport(Booking b, bool isArabic) async {
    final player = (b.playerTeamName != null && b.playerTeamName!.isNotEmpty)
        ? b.playerTeamName!
        : 'لاعب';
    final id = b.id;
    final dateStr = AppDateFormatter.formatFullDate(b.startTime, isArabic ? 'ar' : 'en');
    final timeStr = AppDateFormatter.formatTime(b.startTime, isArabic ? 'ar' : 'en');
    final msg = isArabic
        ? "مرحباً دعم VSP، أريد الإبلاغ عن صاحب الحجز (عدم حضور / مشكلة بالحجز).\nرقم الحجز: $id\nاسم صاحب الحجز: $player\nموعد الحجز: $dateStr • $timeStr"
        : "Hi VSP Support, I would like to report the booking holder (no-show / dispute).\nBooking ID: $id\nPlayer Name: $player\nSlot: $dateStr • $timeStr";
    final url = 'https://wa.me/201100229462?text=${Uri.encodeComponent(msg)}';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch WhatsApp: $e');
    }
  }

  /// Formats and shares an official digital booking receipt via WhatsApp.
  static Future<void> sendWhatsAppReceipt(
    BuildContext context,
    Booking b,
    bool isArabic,
  ) async {
    final refCode = '#BK-${b.id.substring(0, b.id.length >= 6 ? 6 : b.id.length).toUpperCase()}';
    final customerName = (b.playerTeamName != null && b.playerTeamName!.isNotEmpty)
        ? b.playerTeamName!
        : (b.hostName != null && b.hostName!.isNotEmpty
            ? b.hostName!
            : (isArabic ? 'عميل VSP' : 'VSP Customer'));

    final stadiumName = b.stadiumName.isNotEmpty
        ? b.stadiumName
        : (isArabic ? 'ملعب VSP' : 'VSP Pitch');
    final dateStr = AppDateFormatter.formatFullDate(b.startTime, isArabic ? 'ar' : 'en');
    final startTimeStr = AppDateFormatter.formatTime(b.startTime, isArabic ? 'ar' : 'en');
    final endTimeStr = AppDateFormatter.formatTime(b.endTime, isArabic ? 'ar' : 'en');

    final totalPrice = b.totalPrice > 0 ? b.totalPrice : b.depositPaid;
    final depositPaid = b.depositPaid > 0 ? b.depositPaid : 0.0;
    final bool isPaidInFull = b.isPaid || b.paymentStatus == 'paid';
    final remainingCash = isPaidInFull ? 0.0 : (totalPrice - depositPaid).clamp(0.0, 999999.0);
    final cashCollected = isPaidInFull ? (totalPrice - depositPaid).clamp(0.0, 999999.0) : 0.0;

    final String paymentLines = isArabic
        ? (isPaidInFull
            ? (depositPaid > 0
                ? '*العربون المسدد إلكترونياً:* ${depositPaid.toInt()} ج.م\n*المسدد كاش بالملعب:* ${cashCollected.toInt()} ج.م\n*حالة الحساب:* خالص بالكامل (0 ج.م متبقي) ✅'
                : '*المسدد كاش بالملعب:* ${totalPrice.toInt()} ج.م\n*حالة الحساب:* خالص بالكامل (0 ج.م متبقي) ✅')
            : (depositPaid > 0
                ? '*العربون المسدد:* ${depositPaid.toInt()} ج.م\n*المتبقي للتحصيل بالملعب:* ${remainingCash.toInt()} ج.م ⏳'
                : '*المطلوب تحصيله كاش بالملعب:* ${totalPrice.toInt()} ج.م ⏳'))
        : (isPaidInFull
            ? (depositPaid > 0
                ? '*Online Deposit:* ${depositPaid.toInt()} EGP\n*Cash Paid at Pitch:* ${cashCollected.toInt()} EGP\n*Status:* Paid in Full (0 EGP due) ✅'
                : '*Cash Paid at Pitch:* ${totalPrice.toInt()} EGP\n*Status:* Paid in Full (0 EGP due) ✅')
            : (depositPaid > 0
                ? '*Deposit Paid:* ${depositPaid.toInt()} EGP\n*Remaining Cash Due:* ${remainingCash.toInt()} EGP ⏳'
                : '*Cash Due at Pitch:* ${totalPrice.toInt()} EGP ⏳'));

    final String receiptText = isArabic
        ? '''
*إيصال حجز إلكتروني رسمي — VSP Sports*
═════════════════════════
*كود الحجز:* $refCode
*اسم العميل:* $customerName
*الملعب:* $stadiumName
*التاريخ:* $dateStr
*التوقيت:* من $startTimeStr إلى $endTimeStr
*إجمالي المبلغ:* ${totalPrice.toInt()} ج.م
$paymentLines
═════════════════════════
*موقع الملعب على الخريطة:*
https://maps.google.com/?q=${Uri.encodeComponent(stadiumName)}

نتمنى لكم مباراة ممتعة.
'''
        : '''
*Official Digital Booking Receipt — VSP Sports*
═════════════════════════
*Booking Ref:* $refCode
*Customer Name:* $customerName
*Stadium:* $stadiumName
*Date:* $dateStr
*Time:* $startTimeStr - $endTimeStr
*Total Price:* ${totalPrice.toInt()} EGP
$paymentLines
═════════════════════════
*Location:*
https://maps.google.com/?q=${Uri.encodeComponent(stadiumName)}

Enjoy your match.
''';

    final String whatsappUrl = 'https://wa.me/?text=${Uri.encodeComponent(receiptText)}';
    try {
      await launchUrl(Uri.parse(whatsappUrl), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        VSPFeedback.showError(context, 'تعذر فتح الواتساب: $e');
      }
    }
  }
}
