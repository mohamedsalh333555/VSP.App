import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../../../core/utils/vsp_quick_booking_receipt_formatter.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../data/models.dart';

class QuickPhoneBookingModal extends StatefulWidget {
 final Stadium stadium;
 final DateTime date;
 final String slotTime; // e.g. "08:00 PM - 09:00 PM"
 final DateTime startTime;
 final DateTime endTime;
 final double defaultPrice;

 const QuickPhoneBookingModal({
 super.key,
 required this.stadium,
 required this.date,
 required this.slotTime,
 required this.startTime,
 required this.endTime,
 required this.defaultPrice,
 });

 static Future<bool?> show(
 BuildContext context, {
 required Stadium stadium,
 required DateTime date,
 required String slotTime,
 required DateTime startTime,
 required DateTime endTime,
 required double defaultPrice,
 }) {
 return showModalBottomSheet<bool>(
 context: context,
 isScrollControlled: true,
 useSafeArea: true,
 backgroundColor: Colors.transparent,
 builder: (_) => QuickPhoneBookingModal(
 stadium: stadium,
 date: date,
 slotTime: slotTime,
 startTime: startTime,
 endTime: endTime,
 defaultPrice: defaultPrice,
 ),
 );
 }

 @override
 State<QuickPhoneBookingModal> createState() => _QuickPhoneBookingModalState();
}

class _QuickPhoneBookingModalState extends State<QuickPhoneBookingModal> {
 final _customerNameController = TextEditingController();
 final _phoneController = TextEditingController();
 final _priceController = TextEditingController();
 final _depositController = TextEditingController(text: '0');

 bool _isSaving = false;

 @override
 void initState() {
 super.initState();
 _priceController.text = widget.defaultPrice.toInt().toString();
 }

 @override
 void dispose() {
 _customerNameController.dispose();
 _phoneController.dispose();
 _priceController.dispose();
 _depositController.dispose();
 super.dispose();
 }

 Future<void> _handleQuickBooking() async {
 final customerName = _customerNameController.text.trim();
 final phone = _phoneController.text.trim();
 final price = double.tryParse(_priceController.text.trim()) ?? widget.defaultPrice;
 final deposit = double.tryParse(_depositController.text.trim()) ?? 0.0;

 if (customerName.isEmpty) {
 HapticFeedback.vibrate();
 final isAr = Localizations.localeOf(context).languageCode == 'ar';
 VSPFeedback.showError(context, isAr ? 'يرجى كتابة اسم العميل (مثال: كابتن زياد)' : 'Please enter customer name');
 return;
 }

 setState(() => _isSaving = true);
 HapticFeedback.mediumImpact();

 try {
 final authProvider = Provider.of<AuthProvider>(context, listen: false);
 final ownerId = authProvider.currentUser?.uid ?? widget.stadium.ownerId;
 final isAr = Localizations.localeOf(context).languageCode == 'ar';

 final bookingRef = 'MAN_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

 final newBooking = {
 'stadium_id': widget.stadium.id,
 'stadium_name': widget.stadium.name,
 'owner_id': ownerId,
 'created_by_user_id': ownerId,
 'host_name': customerName,
 'customer_phone': phone.isNotEmpty ? phone : null,
 'start_time': widget.startTime.toUtc().toIso8601String(),
 'end_time': widget.endTime.toUtc().toIso8601String(),
 'operational_date': AppDateFormatter.getOperationalDate(widget.date).toUtc().toIso8601String(),
 'status': 'confirmed',
 'is_paid': deposit >= price && price > 0,
 'payment_status': deposit >= price && price > 0 ? 'paid' : (deposit > 0 ? 'deposit_paid' : 'pending'),
 'payment_method': 'cash',
 'total_price': price,
 'deposit_paid': deposit,
 'booking_type': 'personal',
 'is_private': true,
 'payment_transaction_id': 'MANUAL_PHONE_$bookingRef',
 'created_at': DateTime.now().toUtc().toIso8601String(),
 'updated_at': DateTime.now().toUtc().toIso8601String(),
 };

 final response = await Supabase.instance.client
 .from('bookings')
 .insert(newBooking)
 .select()
 .single();

 final createdBookingId = response['id']?.toString() ?? bookingRef;

 if (!mounted) return;
 HapticFeedback.lightImpact();

 // Show instant WhatsApp receipt action sheet
 Navigator.pop(context, true);

 _showReceiptActionDialog(
 context: context,
 bookingRef: createdBookingId.length >= 8 ? createdBookingId.substring(0, 8).toUpperCase() : createdBookingId,
 customerName: customerName,
 customerPhone: phone,
 totalPrice: price,
 depositPaid: deposit,
 isAr: isAr,
 );
 } catch (e) {
 if (mounted) {
 setState(() => _isSaving = false);
 final err = e.toString().toLowerCase();
 final isAr = Localizations.localeOf(context).languageCode == 'ar';
 if (err.contains('prevent_double_booking') || err.contains('duplicate')) {
 VSPFeedback.showError(context, isAr ? 'هذا الموعد تم حجزه للتو من لاعب آخر ' : 'This slot was just booked by another player ');
 } else {
 VSPFeedback.showError(context, isAr ? 'حدث خطأ أثناء حفظ الحجز' : 'Failed to save phone booking');
 }
 }
 }
 }

