import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/constants/egypt_governorates.dart';
import '../../../../shared/widgets/custom_text_field.dart';

class OwnerProfileForm extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController socialController;
  final String? governorate;
  final bool isLocating;
  final VoidCallback onUpdateLocation;

  const OwnerProfileForm({
    super.key,
    required this.nameController,
    required this.phoneController,
    required this.emailController,
    required this.socialController,
    required this.governorate,
    required this.isLocating,
    required this.onUpdateLocation,
  });

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputLabel(context, isArabic ? 'اسم المالك' : 'Owner Name'),
          CustomTextField(controller: nameController, hintText: isArabic ? 'أدخل اسمك' : 'Enter your name'),
          const SizedBox(height: 16),
          _buildInputLabel(context, isArabic ? 'رقم الهاتف' : 'Phone Number'),
          CustomTextField(
            controller: phoneController,
            hintText: isArabic ? 'أدخل رقم هاتفك' : 'Enter your phone',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          _buildInputLabel(context, isArabic ? 'البريد الإلكتروني' : 'Email Address'),
          CustomTextField(
            controller: emailController,
            hintText: isArabic ? 'أدخل بريدك الإلكتروني' : 'Enter your email',
            suffixIcon: const Icon(Iconsax.lock_copy, size: 18, color: VSPColors.textSecondary),
          ),
          const SizedBox(height: 16),
          _buildInputLabel(context, isArabic ? 'الموقع' : 'Location'),
          Container(
            padding: const EdgeInsets.all(VSPSpacing.md),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.md),
              border: Border.all(color: VSPColors.divider.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const Icon(Iconsax.location_copy, color: VSPColors.accent, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'المحافظة الحالية' : 'Current Governorate',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                      ),
                      Text(
                        governorate != null && isArabic
                            ? EgyptGovernorates.getArabicName(governorate!)
                            : (governorate ?? (isArabic ? 'غير محدد' : 'Not set')),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                isLocating
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.accent),
                      )
                    : IconButton(
                        icon: const Icon(Iconsax.gps_copy, color: VSPColors.accent),
                        onPressed: onUpdateLocation,
                      ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildInputLabel(context, isArabic ? 'روابط التواصل الاجتماعي' : 'Social media'),
          CustomTextField(
            controller: socialController,
            hintText: isArabic ? 'أدخل رابط التواصل الاجتماعي' : 'Enter social media link',
          ),
        ],
      ),
    );
  }
}
