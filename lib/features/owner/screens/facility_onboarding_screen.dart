import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/stadium_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../data/models.dart';
import 'add_stadium_wizard.dart';
import 'owner_documentation_wizard.dart';
import '../../../shared/widgets/stadium_card.dart';

/// شاشة تسجيل بيانات المنشأة - للمالك فقط
/// تعرض الملاعب المضافة وتتحكم في أزرار المعالجة والتأكيد بصرياً
class FacilityOnboardingScreen extends StatefulWidget {
  const FacilityOnboardingScreen({super.key});

  @override
  State<FacilityOnboardingScreen> createState() => _FacilityOnboardingScreenState();
}

class _FacilityOnboardingScreenState extends State<FacilityOnboardingScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.currentUser?.uid ?? '';
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    // Localized texts corresponding directly to mockup screenshot
    final String emptyTitle = isAr ? 'ستظهر جميع ملاعبك هنا.' : 'All your stadiums will appear here.';
    final String emptySubtitle = isAr ? 'أضف ملعبك الآن' : 'Add your stadium now';
    final String addStadiumText = isAr ? 'إضافة ملعب' : 'Add stadium';
    final String completeInfoText = isAr ? 'أكمل بياناتك' : 'Complete your info';
    final String stadiumsText = isAr ? 'الملاعب' : 'Stadiums';
    final String noStadiumError = isAr
        ? 'يجب إضافة ملعب واحد على الأقل قبل المتابعة.'
        : 'Please add at least one stadium before continuing.';

    return Scaffold(
      backgroundColor: VSPColors.background,
      body: SafeArea(
        child: StreamBuilder<List<Stadium>>(
            stream: StadiumRepository().getOwnerStadiums(uid),
            builder: (context, snapshot) {
              final stadiums = snapshot.data ?? [];
              final hasStadiums = stadiums.isNotEmpty;

              if (!hasStadiums) {
                // ==================== EMPTY STATE ====================
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    children: [
                      const Spacer(),
                      // Title
                      Text(
                        emptyTitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: VSPColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Subtitle
                      Text(
                        emptySubtitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: VSPColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      // Add Stadium Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const AddStadiumWizard()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2A4805),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(VSPRadius.xl),
                            ),
                          ),
                          child: Text(
                            addStadiumText,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              }

              // ==================== POPULATED STATE ====================
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),
                    // Header Title
                    Text(
                      stadiumsText,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: VSPColors.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Vertically stacked Stadium Cards
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: stadiums.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        return StadiumCard(
                          stadium: stadiums[index],
                          isOwnerView: true,
                          onEditTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddStadiumWizard(stadiumId: stadiums[index].id),
                              ),
                            );
                          },
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddStadiumWizard(stadiumId: stadiums[index].id),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    // Stacked Action Buttons
                    Column(
                      children: [
                        // 1. Add Stadium Button (Dark Green)
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const AddStadiumWizard()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF152603), // darker green/black
                              foregroundColor: Colors.white,
                              side: BorderSide(color: const Color(0xFF2A4805).withValues(alpha: 0.5)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(VSPRadius.xl),
                              ),
                            ),
                            child: Text(
                              addStadiumText,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // 2. Complete Info / Confirm Button (Neon Green)
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () async {
                              // 🛡️ Guard: ensure at least one stadium was actually saved
                              if (stadiums.isEmpty) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(noStadiumError),
                                    backgroundColor: Colors.red.shade700,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                                return;
                              }
                              // Set hasStadium flag only after verifying a stadium exists
                              await authProvider.updateProfile({'hasStadium': true});
                              if (!context.mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const OwnerDocumentationWizard()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: VSPColors.accent, // bright neon green
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(VSPRadius.xl),
                              ),
                            ),
                            child: Text(
                              completeInfoText,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        ),
    );
  }
}
