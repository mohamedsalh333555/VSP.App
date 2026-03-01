import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/database_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models.dart';
import 'add_stadium_wizard.dart';
import 'owner_documentation_wizard.dart';

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
      backgroundColor: AppTheme.darkBackground,
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D1B0D),
              AppTheme.darkBackground,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
                        color: AppTheme.neonGreen.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.stadium_rounded,
                        size: 52,
                        color: AppTheme.neonGreen,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Title
                    Text(
                      languageProvider.getText(AppStrings.facilityDetails),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Agency FB',
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Subtitle
                    Text(
                      languageProvider.isArabic
                          ? 'أضف ملعبك الأول وقم بتوثيق حسابك للبدء في استقبال الحجوزات'
                          : 'Add your stadium and verify your account to start receiving bookings.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // === Added Stadiums List ===
                    if (hasStadiums) ...[
                      // Section header
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: AppTheme.neonGreen, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            languageProvider.isArabic
                                ? 'ملاعبك المضافة (${stadiums.length})'
                                : 'Your Stadiums (${stadiums.length})',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
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
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.neonGreen.withValues(alpha: 0.15),
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
                          color: hasStadiums ? AppTheme.neonGreen : Colors.grey[700]!,
                          textColor: hasStadiums ? Colors.black : Colors.white54,
                          enabled: hasStadiums,
                          onTap: () {
                            if (!hasStadiums) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    languageProvider.isArabic
                                        ? 'يرجى إضافة ملعب أولاً'
                                        : 'Please add a stadium first',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  backgroundColor: Colors.red[700],
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                              return;
                            }
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
    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.neonGreen.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Stadium Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 56,
              height: 56,
              color: const Color(0xFF2C2C2C),
              child: stadium.imageUrl.isNotEmpty
                  ? Image.network(
                      stadium.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.stadium,
                        color: AppTheme.neonGreen,
                        size: 28,
                      ),
                    )
                  : const Icon(
                      Icons.stadium,
                      color: AppTheme.neonGreen,
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
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 12, color: AppTheme.neonGreen),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        stadium.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'EGP ${stadium.pricePerHour.toStringAsFixed(0)}/hr',
                  style: const TextStyle(
                    color: AppTheme.neonGreen,
                    fontSize: 12,
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
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(24),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
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
                      style: TextStyle(
                        color: textColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
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
