import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'booking_sheet_form_fields.dart';

/// Form section containing customer name, phone, notes, and collected cash amount.
class BookingSheetDetailsForm extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController noteController;
  final TextEditingController collectedAmountController;
  final bool isReadOnly;
  final bool isArabic;
  final String customerNameLabel;
  final String internalNotesLabel;

  const BookingSheetDetailsForm({
    super.key,
    required this.nameController,
    required this.phoneController,
    required this.noteController,
    required this.collectedAmountController,
    required this.isReadOnly,
    required this.isArabic,
    required this.customerNameLabel,
    required this.internalNotesLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InputLabel(customerNameLabel),
        PillTextField(
          controller: nameController,
          hint: isArabic ? 'اسم الفريق / اللاعب' : 'Customer / Team Name',
          keyboardType: TextInputType.name,
          enabled: !isReadOnly,
        ),
        const SizedBox(height: 14),
        InputLabel(isArabic ? "رقم الهاتف" : "Phone Number"),
        PillTextField(
          controller: phoneController,
          hint: isArabic ? "رقم الهاتف (اختياري)" : "Phone Number (Optional)",
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          enabled: !isReadOnly,
        ),
        const SizedBox(height: 14),
        InputLabel(internalNotesLabel),
        PillTextField(
          controller: noteController,
          hint: isArabic ? 'أدخل أي ملاحظات إضافية عن الحجز...' : 'Enter internal notes...',
          keyboardType: TextInputType.text,
          enabled: !isReadOnly,
        ),
        const SizedBox(height: 14),
        InputLabel(isArabic ? "المبلغ المحصل (ج.م)" : "Collected Amount (EGP)"),
        PillTextField(
          controller: collectedAmountController,
          hint: isArabic ? "أدخل المبلغ المحصل (0 للإيجار غير المدفوع)" : "Enter amount (0 for unpaid)",
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
          enabled: !isReadOnly,
        ),
      ],
    );
  }
}
