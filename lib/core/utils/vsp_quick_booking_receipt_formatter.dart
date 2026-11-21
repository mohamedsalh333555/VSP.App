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
 final safeTotal = totalPrice.isFinite && totalPrice > 0 ? totalPrice : 0.0;
 final safeDeposit = depositPaid.isFinite && depositPaid > 0 ? depositPaid.clamp(0.0, safeTotal).toDouble() : 0.0;
 final remainingAmount = safeTotal - safeDeposit;

 final mapsLine = (googleMapsUrl != null && googleMapsUrl.isNotEmpty)
 ? (isArabic ? '📍 *موقع الملعب على الخريطة:* $googleMapsUrl\n' : '📍 *Location Map:* $googleMapsUrl\n')
 : '';

 final phoneLine = (stadiumPhone != null && stadiumPhone.isNotEmpty)
 ? (isArabic ? '📞 *هاتف الملعب للإستفسار:* $stadiumPhone\n' : '📞 *Stadium Phone:* $stadiumPhone\n')
 : '';

 String paymentStatus;
 if (safeTotal == 0) {
 paymentStatus = isArabic ? 'لا توجد مبالغ مستحقة' : 'No payment due';
 } else if (safeDeposit >= safeTotal) {
 paymentStatus = isArabic ? 'مدفوع بالكامل إلكترونياً' : 'Paid in full online';
 } else if (isCashConfirmed) {
 if (safeDeposit > 0) {
 paymentStatus = isArabic
 ? 'مدفوع بالكامل (عربون: ${safeDeposit.toStringAsFixed(2)} ج.م + كاش: ${(safeTotal - safeDeposit).toStringAsFixed(2)} ج.م)'
 : 'Paid in full (Deposit: ${safeDeposit.toStringAsFixed(2)} EGP + Cash: ${(safeTotal - safeDeposit).toStringAsFixed(2)} EGP)';
 } else {
 paymentStatus = isArabic ? 'مدفوع بالكامل نقداً بالملعب' : 'Paid in full cash at pitch';
 }
 } else if (safeDeposit > 0) {
 paymentStatus = isArabic
 ? 'عربون مسدد: ${safeDeposit.toStringAsFixed(2)} ج.م (المتبقي: ${remainingAmount.toStringAsFixed(2)} ج.م عند الحضور)'
 : 'Deposit: ${safeDeposit.toStringAsFixed(2)} EGP (Remaining: ${remainingAmount.toStringAsFixed(2)} EGP upon arrival)';
 } else {
 paymentStatus = isArabic
 ? 'الدفع عند الملعب: ${safeTotal.toStringAsFixed(2)} ج.م'
 : 'Payment at pitch: ${safeTotal.toStringAsFixed(2)} EGP';
 }

 if (isArabic) {
 return '''
 *وصل تأكيد حجز ملعب — VSP* 

 *الملعب:* $stadiumName
 *الكابتن:* $customerName
 *التاريخ:* $dateStr
 *الميعاد:* $timeStr
 *الإجمالي:* ${safeTotal.toStringAsFixed(2)} ج.م ($paymentStatus)
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
 *Total:* ${safeTotal.toStringAsFixed(2)} EGP ($paymentStatus)
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
