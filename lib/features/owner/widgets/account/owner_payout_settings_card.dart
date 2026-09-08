import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/components/vsp_card.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../shared/widgets/custom_text_field.dart';

class OwnerPayoutSettingsCard extends StatefulWidget {
  final TextEditingController instapayController;
  final TextEditingController vodafoneController;
  final TextEditingController bankController;

  const OwnerPayoutSettingsCard({
    super.key,
    required this.instapayController,
    required this.vodafoneController,
    required this.bankController,
  });

  @override
  State<OwnerPayoutSettingsCard> createState() => _OwnerPayoutSettingsCardState();
}

class _OwnerPayoutSettingsCardState extends State<OwnerPayoutSettingsCard> {
  Widget _buildInputLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: VSPSpacing.xs, left: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: VSPCard(
        padding: const EdgeInsets.all(VSPSpacing.md),
        margin: EdgeInsets.zero,
        color: VSPColors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Iconsax.wallet_1_copy, color: VSPColors.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isArabic ? 'بيانات استلام المستحقات والتسويات المالية ' : 'Payout & Settlement Method',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: VSPColors.accent,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isArabic
                  ? 'تستخدم هذه البيانات من قبل إدارة المنصة VSP لتحويل أرباح ومستحقات حجز ملاعبك إليك بشكل دوري.'
                  : 'This data is used by VSP Admin to disburse your stadium booking payouts.',
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 16),
            _buildInputLabel(
              context,
              isArabic ? ' عنوان إنستا باي (InstaPay IPN / Phone)' : ' InstaPay IPN / Phone',
            ),
            CustomTextField(
              controller: widget.instapayController,
              hintText: isArabic ? 'أدخل عنوان إنستا باي أو الهاتف' : 'Enter InstaPay IPN or phone number',
              suffixIcon: widget.instapayController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Iconsax.close_circle_copy, size: 16),
                      onPressed: () => setState(() => widget.instapayController.clear()),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            _buildInputLabel(
              context,
              isArabic ? ' رقم المحفظة الإلكترونية (فودافون كاش / اتصالات / أورنج)' : ' Mobile Wallet Number',
            ),
            CustomTextField(
              controller: widget.vodafoneController,
              hintText: isArabic ? 'أدخل رقم المحفظة' : 'Enter wallet phone number',
              keyboardType: TextInputType.phone,
              suffixIcon: widget.vodafoneController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Iconsax.close_circle_copy, size: 16),
                      onPressed: () => setState(() => widget.vodafoneController.clear()),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            _buildInputLabel(
              context,
              isArabic ? ' الحساب البنكي / المستفيد (IBAN & Holder)' : ' Bank Account Number / IBAN',
            ),
            CustomTextField(
              controller: widget.bankController,
              hintText: isArabic ? 'أدخل تفاصيل الحساب واسم المستفيد' : 'Enter Bank Account/IBAN and Holder Name',
              suffixIcon: widget.bankController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Iconsax.close_circle_copy, size: 16),
                      onPressed: () => setState(() => widget.bankController.clear()),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
