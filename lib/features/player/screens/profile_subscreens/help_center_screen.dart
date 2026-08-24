import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/repositories/app_settings_repository.dart';
import '../../../../core/utils/vsp_launcher_utils.dart';
import '../../../../shared/widgets/vsp_back_button.dart';
import '../../../../shared/widgets/vsp_icon_badge.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

class HelpCenterScreen extends StatefulWidget {
 const HelpCenterScreen({super.key});

 @override
 State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
 @override
 Widget build(BuildContext context) {
 final l10n = AppLocalizations.of(context)!;
 final isAr = l10n.localeName == 'ar';

 final List<Map<String, String>> faqs = [
 {'q': l10n.faq1_q, 'a': l10n.faq1_a},
 {'q': l10n.faq2_q, 'a': l10n.faq2_a},
 {'q': l10n.faq3_q, 'a': l10n.faq3_a},
 {'q': l10n.faq4_q, 'a': l10n.faq4_a},
 {'q': l10n.faq5_q, 'a': l10n.faq5_a},
 {'q': l10n.faq6_q, 'a': l10n.faq6_a},
 {'q': l10n.faq7_q, 'a': l10n.faq7_a},
 {'q': l10n.faq8_q, 'a': l10n.faq8_a},
 {'q': l10n.faq9_q, 'a': l10n.faq9_a},
 {'q': l10n.faq10_q, 'a': l10n.faq10_a},
 ];

 return Scaffold(
 backgroundColor: VSPColors.background,
 appBar: AppBar(
 backgroundColor: Colors.transparent,
 elevation: 0,
 leading: const VSPBackButton(),
 title: Text(
 l10n.helpCenter,
 style: Theme.of(context).textTheme.displaySmall,
 ),
 centerTitle: true,
 ),
 body: SingleChildScrollView(
 keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
 padding: const EdgeInsets.all(VSPSpacing.md),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Hero Header
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(20),
 margin: const EdgeInsets.only(bottom: 24),
 decoration: BoxDecoration(
 gradient: LinearGradient(
 colors: [
 VSPColors.accent.withValues(alpha: 0.12),
 VSPColors.accent.withValues(alpha: 0.03),
 ],
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 ),
 borderRadius: BorderRadius.circular(VSPRadius.xl),
 border: Border.all(color: VSPColors.accent.withValues(alpha: 0.2)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Icon(Iconsax.headphones_copy, color: VSPColors.accent, size: 32),
 const SizedBox(height: 12),
 Text(
 isAr ? 'كيف يمكننا مساعدتك اليوم؟' : 'How can we help you today?',
 style: Theme.of(context).textTheme.titleLarge?.copyWith(
 color: Colors.white,
 fontSize: 20,
 fontWeight: FontWeight.bold,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 isAr
 ? 'فريق الدعم متاح لمساعدتك في أي وقت عبر واتساب أو الهاتف.'
 : 'Support team is available to assist you anytime via WhatsApp or phone.',
 style: Theme.of(context).textTheme.bodyMedium?.copyWith(
 color: VSPColors.textSecondary,
 fontSize: 12,
 height: 1.5,
 ),
 ),
 ],
 ),
 ),

 // WhatsApp Support
 _buildSupportAction(
 context,
 title: isAr ? 'محادثة الدعم' : 'Chat with Support',
 subtitle: isAr ? 'تحدث مباشرة مع فريقنا على واتساب' : 'Chat directly with our team on WhatsApp',
 icon: Iconsax.headphones_copy,
 color: const Color(0xFF25D366),
 onTap: () => _launchWhatsApp(context),
 ),
 const SizedBox(height: VSPSpacing.md),
 _buildSupportAction(
 context,
 title: isAr ? 'اتصل بالدعم' : 'Call Support',
 subtitle: isAr ? 'مساعدة طارئة للحجوزات والمباريات' : 'Emergency help for bookings and matches',
 icon: Iconsax.call_copy,
 color: VSPColors.accent,
 onTap: () async {
 final settings = await AppSettingsRepository().getSettings();
 final phone = settings.supportPhone.replaceAll('+', '').replaceAll(' ', '');
 launchUrl(Uri.parse('tel:$phone'));
 },
 ),

 const SizedBox(height: VSPSpacing.xl),

 // FAQs
 Text(
 isAr ? 'الأسئلة الشائعة' : 'Frequently Asked Questions',
 style: Theme.of(context).textTheme.titleLarge?.copyWith(
 color: Colors.white,
 fontWeight: FontWeight.bold,
 ),
 ),
 const SizedBox(height: 4),
 Text(
 isAr ? 'إجابات لأكثر الأسئلة شيوعاً حول تطبيق VSP' : 'Answers to the most common questions about the VSP app',
 style: Theme.of(context).textTheme.bodySmall?.copyWith(
 color: VSPColors.textSecondary,
 fontSize: 12,
 ),
 ),
 const SizedBox(height: VSPSpacing.md),

 ...List.generate(faqs.length, (i) => _buildFAQTile(faqs[i]['q']!, faqs[i]['a']!)),
 const SizedBox(height: 20),
 ],
 ),
 ),
 );
 }

 Widget _buildSupportAction(BuildContext context, {
 required String title,
 required String subtitle,
 required IconData icon,
 required Color color,
 required VoidCallback onTap,
 }) {
 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(VSPRadius.lg),
 child: Container(
 padding: const EdgeInsets.all(VSPSpacing.lg),
 decoration: BoxDecoration(
 color: VSPColors.surface,
 borderRadius: BorderRadius.circular(VSPRadius.lg),
 border: Border.all(color: color.withValues(alpha: 0.3)),
 ),
 child: Row(
 children: [
 VSPIconBadge(icon: icon, color: color, size: 48, iconSize: 24, backgroundOpacity: 0.1),
 const SizedBox(width: VSPSpacing.md),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: Theme.of(context).textTheme.titleMedium?.copyWith(
 color: Colors.white,
 fontWeight: FontWeight.bold,
 fontSize: 15,
 ),
 ),
 Text(
 subtitle,
 style: Theme.of(context).textTheme.bodySmall?.copyWith(
 color: VSPColors.textSecondary,
 fontSize: 12,
 ),
 ),
 ],
 ),
 ),
 const Icon(Iconsax.arrow_right_1_copy, color: VSPColors.textSecondary, size: 16),
 ],
 ),
 ),
 );
 }

 Widget _buildFAQTile(String question, String answer) {
 return Container(
 margin: const EdgeInsets.only(bottom: 8),
 decoration: BoxDecoration(
 color: VSPColors.surface,
 borderRadius: BorderRadius.circular(VSPRadius.md),
 border: Border.all(color: VSPColors.divider.withValues(alpha: 0.5)),
 ),
 child: ExpansionTile(
 tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
 childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
 iconColor: VSPColors.accent,
 collapsedIconColor: VSPColors.textSecondary,
 shape: const Border(),
 collapsedShape: const Border(),
 title: Text(
 question,
 style: Theme.of(context).textTheme.titleSmall?.copyWith(
 color: Colors.white,
 fontSize: 13.5,
 fontWeight: FontWeight.w600,
 height: 1.4,
 ),
 ),
 children: [
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: VSPColors.background,
 borderRadius: BorderRadius.circular(VSPRadius.sm),
 ),
 child: Text(
 answer,
 style: Theme.of(context).textTheme.bodyMedium?.copyWith(
 color: VSPColors.textSecondary,
 fontSize: 12.5,
 height: 1.65,
 ),
 ),
 ),
 ],
 ),
 );
 }

 void _launchWhatsApp(BuildContext context) async {
 final auth = Provider.of<AuthProvider>(context, listen: false);
 final user = auth.userModel;
 final name = user?.name ?? 'مستخدم VSP';
 final uid = user?.uid ?? 'N/A';
 final gov = user?.governorate ?? 'N/A';

 final message =
 'السلام عليكم فريق VSP \n'
 'أحتاج مساعدة في:\n\n'
 '────────────────\n'
 'الاسم: $name\n'
 'المحافظة: $gov\n'
 'الكود: $uid\n'
 '────────────────\n'
 'وصف المشكلة: ';

 final settings = await AppSettingsRepository().getSettings();
 final rawPhone = settings.whatsappNumber.isEmpty ? '201100229462' : settings.whatsappNumber;
 if (context.mounted) {
 await VSPLauncherUtils.openWhatsApp(context, phone: rawPhone, message: message);
 }
 }
}