 void _showReceiptActionDialog({
 required BuildContext context,
 required String bookingRef,
 required String customerName,
 required String customerPhone,
 required double totalPrice,
 required double depositPaid,
 required bool isAr,
 }) {
 final receiptMsg = VSPQuickBookingReceiptFormatter.buildReceiptMessage(
 stadiumName: widget.stadium.name,
 bookingRef: bookingRef,
 customerName: customerName,
 startTime: widget.startTime,
 endTime: widget.endTime,
 totalPrice: totalPrice,
 depositPaid: depositPaid,
 googleMapsUrl: widget.stadium.googleMapsUrl,
 stadiumPhone: widget.stadium.phone,
 isArabic: isAr,
 );

 showModalBottomSheet(
 context: context,
 backgroundColor: VSPColors.surface,
 shape: const RoundedRectangleBorder(
 borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
 ),
 builder: (sheetCtx) {
 return Padding(
 padding: const EdgeInsets.all(VSPSpacing.lg),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(Iconsax.tick_circle_copy, color: VSPColors.accent, size: 48),
 const SizedBox(height: 12),
 Text(
 isAr ? 'تم تسجيل الحجز بنجاح! ' : 'Booking Confirmed! ',
 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
 ),
 const SizedBox(height: 6),
 Text(
 isAr 
 ? 'تم حجز موعد (${widget.slotTime}) للكابتن $customerName'
 : 'Slot (${widget.slotTime}) booked for $customerName',
 style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
 textAlign: TextAlign.center,
 ),
 const SizedBox(height: 20),

 // WhatsApp Receipt Button
 PrimaryButton(
 text: isAr ? 'إرسال وصل الحجز لواتساب العميل ' : 'Send Receipt to Customer WhatsApp ',
 height: 50,
 color: const Color(0xFF25D366),
 textColor: Colors.white,
 onPressed: () async {
 Navigator.pop(sheetCtx);
 await VSPQuickBookingReceiptFormatter.sendReceiptToCustomer(
 context: context,
 phone: customerPhone,
 receiptMessage: receiptMsg,
 );
 },
 ),
 const SizedBox(height: 10),

 TextButton(
 onPressed: () => Navigator.pop(sheetCtx),
 child: Text(
 isAr ? 'تم / إغلاق' : 'Done / Close',
 style: const TextStyle(color: VSPColors.textSecondary),
 ),
 ),
 ],
 ),
 );
 },
 );
 }

 @override
 Widget build(BuildContext context) {
 final isAr = Localizations.localeOf(context).languageCode == 'ar';
 final dateStr = AppDateFormatter.formatDayMonth(widget.date, isAr ? 'ar' : 'en');

 return Padding(
 padding: EdgeInsets.only(
 bottom: MediaQuery.of(context).viewInsets.bottom,
 ),
 child: Container(
 padding: const EdgeInsets.all(VSPSpacing.lg),
 decoration: const BoxDecoration(
 color: VSPColors.surface,
 borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
 ),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Center(
 child: Container(
 width: 40,
 height: 4,
 decoration: BoxDecoration(
 color: VSPColors.divider,
 borderRadius: BorderRadius.circular(2),
 ),
 ),
 ),
 const SizedBox(height: 16),

 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Row(
 children: [
 const Icon(Iconsax.call_calling_copy, color: VSPColors.accent, size: 22),
 const SizedBox(width: 8),
 Text(
 isAr ? 'حجز تليفوني سريع (5 ثوانٍ) ' : 'Quick Phone Booking ',
 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
 ),
 ],
 ),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: VSPColors.accent.withValues(alpha: 0.15),
 borderRadius: BorderRadius.circular(VSPRadius.full),
 ),
 child: Text(
 widget.slotTime,
 style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 11),
 ),
 ),
 ],
 ),
 const SizedBox(height: 6),
 Text(
 isAr ? 'الملعب: ${widget.stadium.name} • التاريخ: $dateStr' : '${widget.stadium.name} • $dateStr',
 style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
 ),
 const SizedBox(height: 16),

 // Customer Name
 CustomTextField(
 controller: _customerNameController,
 hintText: isAr ? 'اسم الكابتن (مثال: كابتن زياد) *' : 'Captain Name (e.g. Ziad) *',
 prefixIcon: Iconsax.user_copy,
 autofocus: true,
 ),
 const SizedBox(height: 12),

 // Customer Phone
 CustomTextField(
 controller: _phoneController,
 hintText: isAr ? 'رقم الواتساب (لإرسال الوصل فورا)' : 'WhatsApp Phone (for receipt)',
 prefixIcon: Iconsax.call_copy,
 keyboardType: TextInputType.phone,
 ),
 const SizedBox(height: 12),

 // Price & Deposit in one row
 Row(
 children: [
 Expanded(
 child: CustomTextField(
 controller: _priceController,
 hintText: isAr ? 'السعر المطلوب (ج.م)' : 'Price (EGP)',
 prefixIcon: Iconsax.money_copy,
 keyboardType: TextInputType.number,
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: CustomTextField(
 controller: _depositController,
 hintText: isAr ? 'العربون المسدد (ج.م)' : 'Deposit (EGP)',
 prefixIcon: Iconsax.wallet_check_copy,
 keyboardType: TextInputType.number,
 ),
 ),
 ],
 ),
 const SizedBox(height: 20),

 // Submit Button
 PrimaryButton(
 text: isAr ? 'تأكيد الحجز الفوري ' : 'Confirm Instant Booking ',
 height: 52,
 isLoading: _isSaving,
 onPressed: _handleQuickBooking,
 ),
 const SizedBox(height: 8),
 ],
 ),
 ),
 );
 }
}
