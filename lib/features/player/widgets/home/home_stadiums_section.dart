import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/egypt_governorates.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/stadium_provider.dart';
import '../../../../core/repositories/app_settings_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_launcher_utils.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/stadium_card.dart';
import '../../screens/all_stadiums_screen.dart';
import '../../screens/stadium_details_screen.dart';
import 'home_feed_sections.dart';
import 'home_governorate_modal.dart';

/// قسم الملاعب القريبة في الصفحة الرئيسية (مع معالجة الحالة الفارغة والبديل الجغرافي)
class HomeStadiumsSection extends StatelessWidget {
  const HomeStadiumsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StadiumProvider>(
      builder: (context, provider, _) {
        if (provider.stadiums.isEmpty && !provider.isLoading) {
          final rawCityName = context.read<AuthProvider>().userModel?.governorate ?? 'منطقتك';
          final isAr = AppLocalizations.of(context)!.localeName == 'ar';
          final String cityName = (isAr && rawCityName != 'منطقتك')
              ? (EgyptGovernorates.governorateToArabic[rawCityName] ?? rawCityName)
              : rawCityName;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.xl),
              border: Border.all(color: VSPColors.divider),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Iconsax.location_copy, color: VSPColors.accent.withValues(alpha: 0.3), size: 64),
                const SizedBox(height: 16),
                Text(
                  isAr ? 'لم نصل إلى $cityName بعد! ' : 'We haven\'t reached $cityName yet! ',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  isAr ? 'ولكننا نتوسع بسرعة في جميع المحافظات.' : 'But we are expanding rapidly to all governorates.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: VSPColors.textSecondary,
                        fontSize: 13,
                      ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  text: isAr ? 'اقترح ملعباً في منطقتك ' : 'Suggest a stadium in your area ',
                  onPressed: () async {
                    final message = isAr
                        ? 'مرحباً VSP، أنا من محافظة $cityName وأريد اقتراح إضافة ملاعب في منطقتي!'
                        : 'Hello VSP, I am from $cityName and I want to suggest adding stadiums in my area!';
                    final settings = await AppSettingsRepository().getSettings();
                    final rawPhone = settings.whatsappNumber.isEmpty ? '201100229462' : settings.whatsappNumber;
                    if (context.mounted) {
                      await VSPLauncherUtils.openWhatsApp(context, phone: rawPhone, message: message);
                    }
                  },
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            if (provider.isGeographicFallback) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: VSPColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.info_circle_copy, color: VSPColors.accent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.geographicFallbackBanner,
                        style: const TextStyle(
                          color: VSPColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        showLocationPickerHelper(context, context.read<AuthProvider>());
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: VSPColors.accent,
                          borderRadius: BorderRadius.circular(VSPRadius.sm),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.localeName == 'ar' ? 'تغيير' : 'Change',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            HomeSectionHeader(
              title: AppLocalizations.of(context)!.nearbyStadiums,
              onSeeAll: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AllStadiumsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 240,
              child: provider.isLoading && provider.stadiums.isEmpty
                  ? ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 3,
                      itemBuilder: (_, __) => const CardSkeleton(),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: provider.stadiums.length,
                      itemBuilder: (context, index) {
                        final stadium = provider.stadiums[index];
                        return Container(
                          width: 300,
                          margin: const EdgeInsets.only(right: 6),
                          child: StadiumCard(
                            stadium: stadium,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StadiumDetailsScreen(stadium: stadium),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
