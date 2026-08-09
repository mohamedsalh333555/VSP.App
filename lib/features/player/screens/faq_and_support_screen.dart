import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';

class FAQAndSupportScreen extends StatefulWidget {
  const FAQAndSupportScreen({super.key});

  @override
  State<FAQAndSupportScreen> createState() => _FAQAndSupportScreenState();
}

class _FAQAndSupportScreenState extends State<FAQAndSupportScreen> {
  Future<void> _launchWhatsApp() async {
    final Uri url = Uri.parse('https://wa.me/201000000000?text=${Uri.encodeComponent('أهلاً دعم VSP، أحتاج مساعدة بشأن التطبيق/الحجوزات.')}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchPhoneCall() async {
    final Uri url = Uri.parse('tel:+201000000000');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            isArabic ? LucideIcons.chevronRight : LucideIcons.chevronLeft,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'الأسئلة الشائعة والدعم الفني',
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
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.headphones, color: VSPColors.accent, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'فريق دعم VSP المباشر',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _launchWhatsApp,
                          icon: const Icon(LucideIcons.messageCircle, size: 18),
                          label: const Text('واتساب الدعم', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _launchPhoneCall,
                          icon: const Icon(LucideIcons.phone, size: 18, color: VSPColors.accent),
                          label: const Text('اتصال مباشر', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: VSPColors.accent),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: VSPSpacing.lg),

            Text(
              'الأسئلة الأكثر شيوعاً (FAQ):',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: VSPSpacing.sm),

            _buildFAQTile(
              question: 'كيف يمكنني حجز ملعب وإلغاء الحجز؟',
              answer: 'يمكنك اختيار الملعب والوقت المناسب من القائمة الرئيسية، واختيار الدفع بالعربون أو بالكامل. في حال التراجع قبل الدفع، لن يُخصم أي مبلغ من حسابه.',
            ),
            _buildFAQTile(
              question: 'ما هو نظام الـ Elo Rating وكيف يُحسب الدوري؟',
              answer: 'الـ Elo Rating هو الترتيب الرسمي لفريقك بين كل فرق المحافظة. يزيد النقاط عند الفوز في التحديات والبطولات، ويرتفع موقع فريقك في قائمة المتصدرين.',
            ),
            _buildFAQTile(
              question: 'كيف يتم اعتماد نتائج التحديات بين الكباتن؟',
              answer: 'يقوم الكابتن بإدخال النتيجة بعد المباراة. تُعتمد النتيجة تلقائياً خلال 24 ساعة في حال عدم اعتراض الفريق المنافس، وتُحدث نقاط الدوري فوراً.',
            ),
            _buildFAQTile(
              question: 'ما هي رسوم المنصة والتشغيل (3%)؟',
              answer: 'هي رسوم خدمة بسيطة تُضاف عند السداد إلكترونياً لتغطي خدمات التشغيل والتأمين التقني للحجوزات فورياً.',
            ),

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
        border: Border.all(color: VSPColors.divider),
      ),
      child: ExpansionTile(
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
    );
  }
}
