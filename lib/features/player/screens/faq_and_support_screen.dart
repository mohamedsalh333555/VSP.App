import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../../../core/repositories/app_settings_repository.dart';
import '../../../core/utils/vsp_launcher_utils.dart';

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
      final phone = settings.whatsappNumber.isNotEmpty ? settings.whatsappNumber : (settings.supportPhone.isNotEmpty ? settings.supportPhone : '201100229462');
      await VSPLauncherUtils.openWhatsApp(context, phone: phone, message: message);
    } catch (_) {}
  }

  Future<void> _launchPhoneCall() async {
    try {
      final settings = await AppSettingsRepository().getSettings();
      if (!mounted) return;
      final phone = settings.supportPhone.isNotEmpty ? settings.supportPhone : '01100229462';
      await VSPLauncherUtils.makePhoneCall(context, phone);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isOwner = context.select<AuthProvider, bool>((a) => a.isOwner);

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        leading: const VSPBackButton(),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Iconsax.headphones_copy, color: VSPColors.accent, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        isOwner 
                          ? (isArabic ? 'دعم أصحاب الملاعب المباشر' : 'Stadium Owner Direct Support')
                          : (isArabic ? 'دعم VSP المباشر' : 'VSP Direct Support'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _launchWhatsApp,
                          icon: const Icon(Iconsax.headphones_copy, size: 16, color: Colors.black),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              isArabic ? 'واتساب الدعم' : 'WhatsApp Support',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                              maxLines: 1,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: VSPColors.accent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _launchPhoneCall,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: VSPColors.accent),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              isArabic ? 'اتصال مباشر' : 'Direct Call',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                            ),
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
                  ? 'من خلال زر "إضافة ملعب جديد" في لوحة التحكم، يمكنك رفع صور الملعب، تحديد سعر الساعة، وإضافة فترات الراحة (اختيارية) وتحديد ساعات العمل اليومية بكل سهولة.'
                  : 'Use the "Add New Stadium" button in your dashboard to upload photos, set hourly rates, add optional breaks, and define daily operating hours.',
              ),
              _buildFAQTile(
                question: isArabic ? 'كيف أحصل على مبالغ الحجوزات والعربون من اللاعبين؟' : 'How do I receive booking payments and deposits from players?',
                answer: isArabic 
                  ? 'يمكنك إضافة بيانات وسائل الدفع والتحصيل الخاصة بك (إنستاباي، المحافظ الإلكترونية، أو الحساب البنكي) في إعدادات الحساب لتصلك مبالغ العربون والحجوزات فورياً.'
                  : 'Add your preferred payout method (InstaPay, Mobile Wallets, or Bank Transfer) in Account Settings to receive player deposits directly.',
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
                  ? 'من تبويب "البطولات"، يمكنك إطلاق بطولة جديدة، تحديد رسوم الاشتراك والجوائز، وتوليد مواعيد المباريات والشجرة التنافسية الإقصائية تلقائياً.'
                  : 'Go to the Tournaments section to initiate a new tournament, specify entry fees & prizes, and generate match brackets automatically.',
              ),
              _buildFAQTile(
                question: isArabic ? 'ما هي باقات الاشتراك لأصحاب الملاعب (Basic vs PRO)؟' : 'What are the subscription plans for stadium owners (Basic vs PRO)?',
                answer: isArabic 
                  ? 'تمنحك الباقة الأساسية تشغيل ملعب واحد مجاناً لمدة شهرين كاملين لتقييم المنظومة، بينما تمنحك الباقة الاحترافية (PRO) إدارة حتى 3 ملاعب كاملة، تحليلات متقدمة للإيرادات وساعات الذروة، وأولوية الظهور في نتائج البحث.'
                  : 'The Basic plan offers free management of 1 pitch for 2 months, while the PRO plan includes managing up to 3 pitches, advanced analytics for peak hours, and priority search visibility.',
              ),
              _buildFAQTile(
                question: isArabic ? 'ما هي رسوم المنصة وكيف يتم تسوية الخدمات؟' : 'What are the platform fees for stadium owners?',
                answer: isArabic 
                  ? 'تتميز المنصة بتقديم خدمات إدارة الملاعب والبطولات مجاناً لأصحاب الملاعب، مع تحصيل رسوم خدمة رقمية بسيطة ومؤمنة عند الدفع الإلكتروني لضمان جودة التشغيل.'
                  : 'VSP provides full stadium management and tournament features for owners free of platform commissions, with transparent secure processing fees.',
              ),
            ] else ...[
              _buildFAQTile(
                question: isArabic ? 'كيف يمكنني حجز ملعب وإلغاء الحجز؟' : 'How can I book a stadium and cancel a booking?',
                answer: isArabic 
                  ? 'يمكنك اختيار الملعب والوقت المناسب من القائمة الرئيسية، واختيار الدفع بالعربون أو بالكامل عبر البطاقات البنكية، المحافظ الإلكترونية، أو إنستاباي. يمكنك إلغاء الحجز واسترداد العربون وفقاً لسياسة الإلغاء المحددة للملعب.'
                  : 'Choose a pitch and convenient slot, pay deposit or full amount via cards, mobile wallets, or InstaPay. Cancellations follow the stadium cancellation policy.',
              ),
              _buildFAQTile(
                question: isArabic ? 'كيف أنضم إلى مباراة عامة أو أحجز مكاناً في تحدي؟' : 'How do I join an open match or book a spot in a challenge?',
                answer: isArabic 
                  ? 'يمكنك تصفح المباريات العامة في قسم "المباريات"، واختيار المراكز الشاغرة والانضمام فورياً لتلعب مع لاعبين في منطقتك.'
                  : 'Browse open matches under the Matches tab, select an available position, and join local games near your governorate.',
              ),
              _buildFAQTile(
                question: isArabic ? 'كيف أشترك في البطولات وتحديات 1v1؟' : 'How do I register for tournaments and 1v1 challenges?',
                answer: isArabic 
                  ? 'من قسم "البطولات"، يمكنك استعراض البطولات المفتوحة والتسجيل بقائمة فريقك ودفع الرسوم إلكترونياً، أو المشاركة في دوري ملك الـ 1v1 الفردي لحصد الجوائز والنقاط.'
                  : 'Navigate to Tournaments to explore open cups, register your team squad and pay fees online, or compete in 1v1 individual showdowns.',
              ),
              _buildFAQTile(
                question: isArabic ? 'ما هي وظيفة كابتن VSP الذكي (VSP Copilot)؟' : 'What is VSP Copilot (AI Football Assistant)?',
                answer: isArabic 
                  ? 'هو مساعدك الرياضي الذكي المدعوم بالذكاء الاصطناعي، يمكنك محادثته باللهجة الكروية لاقتراح الملاعب المتاحة الليلة، مقارنة الأسعار، ومعرفة المواعيد والبطولات الشاغرة فوراً.'
                  : 'Your AI football assistant ready to find available nearby pitches, compare rates, and recommend tournament fixtures instantly.',
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
