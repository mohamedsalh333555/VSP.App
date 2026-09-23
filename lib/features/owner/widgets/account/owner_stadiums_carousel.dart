import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/stadium_card.dart';
import '../../screens/add_stadium_wizard.dart';
import '../../screens/subscription_plans_screen.dart';

class OwnerStadiumsCarousel extends StatelessWidget {
  final Stream<List<Stadium>> stadiumsStream;

  const OwnerStadiumsCarousel({
    super.key,
    required this.stadiumsStream,
  });

  void _handleAddStadiumTap(BuildContext context, int currentCount) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.userModel;

    final isPro = user?.isProPlan == true;
    final canAddMore = isPro ? currentCount < 3 : currentCount < 1;

    if (canAddMore || currentCount == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AddStadiumWizard(),
        ),
      );
    } else if (!isPro) {
      _showUpgradePlanModal(context, isArabic);
    } else {
      VSPFeedback.showSuccess(
        context,
        isArabic
            ? 'وصلت للحد الأقصى المسموح (3 ملاعب). لتخصيص خطة أعلى تواصل مع الدعم.'
            : 'Maximum 3 stadiums limit reached. Contact support for enterprise plans.',
      );
    }
  }

  void _showUpgradePlanModal(BuildContext context, bool isArabic) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: VSPColors.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: VSPColors.accent, width: 1.5),
                ),
                child: const Icon(Iconsax.crown_copy, color: VSPColors.accent, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                isArabic ? 'ترقية الباقة لإضافة ملاعب أخرى' : 'Upgrade Plan to Add More Stadiums',
                style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(VSPRadius.input),
                  border: Border.all(color: VSPColors.divider),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Iconsax.building_3_copy, color: VSPColors.textSecondary, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isArabic ? 'الباقة الأساسية: ملعب 1 فقط (أول سنة مجاناً)' : 'Basic Plan: 1 Stadium only (1st Year Free)',
                            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: VSPColors.divider, height: 16),
                    Row(
                      children: [
                        const Icon(Iconsax.buildings_copy, color: VSPColors.accent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isArabic ? 'الباقة الاحترافية: حتى 3 ملاعب كاملة (1000 ج.م/شهر)' : 'Pro Plan: Up to 3 Stadiums (1000 EGP/mo)',
                            style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                text: isArabic ? 'عرض الباقات والترقية' : 'View Plans & Upgrade',
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SubscriptionPlansScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(
                  isArabic ? 'إلغاء' : 'Cancel',
                  style: const TextStyle(color: VSPColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddStadiumCard(BuildContext context, int currentCount) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return GestureDetector(
      onTap: () => _handleAddStadiumTap(context, currentCount),
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.xl),
          border: Border.all(
            color: VSPColors.accent.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: VSPColors.accent.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: VSPColors.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: VSPColors.accent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: VSPColors.accent.withValues(alpha: 0.35),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Iconsax.add_circle_copy,
                color: VSPColors.accent,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isArabic ? 'إضافة ملعب آخر' : 'Add Another Stadium',
              style: const TextStyle(
                color: VSPColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            isArabic ? 'الملاعب المسجلة' : 'My Stadiums',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: VSPColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 215,
          child: StreamBuilder<List<Stadium>>(
            stream: stadiumsStream,
            builder: (context, snapshot) {
              final stadiums = snapshot.data ?? [];
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: 0),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: stadiums.length + 1,
                itemBuilder: (context, index) {
                  if (index < stadiums.length) {
                    return Container(
                      width: 260,
                      margin: const EdgeInsets.only(right: VSPSpacing.md),
                      child: StadiumCard(
                        stadium: stadiums[index],
                        isOwnerView: true,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AddStadiumWizard(stadiumId: stadiums[index].id)),
                          );
                        },
                        onEditTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AddStadiumWizard(stadiumId: stadiums[index].id)),
                          );
                        },
                      ),
                    );
                  } else {
                    return Container(
                      width: 240,
                      margin: const EdgeInsets.only(right: VSPSpacing.md),
                      child: _buildAddStadiumCard(context, stadiums.length),
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
