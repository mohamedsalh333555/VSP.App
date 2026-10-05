import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../ui/tokens/vsp_design_tokens.dart';

class VSPFeedback {

 // ─── نظام الألوان الموحد للتنبيهات اللحظية ───
 // أخضر = نجاح (VSPDSSemanticColors.accent)
 // أحمر = خطأ (VSPDSSemanticColors.error)
 // برتقالي = تحذير (VSPDSSemanticColors.warning / Orange)
 // أبيض = معلومة (VSPDSColors.white / textPrimary)

 /// نجاح
 static void showSuccess(BuildContext context, String message) {
 HapticFeedback.lightImpact();
 _showOverlayToast(
 context: context,
 message: message,
 backgroundColor: VSPDSSemanticColors.accent,
 textColor: VSPDSColors.black,
 icon: Iconsax.tick_circle_copy,
 );
 }

 /// خطأ — مع تنظيف تلقائي للرسالة من prefixes الـ DB
 static void showError(BuildContext context, String rawMessage) {
 HapticFeedback.heavyImpact();
 final message = _cleanErrorMessage(context, rawMessage);
 _showOverlayToast(
 context: context,
 message: message,
 backgroundColor: VSPDSSemanticColors.error,
 textColor: VSPDSVSPDSColors.white,
 icon: Iconsax.warning_2_copy,
 );
 }

 /// تحذير
 static void showWarning(BuildContext context, String message) {
 HapticFeedback.mediumImpact();
 _showOverlayToast(
 context: context,
 message: message,
 backgroundColor: VSPDSSemanticColors.warning,
 textColor: VSPDSColors.white,
 icon: Iconsax.warning_2_copy,
 );
 }

 /// معلومة
 static void showInfo(BuildContext context, String message) {
 _showOverlayToast(
 context: context,
 message: message,
 backgroundColor: VSPDSSemanticColors.surface,
 textColor: VSPDSColors.white,
 icon: Iconsax.info_circle_copy,
 );
 }

 static void triggerSuccess() {
 HapticFeedback.lightImpact();
 }

 static void triggerTap() {
 HapticFeedback.selectionClick();
 }

 /// تنظيف رسائل الخطأ الخام من DB ومع localization تلقائي
 static String _cleanErrorMessage(BuildContext context, String raw) {
 final isAr = Localizations.localeOf(context).languageCode == 'ar';
 String msg = raw
 .replaceAll('Failed to create booking: ', '')
 .replaceAll('Exception: ', '')
 .replaceAll('PostgrestException', '')
 .replaceAll('(message:', '')
 .replaceAll('hint: null)', '')
 .trim();

 // ترجمة رسائل double booking الشائعة
 if (msg.contains('double booking') || msg.contains('time_conflict') || msg.contains('تحجز نفس الوقت')) {
 return isAr
 ? 'هذا الوقت محجوز بالفعل. يرجى اختيار وقت آخر.'
 : 'This time slot is already booked. Please choose another.';
 }
 if (msg.contains('cash limit') || msg.contains('حد الكاش')) {
 return isAr
 ? 'تجاوزت حد الحجوزات النقدية المسموح بها. يرجى سداد الحجوزات السابقة أولاً.'
 : 'Cash booking limit reached. Please pay for previous bookings first.';
 }

 return msg.isNotEmpty ? msg : (isAr ? 'حدث خطأ غير متوقع.' : 'An unexpected error occurred.');
 }

 /// المحرك المركزي لإظهار التنبيهات بـ Root Overlay فوق جميع الطبقات والبوب اب
 static void _showOverlayToast({
 required BuildContext context,
 required String message,
 required Color backgroundColor,
 required Color textColor,
 required IconData icon,
 }) {
 try {
 final overlay = Overlay.of(context, rootOverlay: true);
 late OverlayEntry entry;

 entry = OverlayEntry(
 builder: (ctx) => Positioned(
 top: MediaQuery.of(ctx).padding.top + VSPDSSpacing.sm,
 left: VSPDSSpacing.md,
 right: VSPDSSpacing.md,
 child: Material(
 color: Colors.transparent,
 child: TweenAnimationBuilder<double>(
 tween: Tween(begin: 0.0, end: 1.0),
 duration: VSPDSFeedback.enter,
 curve: Curves.easeOutBack,
 builder: (ctx, value, child) {
 return Transform.translate(
 offset: Offset(0, (1 - value) * -20),
 child: Opacity(
 opacity: value.clamp(0.0, 1.0),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: VSPDSFeedback.horizontalInset, vertical: VSPDSFeedback.verticalInset),
 decoration: BoxDecoration(
 color: backgroundColor,
 borderRadius: BorderRadius.circular(VSPDSFeedback.cornerRadius),
 boxShadow: const [
 BoxShadow(
   color: Color(0x61000000),
   blurRadius: VSPDSFeedback.shadowBlur,
   offset: Offset(0, VSPDSFeedback.shadowOffsetY),
 ),
 ],
 ),
 child: Row(
 children: [
 Icon(icon, color: textColor, size: VSPDSFeedback.icon),
 const SizedBox(width: 12),
 Expanded(
 child: Text(
 message,
 style: TextStyle(
 color: textColor,
 fontWeight: FontWeight.w700,
 fontSize: VSPDSTypography.bodyMedium.fontSize,
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 );
 },
 ),
 ),
 ),
 );

 // إدراج التنبيه في أعلى طبقة بالـ Navigator
 overlay.insert(entry);

 // إخفاء التنبيه أوتوماتيكياً بعد 3 ثوانٍ
 Future.delayed(VSPDSFeedback.dismiss, () {
 if (entry.mounted) {
 entry.remove();
 }
 });
 } catch (e) {
 // السقوط الخلفي للـ SnackBar الإعتيادي في حال عدم توفر Overlay
 ScaffoldMessenger.of(context).hideCurrentSnackBar();
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(message, style: VSPDSTypography.bodyMedium.copyWith(color: textColor, fontWeight: FontWeight.w700)),
 backgroundColor: backgroundColor,
 behavior: SnackBarBehavior.floating,
 ),
 );
 }
 }
}
