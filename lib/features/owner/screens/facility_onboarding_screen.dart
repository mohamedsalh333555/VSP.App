import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/stadium_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../data/models.dart';
import 'add_stadium_wizard.dart';
import 'owner_documentation_wizard.dart';
import '../../../shared/widgets/stadium_card.dart';

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

    return Scaffold(
      backgroundColor: VSPColors.background,
      body: SafeArea(
        child: StreamBuilder<List<Stadium>>(
            stream: StadiumRepository().getOwnerStadiums(uid),
            builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text(isAr ? 'حد خطأ في تحميل المافإ' : 'Error loading stadiums', style: const TextStyle(color: VSPColors.error)));
                  }
                  final stadiums = snapshot.data ?? [];
              final hasStadiums = stadiums.isNotEmpty;

              if (!hasStadiums) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    children: [
                      const Spacer(),
                      Text(
                        isAr ? 'ستظهر جميع ملاعبك هنا.' : 'All your stadiums will appear here.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: VSPColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isAr ? 'أضف ملعبك الأول للبدء' : 'Add your first stadium to start',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: VSPColors.textSecondary, fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity, height: 56,
                        child: ElevatedButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddStadiumWizard())),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: VSPColors.accent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
                          ),
                          child: Text(isAr ? 'إضافة ملعب' : 'Add stadium', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              }

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      isAr ? 'ملاعبك المضافة' : 'Your Stadiums',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: VSPColors.textPrimary, fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 💡 ملاحظة المعاينة
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: VSPColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.lightbulb, color: VSPColors.accent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isAr ? 'هكذا ستظهر ملاعبك وتفاصيلها أمام اللاعبين في التطبيق.' : 'This is how your stadiums will appear to players.',
                              style: const TextStyle(color: VSPColors.accent, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: stadiums.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        return AbsorbPointer( // نمنع الضغط هنا لأنها للمعاينة
                          child: StadiumCard(
                            stadium: stadiums[index],
                            isOwnerView: false, // لكي تظهر بتصميم اللاعبين بالضبط!
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity, height: 56,
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddStadiumWizard())),
                            icon: const Icon(LucideIcons.plusCircle, color: Colors.white),
                            label: Text(isAr ? 'إضافة ملعب آخر' : 'Add another stadium', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: VSPColors.surfaceAlt,
                              foregroundColor: Colors.white,
                              side: BorderSide(color: VSPColors.divider),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity, height: 56,
                          child: ElevatedButton(
                            onPressed: () async {
                              final updatedAdditional = Map<String, dynamic>.from(authProvider.userModel?.additionalData ?? {})..['isOnboardingConfirmed'] = true;
                              await authProvider.updateProfile({'hasStadium': true, 'additionalData': updatedAdditional});
                              if (!context.mounted) return;
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerDocumentationWizard()));
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: VSPColors.accent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
                            ),
                            child: Text(isAr ? 'متابعة لرفع الوثائق' : 'Continue to Upload Docs', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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