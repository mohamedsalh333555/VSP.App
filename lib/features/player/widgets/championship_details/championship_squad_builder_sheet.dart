import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/repositories/team_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../screens/championship_checkout_screen.dart';
import '../create_team_sheet.dart';

/// يعرض نافذة توجيه الكابتن عند نقص عدد لاعبي الفريق عن الحد الأدنى (5 لاعبين)
Future<void> showIncompleteSquadBridgeSheet({
  required BuildContext context,
  required Team? team,
  required Championship championship,
}) async {
  final isArabic = Localizations.localeOf(context).languageCode == 'ar';
  final int currentCount = team?.memberUids.length ?? 0;
  final int missingCount = (5 - currentCount).clamp(1, 5);

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      return Container(
        padding: const EdgeInsets.all(VSPSpacing.lg),
        decoration: const BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(VSPRadius.xl),
            topRight: Radius.circular(VSPRadius.xl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: VSPColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Iconsax.people_copy, color: VSPColors.accent, size: 24),
                const SizedBox(width: 10),
                Text(
                  isArabic ? 'استكمال تشكيلة البطولة ' : 'Tournament Squad Builder ',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VSPColors.background,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.info_circle_copy, color: VSPColors.accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      team == null
                          ? (isArabic
                              ? 'يجب إنشاء فريقك أولاً للتمكن من الاشتراك في البطولة.'
                              : 'You need to create a team first to join tournaments.')
                          : (isArabic
                              ? 'ينقص فريقك [$missingCount] لاعبين للمشاركة في البطولة (الحد الأدنى 5 لاعبين).'
                              : 'Your team needs [$missingCount] more players to meet the 5-player minimum.'),
                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (team == null) ...[
              PrimaryButton(
                text: isArabic ? 'إنشاء فريق الآن في ثوانٍ ' : 'Create Team Now in Seconds ',
                color: VSPColors.accent,
                textColor: Colors.black,
                onPressed: () async {
                  Navigator.pop(sheetCtx);
                  final created = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => const CreateTeamSheet(),
                  );
                  if (created == true && context.mounted) {
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    final newTeam = await TeamRepository().getUserTeam(auth.currentUser!.uid);
                    if (newTeam != null && context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => ChampionshipCheckoutScreen(
                            championship: championship,
                            team: newTeam,
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            ] else ...[
              PrimaryButton(
                text: isArabic ? 'متابعة وإضافة أسماء اللاعبين الضيوف ' : 'Continue & Add Guest Players ',
                color: VSPColors.accent,
                textColor: Colors.black,
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => ChampionshipCheckoutScreen(
                        championship: championship,
                        team: team,
                      ),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 10),
          ],
        ),
      );
    },
  );
}
