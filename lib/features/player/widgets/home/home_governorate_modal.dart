import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/egypt_governorates.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/stadium_provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../l10n/app_localizations.dart';

/// يعرض نافذة منبثقة لاختيار المحافظة يدوياً
void showLocationPickerHelper(BuildContext context, AuthProvider auth) {
  showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: VSPColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      const governorates = EgyptGovernorates.allGovernorates;
      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context)!.selectLocation,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: governorates.length,
                itemBuilder: (context, index) {
                  final gov = governorates[index];
                  final isSelected = auth.userModel?.governorate == gov;
                  return ListTile(
                    leading: Icon(
                      Iconsax.building_copy,
                      color: isSelected ? VSPColors.accent : VSPColors.textSecondary,
                    ),
                    title: Text(
                      gov,
                      style: TextStyle(
                        color: isSelected ? VSPColors.accent : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected ? const Icon(Iconsax.tick_circle_copy, color: VSPColors.accent) : null,
                    onTap: () {
                      auth.updateProfile({'governorate': gov});
                      context.read<StadiumProvider>().applyGovernorateFilter(gov);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// يعرض تنبيهاً للمستخدم إذا كشف الـ GPS عن تغيير محافظته
void showGovernorateChangeAlert(
  BuildContext context,
  AuthProvider auth,
  String newGov,
  StadiumProvider stadiumProvider,
) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      final title = isArabic ? 'تغيير المحافظة تلقائياً ' : 'Change Location ';
      final content = isArabic
          ? 'مرحباً بك في $newGov! لاحظنا أنك انتقلت. هل تود تحديث موقعك لتظهر لك الملاعب والفرق في مكانك الجديد؟'
          : 'Welcome to $newGov! We noticed you moved. Would you like to update your location to see nearby stadiums and teams?';
      final yesBtn = isArabic ? 'تحديث الموقع' : 'Update Location';
      final noBtn = isArabic ? 'لا، شكراً' : 'No, thanks';

      return AlertDialog(
        backgroundColor: VSPColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Row(
          children: [
            const Icon(Iconsax.location_copy, color: VSPColors.accent, size: 28),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          content,
          style: const TextStyle(color: VSPColors.textSecondary, height: 1.5, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              noBtn,
              style: TextStyle(color: VSPColors.textSecondary.withValues(alpha: 0.8), fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await auth.updateProfile({'governorate': newGov});
              stadiumProvider.applyGovernorateFilter(newGov);
              if (context.mounted) {
                VSPFeedback.showSuccess(
                  context,
                  isArabic ? 'تم تحديث موقعك إلى $newGov! ' : 'Location updated to $newGov! ',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: VSPColors.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.sm)),
            ),
            child: Text(yesBtn, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      );
    },
  );
}
