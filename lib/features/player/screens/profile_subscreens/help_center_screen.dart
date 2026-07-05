import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft, color: VSPColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Help Center',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
        padding: const EdgeInsets.all(VSPSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How can we help you today?',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: VSPSpacing.md),
            const Text(
              'Our support team is available 24/7 to assist you with any issues or questions.',
              style: TextStyle(color: VSPColors.textSecondary),
            ),
            const SizedBox(height: VSPSpacing.xl),
            
            // WhatsApp Support Card
            _buildSupportAction(
              context,
              title: 'Chat with Support',
              subtitle: 'Talk directly with our team on WhatsApp',
              icon: LucideIcons.messageSquare,
              color: const Color(0xFF25D366),
              onTap: () => _launchWhatsApp(context),
            ),
            
            const SizedBox(height: VSPSpacing.md),
            
            _buildSupportAction(
              context,
              title: 'Call Support',
              subtitle: 'Emergency assistance for bookings',
              icon: LucideIcons.phoneCall,
              color: VSPColors.accent,
              onTap: () => launchUrl(Uri.parse('tel:+201100229462')),
            ),

            const SizedBox(height: VSPSpacing.xl),
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: VSPSpacing.md),
            _buildFAQTile(AppLocalizations.of(context)!.faq1_q, AppLocalizations.of(context)!.faq1_a),
            _buildFAQTile(AppLocalizations.of(context)!.faq2_q, AppLocalizations.of(context)!.faq2_a),
            _buildFAQTile(AppLocalizations.of(context)!.faq3_q, AppLocalizations.of(context)!.faq3_a),
            _buildFAQTile(AppLocalizations.of(context)!.faq4_q, AppLocalizations.of(context)!.faq4_a),
            _buildFAQTile(AppLocalizations.of(context)!.faq5_q, AppLocalizations.of(context)!.faq5_a),
            _buildFAQTile(AppLocalizations.of(context)!.faq6_q, AppLocalizations.of(context)!.faq6_a),
            _buildFAQTile(AppLocalizations.of(context)!.faq7_q, AppLocalizations.of(context)!.faq7_a),
            _buildFAQTile(AppLocalizations.of(context)!.faq8_q, AppLocalizations.of(context)!.faq8_a),
            _buildFAQTile(AppLocalizations.of(context)!.faq9_q, AppLocalizations.of(context)!.faq9_a),
            _buildFAQTile(AppLocalizations.of(context)!.faq10_q, AppLocalizations.of(context)!.faq10_a),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportAction(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: VSPSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, color: VSPColors.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQTile(String question, String answer) {
    return ExpansionTile(
      title: Text(question, style: const TextStyle(color: Colors.white, fontSize: 14)),
      children: [
        Padding(
          padding: const EdgeInsets.all(VSPSpacing.md),
          child: Text(answer, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13)),
        ),
      ],
    );
  }

  void _launchWhatsApp(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.userModel;
    
    final message = 'Support Request:\nUID: ${user?.uid}\nGov: ${user?.governorate}\nIssue: ';
    final phone = '+201100229462'.replaceAll('+', ''); // wa.me needs phone without +
    
    // Universal WhatsApp Link - More reliable on modern Android/iOS
    final whatsappUrl = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(message)}");
    
    try {
      final success = await launchUrl(
        whatsappUrl,
        mode: LaunchMode.externalApplication,
      );
      
      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.whatsAppNotInstalled))
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp. Please try again.'))
        );
      }
    }
  }
}

