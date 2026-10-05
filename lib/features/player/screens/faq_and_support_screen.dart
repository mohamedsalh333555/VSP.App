import 'package:flutter/material.dart';
import '../../../core/ui/vsp_ui.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../../../core/repositories/app_settings_repository.dart';
import '../../../core/utils/vsp_launcher_utils.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../core/services/support_service.dart';
import '../../../l10n/app_localizations.dart';

class FAQAndSupportScreen extends StatefulWidget {
  const FAQAndSupportScreen({super.key});

  @override
  State<FAQAndSupportScreen> createState() => _FAQAndSupportScreenState();
}

class _FAQAndSupportScreenState extends State<FAQAndSupportScreen> {
  Future<void> _launchWhatsApp() async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final message = isArabic 
        ? 'أهلاً دعم VSP، أحتاج مساعدة بشأن التطبيق/الحجوزات.' 
        : 'Hi VSP Support, I need help regarding the app/bookings.';
    try {
      final settings = await AppSettingsRepository().getSettings();
      if (!mounted) return;
      final phone = settings.whatsappNumber.isNotEmpty ? settings.whatsappNumber : settings.supportPhone;
      if (phone.isEmpty) {
        if (mounted) {
          VSPFeedback.showError(
            context,
            isArabic ? 'support_contact_not_configured' : 'support_contact_not_configured',
          );
        }
        return;
      }
      await VSPLauncherUtils.openWhatsApp(context, phone: phone, message: message);
    } catch (e) {
      if (mounted) VSPFeedback.showError(context, e);
    }
  }

  Future<void> _launchPhoneCall() async {
    try {
      final settings = await AppSettingsRepository().getSettings();
      if (!mounted) return;
      final phone = settings.supportPhone;
      if (phone.isEmpty) {
        if (mounted) {
          final isArabic = Localizations.localeOf(context).languageCode == 'ar';
          VSPFeedback.showError(
            context,
            isArabic ? 'support_contact_not_configured' : 'support_contact_not_configured',
          );
        }
        return;
      }
      await VSPLauncherUtils.makePhoneCall(context, phone);
    } catch (e) {
      if (mounted) VSPFeedback.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final l10n = AppLocalizations.of(context)!;
    final isOwner = context.select<AuthProvider, bool>((a) => a.isOwner);

    return VSPScaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        leading: const VSPBackButton(),
        centerTitle: true,
        title: Text(
          isOwner ? l10n.supportOwnerPageTitle : l10n.supportPlayerPageTitle,
          style: Theme.of(context).textTheme.displaySmall,
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(VSPSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Support Contact Cards Banner
            Container(
              padding: const EdgeInsets.all(VSPSpacing.md),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.xl),
                border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Iconsax.headphones_copy, color: VSPColors.accent, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        isOwner ? l10n.supportOwnerDirectTitle : l10n.supportPlayerDirectTitle,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => SupportService().openSupport(context),
                          icon: const Icon(Iconsax.messages_3_copy, size: 16, color: Colors.black),
                          label: Text(
                            l10n.supportInAppButton,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: VSPColors.accent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _launchWhatsApp,
                              icon: const Icon(Iconsax.message_text_1_copy, size: 16),
                              label: Text(l10n.supportWhatsAppButton),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: VSPColors.textPrimary,
                                side: const BorderSide(color: VSPColors.divider),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _launchPhoneCall,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: VSPColors.divider),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  l10n.supportCallButton,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                ],
              ),
            ),

            const SizedBox(height: VSPSpacing.lg),

            Text(
              isOwner 
                ? (isArabic ? 'أسئلة تهم أصحاب الملاعب:' : 'Stadium Owner FAQs:')
                : (isArabic ? 'الأسئلة الأكثر شيوعاً:' : 'Frequently Asked Questions:'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: VSPSpacing.sm),

            if (isOwner) ...[
              _buildFAQTile(question: l10n.ownerFaq1_q, answer: l10n.ownerFaq1_a),
              _buildFAQTile(question: l10n.ownerFaq2_q, answer: l10n.ownerFaq2_a),
              _buildFAQTile(question: l10n.ownerFaq3_q, answer: l10n.ownerFaq3_a),
              _buildFAQTile(question: l10n.ownerFaq4_q, answer: l10n.ownerFaq4_a),
              _buildFAQTile(question: l10n.ownerFaq5_q, answer: l10n.ownerFaq5_a),
              _buildFAQTile(question: l10n.ownerFaq6_q, answer: l10n.ownerFaq6_a),
            ] else ...[
              _buildFAQTile(question: l10n.faq1_q, answer: l10n.faq1_a),
              _buildFAQTile(question: l10n.faq2_q, answer: l10n.faq2_a),
              _buildFAQTile(question: l10n.faq3_q, answer: l10n.faq3_a),
              _buildFAQTile(question: l10n.faq4_q, answer: l10n.faq4_a),
              _buildFAQTile(question: l10n.faq5_q, answer: l10n.faq5_a),
            ],

            const SizedBox(height: VSPSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQTile({required String question, required String answer}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.divider.withValues(alpha: 0.5)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
          iconColor: VSPColors.accent,
          collapsedIconColor: VSPColors.textSecondary,
          title: Text(
            question,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                answer,
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
