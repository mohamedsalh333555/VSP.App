import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
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
          icon: const Icon(Iconsax.arrow_left_2_copy, color: VSPColors.textPrimary),
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
                      const Icon(Iconsax.security_safe_copy, color: VSPColors.accent, size: 20),
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
              icon: Iconsax.data_copy,
              title: isAr ? '١. البيانات التي نجمعها' : '1. Data We Collect',
              content: isAr
                  ? 'نقوم بجمع البيانات التي تُدخلها مباشرةً عند إنشاء حسابك، وتشمل: الاسم، رقم الهاتف، تاريخ الميلاد، المحافظة، صورة الملف الشخصي، والمركز المفضل (مهاجم / حارس / إلخ).'
                  : 'We collect data you provide directly when creating your account, including: name, phone number, date of birth, governorate, profile image, and preferred position (Striker / GK / etc.).',
            ),

            // Section 2: Payments via Paymob (Updated to 2 Hours)
            _buildSection(
              context,
              icon: Iconsax.wallet_1_copy,
              title: isAr ? '٢. الدفع والمبالغ المستردة' : '2. Payments & Refunds',
              content: isAr
                  ? 'تتم معالجة جميع المدفوعات الرقمية داخل التطبيق بشكل آمن عبر بوابة Paymob المرخصة في مصر. تُحسب وتظهر رسوم خدمة المنصة ورسوم بوابة الدفع بوضوح في تفاصيل الفاتورة قبل إتمام الدفع. لا يتم تخزين بيانات البطاقة المصرفية على خوادمنا في أي وقت.\n\nعند إلغاء الحجز قبل انتهاء وقت السماح (ساعتين قبل موعد المباراة)، يتم استرداد المبالغ المستحقة تلقائياً ومباشرةً إلى وسيلة الدفع الأصلية التي تم الدفع منها (الحساب البنكي / المحفظة الإلكترونية / انستا باي).'
                  : 'All in-app digital payments are processed securely through Paymob, a licensed payment gateway in Egypt. Applicable platform service fees and gateway processing charges are clearly displayed before payment confirmation. Card or account credentials are never stored on our servers.\n\nUpon eligible cancellation (up to 2 hours before kickoff), refunds are automatically credited directly to your original payment method (Bank Account / E-Wallet / InstaPay).',
            ),

            // Section 3: No-Show Penalties & GPS (Updated with strict constraints)
            _buildSection(
              context,
              icon: Iconsax.location_copy,
              title: isAr ? '٣. تتبع الغياب والتحقق الجغرافي' : '3. No-Show Tracking & GPS',
              content: isAr
                  ? 'في حالة الإبلاغ عن "عدم الحضور" لمباراة تم حجزها، يتحقق النظام من موقعك الجغرافي (GPS) للتثبت من وجودك داخل نطاق الملعب (حتى 150 متر + دقة الـ GPS).\n\nيُسمح بتقديم طعن (نزاع) على حالة الغياب خلال نافذة زمنية مدتها 60 دقيقة فقط من وقت انتهاء المباراة، بشرط ألا تتعدى دقة إشارة الـ GPS لجهازك 50 متراً لمنع محاولات التلاعب بالموقع.'
                  : "In case of a reported no-show for a booked match, the system verifies your GPS location to confirm your presence within the stadium perimeter (up to 150m + GPS accuracy).\n\nDisputes can only be filed within a strict 60-minute window after the match ends, provided that your device's GPS accuracy is under 50 meters to prevent spoofing attempts.",
            ),

            // Section 4: Team & Roster Limits
            _buildSection(
              context,
              icon: Iconsax.people_copy,
              title: isAr ? '٤. قواعد الفرق وحدود التسجيل' : '4. Team & Roster Rules',
              content: isAr
                  ? 'يُسمح لكل فريق بتسجيل ما يصل إلى 12 لاعباً كحد أقصى للقائمة الرسمية. كما يمكن لكل لاعب الانضمام إلى 3 فرق كحد أقصى في نفس الوقت لمنع الاحتكار.\n\nقائمة الفريق يتم التحكم فيها ومطابقتها على مستوى قاعدة البيانات عبر Row-Level Security (RLS) لمنع أي تجاوزات غير مصرح بها.'
                  : 'Each team may register a maximum of 12 players. Each player can join a maximum of 3 teams simultaneously to prevent monopoly.\n\nRoster management is strictly enforced on the database level via Row-Level Security (RLS) to block any unauthorized additions.',
            ),

            // Section 5: Data Sharing
            _buildSection(
              context,
              icon: Iconsax.share_copy,
              title: isAr ? '٥. مشاركة البيانات والبيئة السحابية' : '5. Data Sharing & Cloud Infrastructure',
              content: isAr
                  ? 'لا نبيع بياناتك الشخصية لأي طرف ثالث نهائياً. تُخزن وتُعالج البيانات بأمان على خوادم Supabase السحابية المخصصة (قاعدة البيانات والتحقق)، مع استخدام Firebase لإحصاءات الأداء وتنبيهات الإشعارات اللحظية. لكل منها سياسة خصوصية وأمان سحابية مستقلة وخاضعة لشهادات الأمان العالمية.'
                  : 'We do not sell your personal data to any third parties under any circumstances. Data is securely stored and processed using Supabase cloud infrastructure (Database & Authentication) and Firebase for performance analytics and instant push notification delivery.',
            ),

            // Section 6: Your Rights & Account Deletion
            _buildSection(
              context,
              icon: Iconsax.user_tick_copy,
              title: isAr ? '٦. حقوقك وتحديث أو حذف الحساب' : '6. Your Rights & Account Deletion',
              content: isAr
                  ? 'تطبيقاً لمتطلبات المتاجر الرسمية وقانون حماية البيانات، يمكنك في أي وقت:\n• حذف حسابك وكافة بياناتك الشخصية نهائياً ومباشرةً من داخل التطبيق عبر خيار (تعديل الملف الشخصي -> حذف الحساب).\n• تعديل بياناتك الشخصية بروفايلك أو إلغاء الاشتراك من الخدمة.\n• التواصل المباشر مع فريق الدعم الفني عبر WhatsApp على الرقم: 01100229462 لأي استفسارات تتعلق بالخصوصية.'
                  : 'In compliance with official app store guidelines (Apple 5.1.1 & Google Play) and data protection regulations, you may at any time:\n• Permanently delete your account and all associated personal records directly within the app via (Edit Profile -> Delete Account).\n• Update or rectify your profile information.\n• Reach out directly to our support team via WhatsApp: +201100229462 for any privacy concerns.',
            ),

            // Section 7: Permissions, Chat Policy & Minimum Age
            _buildSection(
              context,
              icon: Iconsax.shield_tick_copy,
              title: isAr ? '٧. أذونات التطبيق وسلوك الدردشة والسن الأدنى' : '7. App Permissions, Chat Policy & Minimum Age',
              content: isAr
                  ? '• الأذونات (App Permissions): يطلب التطبيق أذونات الكاميرا/الصور لرفع صورة البروفايل وصور الملاعب ومستندات التوثيق، والموقع الجغرافي (GPS) لاقتراح الملاعب القريبة وطعون الغياب، والإشعارات لتأكيدات الحجز.\n• المحادثات والمحتوى (Chat & UGC Policy): تُحظر أي رسائل احتيالية أو مسيئة في الدردشة الفورية. يوفر التطبيق ميزة الحظر والإبلاغ الفوري، وللإدارة الحق في حظر الحساب المخالف نهائياً.\n• السن الأدنى للاستخدام: يُخصص التطبيق للاستخدام لمن هم بعمر 13 سنة فأكثر، أو بموافقة ولي الأمر للأنشطة الرياضية تحت السن القانوني.'
                  : '• App Permissions: Requested solely for profile/stadium photo uploads (Camera/Gallery), nearby pitch detection & no-show verification (GPS), and booking notifications (FCM).\n• Chat & User Generated Content (UGC): Fraudulent, harassing, or inappropriate messaging is strictly prohibited. Instant block/report options are provided, and VSP reserves the right to terminate violating accounts.\n• Minimum Age: The platform is intended for users aged 13 and above, or with parental/guardian approval for minors participating in sports activities.',
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
