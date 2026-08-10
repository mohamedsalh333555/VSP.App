import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/providers/auth_provider.dart';

class FAQAndSupportScreen extends StatefulWidget {
  const FAQAndSupportScreen({super.key});

  @override
  State<FAQAndSupportScreen> createState() => _FAQAndSupportScreenState();
}

class _FAQAndSupportScreenState extends State<FAQAndSupportScreen> {
  Future<void> _launchWhatsApp() async {
    final Uri url = Uri.parse('https://wa.me/201100229462?text=${Uri.encodeComponent('أهلاً دعم VSP، أحتاج مساعدة بشأن التطبيق/الحجوزات.')}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchPhoneCall() async {
    final Uri url = Uri.parse('tel:+201100229462');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final auth = Provider.of<AuthProvider>(context);
    final isOwner = auth.isOwner;

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
          isOwner 
            ? (isArabic ? 'دعم وأسئلة أصحاب الملاعب' : 'Owner Support & FAQ')
            : (isArabic ? 'الأسئلة الشائعة والدعم الفني' : 'FAQ & Support'),
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
                  Row(
                    children: [
                      const Icon(LucideIcons.headphones, color: VSPColors.accent, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        isOwner 
                          ? (isArabic ? 'فريق دعم أصحاب الملاعب المباشر' : 'Direct Stadium Owners Support')
                          : (isArabic ? 'فريق دعم VSP المباشر' : 'VSP Direct Support Team'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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
                          label: Text(isArabic ? 'واتساب الدعم' : 'WhatsApp Support', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                          label: Text(isArabic ? 'اتصال مباشر' : 'Direct Call', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              isOwner 
                ? (isArabic ? 'أسئلة تهم أصحاب الملاعب:' : 'Stadium Owner FAQs:')
                : (isArabic ? 'الأسئلة الأكثر شيوعاً:' : 'Frequently Asked Questions:'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: VSPSpacing.sm),

            if (isOwner) ...[
              _buildFAQTile(
                question: isArabic ? 'كيف أضيف ملعبي وأتحكم في ساعات العمل والأسعار؟' : 'How do I add my stadium and manage pricing & working hours?',
                answer: isArabic 
                  ? 'من خلال زر "إضافة ملعب جديد" في لوحة التحكم، يمكنك رفع صور الملعب، تحديد سعر الساعة، وإضافة فترات الراحة وساعات العمل اليومية بكل سهولة.'
                  : 'Use the "Add New Stadium" button in your dashboard to upload photos, set hourly rates, and define daily operating hours.',
              ),
              _buildFAQTile(
                question: isArabic ? 'كيف أحصل على مبالغ الحجوزات والعربون من اللاعبين؟' : 'How do I receive booking payments and deposits from players?',
                answer: isArabic 
                  ? 'يمكنك إضافة بيانات وسائل الدفع الخاصة بك (انستا باي أو فودافون كاش أو حساب بنكي) في إعدادات الحساب، لتصلك مبالغ العربون والحجوزات فورياً.'
                  : 'Add your preferred payout method (InstaPay, Vodafone Cash, or Bank Transfer) in Account Settings to receive player deposits directly.',
              ),
              _buildFAQTile(
                question: isArabic ? 'كيف أتحكم في جدول الحجوزات وحظر أوقات معينة؟' : 'How do I manage my schedule and block unavailable slots?',
                answer: isArabic 
                  ? 'يمكنك الدخول إلى قائمة الحجوزات والجدول الزمني للملعب، وحظر الأوقات الخاصة بالحجوزات الخارجية لمنع التعارض وتأكيد الحجوزات الإلكترونية.'
                  : 'Access your Stadium Schedule view to block offline slots, view incoming player bookings, and manage your calendar seamlessly.',
              ),
              _buildFAQTile(
                question: isArabic ? 'كيف أنظم البطولات والتحديات على ملعبي؟' : 'How do I create and organize tournaments on my stadium?',
                answer: isArabic 
                  ? 'من تبويب "البطولات"، يمكنك إطلاق بطولة جديدة، تحديد رسوم الاشتراك والجوائز، وتوليد مواعيد المباريات والشجرة التنافسية تلقائياً.'
                  : 'Go to the Tournaments section to initiate a new tournament, specify entry fees & prizes, and generate match brackets automatically.',
              ),
              _buildFAQTile(
                question: isArabic ? 'ما هي رسوم المنصة وكيف يتم تسوية الخدمات؟' : 'What are the platform fees for stadium owners?',
                answer: isArabic 
                  ? 'تتميز المنصة بتقديم خدمات إدارة الملاعب والبطولات مجاناً لأصحاب الملاعب، مع تحصيل رسوم خدمة بسيطة من الحاكز لضمان التشغيل والتأمين التقني.'
                  : 'VSP provides full stadium management and tournament features for owners free of platform commissions, with transparent processing fees.',
              ),
            ] else ...[
              _buildFAQTile(
                question: isArabic ? 'كيف يمكنني حجز ملعب وإلغاء الحجز؟' : 'How can I book a stadium and cancel a booking?',
                answer: isArabic 
                  ? 'يمكنك اختيار الملعب والوقت المناسب من القائمة الرئيسية، واختيار الدفع بالعربون أو بالكامل. يمكنك إلغاء الحجز قبل الموعد وفقاً لسياسة الملعب.'
                  : 'Choose a pitch and convenient time slot from the main menu, select full or deposit payment, and confirm your booking instantly.',
              ),
              _buildFAQTile(
                question: isArabic ? 'كيف أنضم إلى مباراة عامة أو أحجز مكاناً في تحدي؟' : 'How do I join an open match or book a spot in a challenge?',
                answer: isArabic 
                  ? 'يمكنك تصفح المباريات العامة في قسم "المباريات"، واختيار المراكز الشاغرة والانضمام فورياً لتلعب مع لاعبين في منطقتك.'
                  : 'Browse open matches under the Matches tab, select an available position, and join local games near your governorate.',
              ),
              _buildFAQTile(
                question: isArabic ? 'ما هو نظام تصنيف مهارة الفرق وكيف يُحسب الدوري؟' : 'What is team skill ranking and how is the leaderboard calculated?',
                answer: isArabic 
                  ? 'نظام تصنيف المهارة هو الترتيب الرسمي لفريقك بين كل فرق المحافظة. تزداد النقاط عند الفوز في التحديات والبطولات، ويرتفع موقع فريقك في قائمة المتصدرين.'
                  : 'The ranking system calculates your team standing across the governorate. Earn leaderboard points by winning official challenges & tournaments.',
              ),
              _buildFAQTile(
                question: isArabic ? 'كيف يتم اعتماد نتائج التحديات بين الكباتن؟' : 'How are challenge match results confirmed between captains?',
                answer: isArabic 
                  ? 'يقوم الكابتن بإدخال النتيجة بعد المباراة. تُعتمد النتيجة تلقائياً خلال 24 ساعة في حال عدم اعتراض الفريق المنافس، وتُحدث نقاط الدوري فوراً.'
                  : 'Captains submit scores post-match. Results are automatically verified within 24 hours if uncontested, updating rankings instantly.',
              ),
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
