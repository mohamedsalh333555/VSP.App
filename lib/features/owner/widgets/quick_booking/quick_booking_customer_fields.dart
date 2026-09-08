import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../shared/widgets/custom_text_field.dart';

class QuickBookingCustomerFields extends StatelessWidget {
  final TextEditingController customerNameController;
  final TextEditingController phoneController;

  const QuickBookingCustomerFields({
    super.key,
    required this.customerNameController,
    required this.phoneController,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Customer Name
        Text(
          isAr ? 'اسم العميل / الكابتن *' : 'Captain Name *',
          style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        CustomTextField(
          controller: customerNameController,
          hintText: isAr ? 'مثال: كابتن زياد' : 'e.g. Captain Ziad',
          prefixIcon: Iconsax.user_copy,
        ),
        const SizedBox(height: 14),

        // Customer WhatsApp Phone (Optional)
        Text(
          isAr ? 'رقم الواتساب (لإرسال إيصال الحجز)' : 'WhatsApp Phone (for receipt)',
          style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        CustomTextField(
          controller: phoneController,
          hintText: '010xxxxxxxxx',
          prefixIcon: Iconsax.call_copy,
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }
}
