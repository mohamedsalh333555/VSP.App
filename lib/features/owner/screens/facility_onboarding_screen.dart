import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/stadium_repository.dart';
import '../../../core/repositories/user_repository.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../data/models.dart';
import 'add_stadium_wizard.dart';
import '../services/facility_onboarding_service.dart';
import '../widgets/facility_onboarding/facility_upgrade_bottom_sheet.dart';
import '../../../shared/widgets/stadium_card.dart';

class FacilityOnboardingScreen extends StatefulWidget {
 const FacilityOnboardingScreen({super.key});

 @override
 State<FacilityOnboardingScreen> createState() => _FacilityOnboardingScreenState();
}

class _FacilityOnboardingScreenState extends State<FacilityOnboardingScreen> {
  Stream<List<Stadium>>? _stadiumsStream;
  String? _cachedUid;

  Stream<List<Stadium>> _getStadiumsStream(String uid) {
    if (_stadiumsStream != null && _cachedUid == uid) {
      return _stadiumsStream!;
    }
    _cachedUid = uid;
    _stadiumsStream = StadiumRepository().getOwnerStadiums(uid);
    return _stadiumsStream!;
  }

  /// يتحقق من الباقة ويفتح Wizard أو يعرض Bottom Sheet الترقية
  Future<void> _onAddAnotherStadium(
    BuildContext context,
    List<Stadium> stadiums,
    bool isAr,
  ) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userModel;
    if (user == null) return;

