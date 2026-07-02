import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../ui/tokens/vsp_tokens.dart';
import '../providers/auth_provider.dart';

class SupportService {
  static final SupportService _instance = SupportService._internal();
  factory SupportService() => _instance;
  SupportService._internal();

  /// Opens the support channel (Silicon Valley Strategy: Organized Support)
  Future<void> openSupport(BuildContext context, {String? category}) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    showModalBottomSheet(
      context: context,
      backgroundColor: VSPColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(VSPSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isArabic ? 'كيف يمكننا مساعدتك؟' : 'How can we help?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: VSPSpacing.md),
            _buildSupportOption(
              context,
              Icons.verified_user_outlined,
              isArabic ? "التوثيق وتفعيل الحساب" : "Document Verification & Profile",
              isArabic ? "مشاكل توثيق الهوية والملعب" : "Issues with identity and stadium verification.",
            ),
            _buildSupportOption(
              context,
              Icons.person_off_outlined,
              isArabic ? "الإبلاغ عن غياب لاعب" : "Report Player No-Show",
              isArabic ? "الإبلاغ عن عدم حضور اللاعبين في الوقت المحدد" : "Report players who did not show up on time.",
            ),
            _buildSupportOption(
              context,
              Icons.bug_report_outlined,
              isArabic ? "مشكلة تقنية بالبطولات" : "Championships & Technical Issues",
              isArabic ? "الإبلاغ عن أعطال تقنية أو في لوحة المتصدرين" : "Report bugs or leaderboard/brackets issues.",
            ),
            const SizedBox(height: VSPSpacing.xl),
            Center(
              child: Text(
                isArabic ? 'متواجدون 24/7 لشركاء VSP' : 'Available 24/7 for VSP Partners',
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportOption(BuildContext context, IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: VSPColors.accent.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: VSPColors.accent),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: VSPColors.textPrimary)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: VSPColors.textSecondary)),
      onTap: () {
        Navigator.pop(context);
        _launchSupportWhatsApp(context: context, category: title);
      },
    );
  }

  Future<void> _launchSupportWhatsApp({required BuildContext context, required String category}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.userModel;

    final name = user?.name ?? 'Guest';
    final phone = user?.phone ?? 'N/A';
    final uid = user?.uid ?? 'N/A';
    final governorate = user?.governorate ?? 'N/A';

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final messageText = isArabic
        ? "مرحباً دعم VSP، لدي مشكلة بخصوص $category. تفاصيل حسابي: الاسم: $name، الهاتف: $phone، الكود: $uid، المحافظة: $governorate."
        : "Hi VSP Support, I need help with $category. Account Details: Name: $name, Phone: $phone, UID: $uid, Governorate: $governorate.";

    final encodedMessage = Uri.encodeComponent(messageText);
    final url = 'https://wa.me/201100229462?text=$encodedMessage';
    
    try {
      await launchUrl(
        Uri.parse(url), 
        mode: LaunchMode.externalApplication
      );
    } catch (e) {
      debugPrint('Could not launch WhatsApp support: $e');
    }
  }
}
