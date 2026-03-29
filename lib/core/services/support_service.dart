import 'package:flutter/material.dart';
import '../ui/tokens/vsp_tokens.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportService {
  static final SupportService _instance = SupportService._internal();
  factory SupportService() => _instance;
  SupportService._internal();

  /// Opens the support channel (Silicon Valley Strategy: Organized Support)
  Future<void> openSupport(BuildContext context, {String? category}) async {
    // Show a beautiful bottom sheet first to categorize the issue
    // This gives an impression of a large, organized organization.
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
              'How can we help?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: VSPSpacing.md),
            _buildSupportOption(
              context,
              Icons.account_balance_wallet_outlined,
              'Billing & Commission',
              'Issues with payments or stadium blocking.',
            ),
            _buildSupportOption(
              context,
              Icons.sports_soccer_outlined,
              'Match & Tournament',
              'Report an issue with a match or ranking.',
            ),
            _buildSupportOption(
              context,
              Icons.bug_report_outlined,
              'Technical Issue',
              'Report a bug or app crash.',
            ),
            const SizedBox(height: VSPSpacing.xl),
            Center(
              child: Text(
                'Available 24/7 for VSP Partners',
                style: TextStyle(color: VSPColors.textSecondary, fontSize: 12),
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
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: () {
        Navigator.pop(context);
        _launchSupportWhatsApp(category: title);
      },
    );
  }

  Future<void> _launchSupportWhatsApp({required String category}) async {
    final message = Uri.encodeComponent('Hi VSP Support! I need help with: $category');
    final url = 'https://wa.me/201100229462?text=$message';
    
    // Direct launch without canLaunchUrl check, which often fails on Android 11+
    // externalApplication mode will try to open WhatsApp or the browser as fallback.
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
