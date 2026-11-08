import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import '../ui/vsp_ui.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../ui/tokens/vsp_tokens.dart';
import '../repositories/app_settings_repository.dart';
import '../utils/vsp_launcher_utils.dart';

class SuspendedAccountScreen extends StatelessWidget {
 const SuspendedAccountScreen({super.key});

 @override
 Widget build(BuildContext context) {
 final auth = Provider.of<AuthProvider>(context);
 final isAr = Localizations.localeOf(context).languageCode == 'ar';

 return VSPScaffold(
 backgroundColor: VSPColors.background,
 body: SafeArea(top: true, bottom: true, child: Center(
 child: SingleChildScrollView(
 padding: const EdgeInsets.all(VSPSpacing.xl),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 padding: const EdgeInsets.all(VSPSpacing.lg),
 decoration: BoxDecoration(
 color: VSPColors.surface,
 shape: BoxShape.circle,
 border: Border.all(color: VSPColors.error.withValues(alpha: 0.2)),
 ),
 child: Semantics(
 label: isAr ? 'الحساب معلّق' : 'Account suspended',
 image: true,
 child: const Icon(
 Iconsax.close_circle_copy,
 color: VSPColors.error,
 size: 56,
 ),
 ),
 ),
 const SizedBox(height: VSPSpacing.xl),
 Text(
 isAr ? 'تم تعليق الحساب' : 'Account Suspended',
 textAlign: TextAlign.center,
 style: const TextStyle(
 color: VSPColors.error,
 fontSize: 22,
 fontWeight: FontWeight.bold,
 letterSpacing: -0.5,
 ),
 ),
 const SizedBox(height: VSPSpacing.sm),
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
 child: Text(
 isAr
 ? 'لقد تم إيقاف حسابك مؤقتاً بسبب مراجعة إدارية أو مخالفة سياسات المنصة. يرجى التواصل مع الدعم الفني لحل هذه المشكلة.'
 : 'Your account has been temporarily suspended due to administrative review or violation of policies. Please contact support to resolve this issue.',
 textAlign: TextAlign.center,
 style: const TextStyle(
 color: VSPColors.textSecondary,
 height: 1.5,
 fontSize: 14,
 ),
 ),
 ),
 const SizedBox(height: VSPSpacing.xl),
 SizedBox(
 width: double.infinity,
 height: 56,
 child: ElevatedButton.icon(
 style: ElevatedButton.styleFrom(
 backgroundColor: VSPColors.accent,
 foregroundColor: VSPColors.background,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(VSPRadius.md),
 ),
 elevation: 0,
 ),
 onPressed: () async {
 // Do not prefill the user's phone number, UID or name into a
 // third-party messaging app. Support can request details after consent.
 final message = isAr
 ? 'مرحباً فريق دعم VSP، أريد الاستفسار عن تعليق حسابي.'
 : 'Hello VSP Support, I would like help with my suspended account.';

 try {
 final settings = await AppSettingsRepository().getSettings();
 if (!context.mounted) return;
 final supportNumber = settings.whatsappNumber.isNotEmpty
 ? settings.whatsappNumber
 : (settings.supportPhone.isNotEmpty ? settings.supportPhone : '201100229462');
 await VSPLauncherUtils.openWhatsApp(context, phone: supportNumber, message: message);
 } catch (e) {
 debugPrint('Could not launch WhatsApp support.');
 if (!context.mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(
 isAr
 ? 'تعذر فتح الدعم الآن. يرجى المحاولة مرة أخرى.'
 : 'Unable to open support right now. Please try again.',
 ),
 ),
 );
 }
 },
 icon: const Icon(Iconsax.headphones_copy, color: VSPColors.background),
 label: Text(
 isAr ? 'التواصل مع الدعم' : 'Contact Support',
 style: const TextStyle(
 fontWeight: FontWeight.bold,
 fontSize: 16,
 ),
 ),
 ),
 ),
 const SizedBox(height: VSPSpacing.md),
 TextButton(
 onPressed: () async {
 try {
 await auth.signOut();
 } catch (e) {
 debugPrint('Could not sign out suspended account.');
 if (!context.mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(
 isAr
 ? 'تعذر تسجيل الخروج. يرجى المحاولة مرة أخرى.'
 : 'Unable to sign out. Please try again.',
 ),
 ),
 );
 }
 },
 style: TextButton.styleFrom(
 foregroundColor: VSPColors.textSecondary,
 padding: const EdgeInsets.symmetric(vertical: VSPSpacing.sm, horizontal: VSPSpacing.lg),
 ),
 child: Text(
 isAr ? 'تسجيل الخروج' : 'Sign Out',
 style: const TextStyle(
 fontWeight: FontWeight.w600,
 fontSize: 14,
 ),
 ),
 ),
 ],
 ),
 ),
 )),
 );
 }
}