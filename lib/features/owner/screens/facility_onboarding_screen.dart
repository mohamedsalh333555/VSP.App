import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/database_service.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../data/models.dart';
import 'add_stadium_wizard.dart';
import 'owner_documentation_wizard.dart';
import '../../../core/utils/vsp_feedback.dart';

/// شاشة تسجيل بيانات المنشأة - للمالك فقط
/// تعرض الملاعب المضافة وتتحكم في زر التأكيد
class FacilityOnboardingScreen extends StatefulWidget {
  const FacilityOnboardingScreen({super.key});

  @override
  State<FacilityOnboardingScreen> createState() => _FacilityOnboardingScreenState();
}

class _FacilityOnboardingScreenState extends State<FacilityOnboardingScreen> {
  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: VSPColors.background,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              VSPColors.accent.withValues(alpha: 0.05),
              VSPColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.lg),
            child: StreamBuilder<List<Stadium>>(
              stream: DatabaseService().getOwnerStadiums(uid),
              builder: (context, snapshot) {
                final stadiums = snapshot.data ?? [];
                final hasStadiums = stadiums.isNotEmpty;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),

                    // Icon Illustration
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: VSPColors.accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.stadium_rounded,
                        size: 52,
                        color: VSPColors.accent,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Title
                    Text(
                      languageProvider.getText(AppStrings.facilityDetails),
                      style: Theme.of(context).textTheme.displayLarge,
                    ),

                    const SizedBox(height: 12),

                    // Subtitle
                    Text(
                      languageProvider.isArabic
                          ? 'أضف ملعبك الأول وقم بتوثيق حسابك للبدء في استقبال الحجوزات'
                          : 'Add your stadium and verify your account to start receiving bookings.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
                    ),

                    const SizedBox(height: 24),

                    // === Added Stadiums List ===
                    if (hasStadiums) ...[
                      // Section header
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: VSPColors.accent, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            languageProvider.isArabic
                                ? 'ملاعبك المضافة (${stadiums.length})'
                                : 'Your Stadiums (${stadiums.length})',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: stadiums.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            return _buildMiniStadiumCard(stadiums[index]);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (!hasStadiums && snapshot.connectionState == ConnectionState.active) ...[
                      // Empty state hint
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: VSPColors.surface,
                          borderRadius: BorderRadius.circular(VSPRadius.md),
                          border: Border.all(
                            color: VSPColors.accent.withValues(alpha: 0.1),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.add_home_work_outlined,
                                color: Colors.white.withValues(alpha: 0.15), size: 48),
                            const SizedBox(height: 12),
                            Text(
                              languageProvider.isArabic
                                  ? 'لم تقم بإضافة أي ملعب بعد'
                                  : 'No stadiums added yet',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    const Spacer(),

                    // Buttons Container
                    Column(
                      children: [
                        // Add Stadium Button — always active
                        _OnboardingButton(
                          title: languageProvider.isArabic ? 'إضافة ملعب' : 'Add Stadium',
                          subtitle: languageProvider.isArabic
                              ? 'سجل بيانات وموقع ملعبك الجديد'
                              : 'Register your new stadium details',
                          icon: Icons.add_home_work_rounded,
                          color: const Color(0xFF233D15),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const AddStadiumWizard()),
                            );
                          },
                        ),

                        const SizedBox(height: 20),

                        // Confirm / Docs Button — disabled if no stadiums
                        _OnboardingButton(
                          title: languageProvider.isArabic ? 'تأكيد الحساب' : 'Confirm & Continue',
                          subtitle: languageProvider.isArabic
                              ? 'رفع المستندات والأوراق الثبوتية'
                              : 'Upload legal documents and ID',
                          icon: Icons.verified_user_rounded,
                          color: hasStadiums ? VSPColors.accent : VSPColors.surface,
                          textColor: hasStadiums ? Colors.black : VSPColors.textSecondary,
                          enabled: hasStadiums,
                          onTap: () async {
                            if (!hasStadiums) {
                              VSPFeedback.showError(
                                context, 
                                languageProvider.isArabic
                                    ? 'يرجى إضافة ملعب أولاً'
                                    : 'Please add a stadium first'
                              );
                              return;
                            }
                            // Set hasStadium flag NOW — user explicitly confirmed
                            await authProvider.updateProfile({'hasStadium': true});
                            if (!context.mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const OwnerDocumentationWizard()),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStadiumCard(Stadium stadium) {
    return VSPCard(
      width: 200,
      padding: const EdgeInsets.all(VSPSpacing.sm),
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          // Stadium Image
          ClipRRect(
            borderRadius: BorderRadius.circular(VSPRadius.md),
            child: Container(
              width: 56,
              height: 56,
              color: VSPColors.background,
              child: stadium.imageUrl.isNotEmpty
                  ? Image.network(
                      stadium.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.stadium,
                        color: VSPColors.accent,
                        size: 28,
                      ),
                    )
                  : const Icon(
                      Icons.stadium,
                      color: VSPColors.accent,
                      size: 28,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Stadium Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  stadium.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 12, color: VSPColors.accent),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        stadium.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'EGP ${stadium.pricePerHour.toStringAsFixed(0)}/hr',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: VSPColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color textColor;
  final bool enabled;
  final VoidCallback onTap;

  const _OnboardingButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.textColor = Colors.white,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: enabled ? 1.0 : 0.6,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.lg),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(VSPRadius.xl),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.15),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: textColor, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(color: textColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: textColor.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: textColor.withValues(alpha: 0.5), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
