import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName == 'ar';

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: VSPColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isAr ? 'سياسة الخصوصية' : 'Privacy Policy',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: VSPColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(VSPRadius.lg),
                border: Border.all(color: VSPColors.accent.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.shieldCheck, color: VSPColors.accent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        isAr ? 'آخر تحديث: يوليو 2026' : 'Last Updated: July 2026',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: VSPColors.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAr
                        ? 'تُعدّ هذه السياسة الاتفاقية القانونية بينك وبين منصة VSP الرياضية. باستخدامك للتطبيق، فأنت توافق على شروطها.'
                        : 'This policy forms the legal agreement between you and the VSP Sports Platform. By using the app, you agree to its terms.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: VSPColors.textSecondary,
                          fontSize: 12,
                          height: 1.5,
                        ),
                  ),
                ],
              ),
            ),

            // Section 1: Data Collection
            _buildSection(
              context,
              icon: LucideIcons.database,
              title: isAr ? '١. البيانات التي نجمعها' : '1. Data We Collect',
              content: isAr
                  ? 'نقوم بجمع البيانات التي تُدخلها مباشرةً عند إنشاء حسابك، وتشمل: الاسم، رقم الهاتف، تاريخ الميلاد، المحافظة، صورة الملف الشخصي، والمركز المفضل (مهاجم / حارس / إلخ).'
                  : 'We collect data you provide directly when creating your account, including: name, phone number, date of birth, governorate, profile image, and preferred position (Striker / GK / etc.).',
            ),

            // Section 2: Payments via Paymob (Updated to 2 Hours)
            _buildSection(
              context,
              icon: LucideIcons.creditCard,
              title: isAr ? '٢. الدفع والمبالغ المستردة' : '2. Payments & Refunds',
              content: isAr
                  ? 'تتم معالجة جميع المدفوعات الرقمية داخل التطبيق بشكل آمن عبر بوابة Paymob المرخصة في مصر. لا يتم تخزين بيانات البطاقة المصرفية أو المحفظة الرقمية على خوادمنا في أي وقت.\n\nعند إلغاء الحجز قبل انتهاء وقت السماح (ساعتين قبل موعد المباراة)، يتم استرداد المبالغ تلقائياً ومباشرةً إلى المحفظة الرقمية أو الحساب البنكي الخاص بك عبر بروتوكول InstaPay المؤتمت.'
                  : 'All in-app digital payments are processed securely through Paymob, a licensed payment gateway in Egypt. Card or wallet data is never stored on our servers.\n\nUpon eligible cancellation (up to 2 hours before kickoff), refunds are automatically credited directly to your digital wallet or bank account within minutes via automated InstaPay protocol.',
            ),

            // Section 3: No-Show Penalties & GPS (Updated with strict constraints)
            _buildSection(
              context,
              icon: LucideIcons.mapPin,
              title: isAr ? '٣. تتبع الغياب والتحقق الجغرافي' : '3. No-Show Tracking & GPS',
              content: isAr
                  ? 'في حالة الإبلاغ عن "عدم الحضور" لمباراة تم حجزها، يتحقق النظام من موقعك الجغرافي (GPS) للتثبت من وجودك داخل نطاق الملعب (حتى 150 متر + دقة الـ GPS).\n\nيُسمح بتقديم طعن (نزاع) على حالة الغياب خلال نافذة زمنية مدتها 60 دقيقة فقط من وقت انتهاء المباراة، بشرط ألا تتعدى دقة إشارة الـ GPS لجهازك 30 متراً لمنع محاولات التلاعب بالموقع.'
                  : "In case of a reported no-show for a booked match, the system verifies your GPS location to confirm your presence within the stadium perimeter (up to 150m + GPS accuracy).\n\nDisputes can only be filed within a strict 60-minute window after the match ends, provided that your device's GPS accuracy is under 30 meters to prevent spoofing attempts.",
            ),

            // Section 4: Team & Roster Limits
            _buildSection(
              context,
              icon: LucideIcons.users,
              title: isAr ? '٤. قواعد الفرق وحدود التسجيل' : '4. Team & Roster Rules',
              content: isAr
                  ? 'يُسمح لكل فريق بتسجيل ما يصل إلى 12 لاعباً كحد أقصى للقائمة الرسمية. كما يمكن لكل لاعب الانضمام إلى 3 فرق كحد أقصى في نفس الوقت لمنع الاحتكار.\n\nقائمة الفريق يتم التحكم فيها ومطابقتها على مستوى قاعدة البيانات عبر Row-Level Security (RLS) لمنع أي تجاوزات غير مصرح بها.'
                  : 'Each team may register a maximum of 12 players. Each player can join a maximum of 3 teams simultaneously to prevent monopoly.\n\nRoster management is strictly enforced on the database level via Row-Level Security (RLS) to block any unauthorized additions.',
            ),

            // Section 5: Data Sharing
            _buildSection(
              context,
              icon: LucideIcons.share2,
              title: isAr ? '٥. مشاركة البيانات' : '5. Data Sharing',
              content: isAr
                  ? 'لا نبيع بياناتك الشخصية لأي طرف ثالث. قد تُشارك بياناتك بشكل مُجمَّع وغير مُعرَّف مع شركائنا لأغراض التحليل وتحسين الخدمة.\n\nنستخدم خدمات Supabase (قاعدة البيانات)، Firebase (الإحصاءات)، وGoogle Mobile Ads لتشغيل التطبيق. لكل منهم سياسة خصوصية منفصلة ومستقلة.'
                  : 'We do not sell your personal data to any third parties. Aggregated and anonymized data may be shared with our partners for analytics and service improvement. We use Supabase (database), Firebase (analytics), and Google Mobile Ads to operate the app, each governed by their own privacy policy.',
            ),

            // Section 6: Your Rights
            _buildSection(
              context,
              icon: LucideIcons.userCheck,
              title: isAr ? '٦. حقوقك' : '6. Your Rights',
              content: isAr
                  ? 'يحق لك في أي وقت: طلب حذف بياناتك كاملاً، تصحيح معلوماتك الشخصية، أو إلغاء حسابك. للتواصل بشأن أي طلب خصوصية، يرجى التواصل مع فريق الدعم مباشرةً عبر WhatsApp على الرقم: 01100229462.'
                  : 'At any time, you have the right to: request full data deletion, correct your personal data, or cancel your account. For any privacy request, please contact our support team directly via WhatsApp: +201100229462.',
            ),

            const SizedBox(height: 32),
            Center(
              child: Text(
                isAr
                    ? '© جميع الحقوق محفوظة لمنصة VSP الرياضية 2026'
                    : '© VSP Sports Platform 2026 — All Rights Reserved',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: VSPColors.textSecondary.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, {required IconData icon, required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.lg),
          border: Border.all(color: VSPColors.divider.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: VSPColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: VSPColors.accent, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: VSPColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: VSPColors.divider, height: 1),
            const SizedBox(height: 12),
            Text(
              content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: VSPColors.textSecondary,
                    fontSize: 13,
                    height: 1.65,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
