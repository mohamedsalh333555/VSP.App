import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/egypt_governorates.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/vsp_fade_in_item.dart';
import '../../screens/championship_details_screen.dart';
import '../../screens/player_home_screen.dart';

class ChampionshipsListTab extends StatelessWidget {
  final Stream<List<Championship>> championshipsStream;
  final String selectedLocation;
  final ValueChanged<String> onLocationChanged;
  final VoidCallback onRetry;

  const ChampionshipsListTab({
    super.key,
    required this.championshipsStream,
    required this.selectedLocation,
    required this.onLocationChanged,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userGovRaw = auth.userModel?.governorate ?? auth.governorate;
    final userGov = EgyptGovernorates.resolveGoogleName(userGovRaw) ?? userGovRaw;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isDifferentGov = userGov.isNotEmpty && selectedLocation.toLowerCase() != userGov.toLowerCase();

    return StreamBuilder<List<Championship>>(
      stream: championshipsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
        }
        if (snapshot.hasError && (!snapshot.hasData || snapshot.data!.isEmpty)) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.refresh, color: VSPColors.warning, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    isArabic
                        ? 'تعذر التحديث اللحظي، اسحب للأسفل للتحديث'
                        : 'Realtime update unavailable, pull to refresh',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, color: VSPColors.accent, size: 16),
                    label: Text(
                      isArabic ? 'إعادة المحاولة' : 'Retry',
                      style: const TextStyle(color: VSPColors.accent, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final championships = snapshot.data ?? [];

        return Column(
          children: [
            // Quick return banner if browsing a different governorate
            if (isDifferentGov)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: VSPColors.surface,
                  borderRadius: BorderRadius.circular(VSPRadius.lg),
                  border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.location_copy, color: VSPColors.accent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isArabic ? 'تتصفح بطولات: $selectedLocation' : 'Viewing: $selectedLocation',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    InkWell(
                      onTap: () => onLocationChanged(userGov),
                      borderRadius: BorderRadius.circular(VSPRadius.sm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          isArabic ? 'بطولاتي ($userGov)' : 'My City ($userGov)',
                          style: const TextStyle(color: VSPColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Content List
            Expanded(
              child: championships.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Iconsax.cup_copy, color: Colors.white.withValues(alpha: 0.1), size: 64),
                            const SizedBox(height: 16),
                            Text(
                              AppLocalizations.of(context)!.noChampionshipsInLoc(selectedLocation),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
                            ),
                            if (isDifferentGov) ...[
                              const SizedBox(height: 16),
                              PrimaryButton(
                                text: isArabic ? 'العودة لبطولات $userGov' : 'Return to $userGov Tournaments',
                                height: 44,
                                onPressed: () => onLocationChanged(userGov),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: VSPScrollPadding.forList(
                        context,
                        hasFloatingNavBar: true,
                        horizontal: 0,
                        top: isDifferentGov ? 0 : 16,
                      ),
                      physics: const BouncingScrollPhysics(),
                      itemCount: championships.length,
                      itemBuilder: (context, index) {
                        final championship = championships[index];
                        return VSPFadeInItem(
                          index: index,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChampionshipDetailsScreen(championship: championship),
                                  ),
                                );
                              },
                              child: ChampionshipCard(championship: championship),
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
