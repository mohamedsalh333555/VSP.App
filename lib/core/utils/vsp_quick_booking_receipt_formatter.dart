import 'package:flutter/material.dart';
import '../utils/vsp_launcher_utils.dart';
import 'app_date_formatter.dart';

class VSPQuickBookingReceiptFormatter {
 /// Generate a professional booking confirmation receipt formatted for WhatsApp
 static String buildReceiptMessage({
 required String stadiumName,
 required String bookingRef,
 required String customerName,
 required DateTime startTime,
 required DateTime endTime,
 required double totalPrice,
 double depositPaid = 0.0,
 bool isCashConfirmed = false,
 String? googleMapsUrl,
 String? stadiumPhone,
 bool isArabic = true,
 }) {
 final dateStr = AppDateFormatter.formatDayMonth(startTime, isArabic ? 'ar' : 'en');
 final timeStr = '${AppDateFormatter.formatTime(startTime, isArabic ? 'ar' : 'en')} - ${AppDateFormatter.formatTime(endTime, isArabic ? 'ar' : 'en')}';
 final remainingAmount = (totalPrice - depositPaid).clamp(0.0, 999999.0);

 final mapsLine = (googleMapsUrl != null && googleMapsUrl.isNotEmpty)
 ? (isArabic ? '📍 *موقع الملعب على الخريطة:* $googleMapsUrl\n' : '📍 *Location Map:* $googleMapsUrl\n')
 : '';

 final phoneLine = (stadiumPhone != null && stadiumPhone.isNotEmpty)
 ? (isArabic ? '📞 *هاتف الملعب للإستفسار:* $stadiumPhone\n' : '📞 *Stadium Phone:* $stadiumPhone\n')
 : '';

 String paymentStatus;
 if (isCashConfirmed) {
 if (depositPaid > 0 && depositPaid < totalPrice) {
 paymentStatus = isArabic
 ? 'مدفوع بالكامل (عربون: ${depositPaid.toInt()} ج.م + كاش: ${(totalPrice - depositPaid).toInt()} ج.م)'
 : 'Paid in full (Deposit: ${depositPaid.toInt()} EGP + Cash: ${(totalPrice - depositPaid).toInt()} EGP)';
 } else {
 paymentStatus = isArabic ? 'مدفوع بالكامل نقداً بالملعب' : 'Paid in full cash at pitch';
 }
 } else if (depositPaid >= totalPrice && totalPrice > 0) {
 paymentStatus = isArabic ? 'مدفوع بالكامل إلكترونياً' : 'Paid in full online';
 } else if (depositPaid > 0) {
 paymentStatus = isArabic
 ? 'عربون مسدد: ${depositPaid.toInt()} ج.م (المتبقي: ${remainingAmount.toInt()} ج.م عند الحضور)'
 : 'Deposit: ${depositPaid.toInt()} EGP (Remaining: ${remainingAmount.toInt()} EGP upon arrival)';
 } else {
 paymentStatus = isArabic
 ? 'دفع كاش بالملعب: ${totalPrice.toInt()} ج.م'
 : 'Cash at pitch: ${totalPrice.toInt()} EGP';
 }

 if (isArabic) {
 return '''
 *وصل تأكيد حجز ملعب — VSP* 

 *الملعب:* $stadiumName
 *الكابتن:* $customerName
 *التاريخ:* $dateStr
 *الميعاد:* $timeStr
 *الإجمالي:* ${totalPrice.toInt()} ج.م ($paymentStatus)
 *كود الحجز:* #$bookingRef
$mapsLine$phoneLine
 *تنبيه:* يرجى الحضور قبل الموعد بـ 10 دقائق لتجهيز الإحماء. نتمنى لكم مباراة ممتعة! 
'''.trim();
 } else {
 return '''
 *VSP Pitch Booking Confirmation Receipt* 

 *Pitch:* $stadiumName
 *Captain:* $customerName
 *Date:* $dateStr
 *Time:* $timeStr
 *Total:* ${totalPrice.toInt()} EGP ($paymentStatus)
 *Booking Code:* #$bookingRef
$mapsLine$phoneLine
 *Note:* Please arrive 10 minutes prior for warmup. Enjoy your match! 
'''.trim();
 }
 }

 /// Launch WhatsApp directly with customer phone number and the receipt message
 static Future<void> sendReceiptToCustomer({
 required BuildContext context,
 required String phone,
 required String receiptMessage,
 }) async {
 await VSPLauncherUtils.openWhatsApp(
 context,
 phone: phone,
 message: receiptMessage,
 );
 }
}