    if (FacilityOnboardingService.canAddStadium(
      user: user,
      currentStadiumsCount: stadiums.length,
    )) {
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddStadiumWizard()),
      );
      return;
    }

    if (!context.mounted) return;
    await FacilityUpgradeBottomSheet.show(context, isAr: isAr, user: user);
  }

 @override
 Widget build(BuildContext context) {
 final authProvider = Provider.of<AuthProvider>(context, listen: false);
 final uid = authProvider.userModel?.uid ?? authProvider.currentUser?.id ?? '';
 final isAr = Localizations.localeOf(context).languageCode == 'ar';

 return Scaffold(
 backgroundColor: VSPColors.background,
 body: SafeArea(
        child: StreamBuilder<List<Stadium>>(
          stream: _getStadiumsStream(uid),
          builder: (context, snapshot) {
 if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
 return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
 }
 if (snapshot.hasError) {
 VSPLogger.w('FacilityOnboardingScreen stream notice (gracefully handled): ${snapshot.error}');
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
 onPressed: () => Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const AddStadiumWizard()),
 ),
 style: ElevatedButton.styleFrom(
 backgroundColor: VSPColors.accent,
 foregroundColor: Colors.black,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(VSPRadius.xl),
 ),
 ),
 child: Text(
 isAr ? 'إضافة ملعب' : 'Add stadium',
 style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
 ),
 ),
 ),
              const SizedBox(height: 12),
              // ── زر التأجيل: outlined واضح بدلاً من نص شبح لا يُلاحَظ ──
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    // تأكيد من المالك قبل تخطي إضافة الملعب
                    final bool? confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: VSPColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(VSPRadius.dialog),
                        ),
                        title: Text(
                          isAr ? 'تأجيل إضافة الملعب؟' : 'Skip Adding Stadium?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        content: Text(
                          isAr
                              ? 'لن تتمكن من استقبال أي حجوزات أو ظهور في نتائج البحث حتى تضيف ملعبك وتُوثّق حسابك.\n\nيمكنك إضافة الملعب في أي وقت من لوحة التحكم.'
                              : "You won't be able to receive bookings or appear in search results until you add your stadium and verify your account.\n\nYou can add it anytime from your dashboard.",
                          style: const TextStyle(
                            color: VSPColors.textSecondary,
                            fontSize: 13.5,
                            height: 1.55,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(
                              isAr ? 'إضافة الملعب الآن' : 'Add Stadium Now',
                              style: const TextStyle(
                                color: VSPColors.accent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(
                              isAr ? 'تخطى الآن' : 'Skip for Now',
                              style: const TextStyle(
                                color: VSPColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    if (!context.mounted) return;
                    final uid = authProvider.currentUser?.id ?? authProvider.userModel?.uid;
                    if (uid != null) {
                      await UserRepository().updateOnboardingConfirmed(uid, true);
                    }
                    await authProvider.updateProfile({'is_onboarding_confirmed': true});
                    if (context.mounted) context.go('/owner');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: VSPColors.textSecondary,
                    side: BorderSide(
                      color: VSPColors.textSecondary.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Iconsax.timer_1_copy, size: 18, color: VSPColors.textSecondary),
                  label: Text(
                    isAr ? 'هضيف الملعب بعدين' : "I'll add the stadium later",
                    style: const TextStyle(
                      color: VSPColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // ── تحذير صغير يُعلم المالك بمحدودية حسابه ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Iconsax.warning_2_copy, size: 12, color: VSPColors.warning),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      isAr
                          ? 'لن تظهر في البحث أو تستقبل حجوزات دون إضافة ملعب'
                          : "You won't appear in search or receive bookings without a stadium",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: VSPColors.warning,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
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

 // Goal Gradient Progress Card
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(14),
 margin: const EdgeInsets.only(bottom: 14),
 decoration: BoxDecoration(
 color: VSPColors.surface,
 borderRadius: BorderRadius.circular(VSPRadius.lg),
 border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Row(
 children: [
 const Icon(Iconsax.chart_1_copy, color: VSPColors.accent, size: 18),
 const SizedBox(width: 8),
 Text(
 isAr ? 'تقدم إكتمال ملفك الرياضي' : 'Profile Completion',
 style: const TextStyle(
 color: Colors.white,
 fontSize: 13,
 fontWeight: FontWeight.bold,
 ),
 ),
 ],
 ),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: VSPColors.accent.withValues(alpha: 0.2),
 borderRadius: BorderRadius.circular(10),
 ),
 child: const Text(
 '65% ',
 style: TextStyle(
 color: VSPColors.accent,
 fontSize: 12,
 fontWeight: FontWeight.w900,
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 ClipRRect(
 borderRadius: BorderRadius.circular(4),
 child: const LinearProgressIndicator(
 value: 0.65,
 minHeight: 6,
 backgroundColor: VSPColors.surfaceAlt,
 valueColor: AlwaysStoppedAnimation<Color>(VSPColors.accent),
 ),
 ),
 const SizedBox(height: 8),
 Text(
 isAr
 ? 'أحسنت! قطعنا 65% من الإعداد. تابع رفع الوثائق لتصل لـ 100% وتفعل شارة المالك الموثوق '
 : '65% complete! Finish uploading documents to reach 100% and earn your Verified Badge ',
 style: const TextStyle(
 color: VSPColors.textSecondary,
 fontSize: 11,
 height: 1.4,
 ),
 ),
 ],
 ),
 ),

 // ملاحظة المعاينة
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
 const Icon(Iconsax.flash_1_copy, color: VSPColors.accent, size: 20),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 isAr
 ? 'هكذا ستظهر ملاعبك وتفاصيلها أمام اللاعبين في التطبيق.'
 : 'This is how your stadiums will appear to players.',
 style: const TextStyle(
 color: VSPColors.accent, fontSize: 13, fontWeight: FontWeight.bold,
 ),
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
 return StadiumCard(
 stadium: stadiums[index],
 isOwnerView: false,
 onTap: () {
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => AddStadiumWizard(stadiumId: stadiums[index].id),
 ),
 );
 },
 );
 },
 ),
 const SizedBox(height: 32),

 Column(
 children: [
 SizedBox(
 width: double.infinity, height: 56,
 child: ElevatedButton.icon(
 // Gate: Check subscription before allowing second stadium
 onPressed: () => _onAddAnotherStadium(context, stadiums, isAr),
 icon: const Icon(Iconsax.add_circle_copy, color: Colors.white),
 label: Text(
 isAr ? 'إضافة ملعب آخر' : 'Add another stadium',
 style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
 ),
 style: ElevatedButton.styleFrom(
 backgroundColor: VSPColors.surfaceAlt,
 foregroundColor: Colors.white,
 side: const BorderSide(color: VSPColors.divider),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(VSPRadius.xl),
 ),
 ),
 ),
 ),
 const SizedBox(height: 12),
 SizedBox(
 width: double.infinity, height: 56,
 child: ElevatedButton(
 onPressed: () async {
 final uid = authProvider.currentUser?.uid;
 final updatedAdditional =
 FacilityOnboardingService.buildOnboardingConfirmedPayload(
 authProvider.userModel?.additionalData,
 );
 if (uid != null) {
 await UserRepository().updateOnboardingStatus(uid, updatedAdditional);
 }
 await authProvider.updateProfile({
 'additionalData': updatedAdditional,
 });
 if (!context.mounted) return;
 // FIX: Use GoRouter instead of Navigator.push to keep
 // redirect logic consistent and avoid broken GoRouter state
 context.go('/documentation');
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: VSPColors.accent,
 foregroundColor: Colors.black,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(VSPRadius.xl),
 ),
 ),
 child: Text(
 isAr ? 'متابعة لرفع الوثائق' : 'Continue to Upload Docs',
 style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 24),
 ],
 ),
 );
 }),
 ),
 );
 }
}
