import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/vsp_back_button.dart';

class TermsAndPrivacyScreen extends StatelessWidget {
  const TermsAndPrivacyScreen({super.key});

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
        leading: const VSPBackButton(),
        centerTitle: true,
        title: Text(
          isOwner
              ? (isArabic ? 'شروط وسياسة أصحاب الملاعب' : 'Stadium Owner Policy & Terms')
              : (isArabic ? 'الشروط والأحكام وسياسة الخصوصية' : 'Terms of Service & Privacy Policy'),
          style: Theme.of(context).textTheme.displaySmall,
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(VSPSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Badge
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
                  Text(
                    isOwner
                        ? (isArabic ? 'اتفاقية تشغيل وحماية أصحاب الملاعب' : 'Stadium Operator & Data Agreement')
                        : (isArabic ? 'اتفاقية الاستخدام وحماية البيانات' : 'Terms of Use & Data Agreement'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isArabic
                        ? 'مطابق لقوانين وحماية البيانات المصرية (PDPL 2020)'
                        : 'Compliant with Egyptian Data Protection Law (PDPL 2020)',
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: VSPSpacing.lg),

            if (isOwner) ...[
              // Section 1: Stadium Operation Terms
              _buildSectionCard(
                context,
                title: isArabic ? '1. شروط وإلتزامات تشغيل الملاعب' : '1. Stadium Operations & Listing Terms',
                content: isArabic
                    ? 'يلتزم صاحب الملعب بدقة بيانات الملعب والمعلومات المعروضة، وتجهيز الإضاءة والمرافق في المواعيد المحجوزة للاعبين دون أي تأخير أو تغيير في السعر المتفق عليه. تضمن المنصة تنظيم الحجوزات بدقة ومنع التضارب.'
                    : 'Stadium owners must guarantee pitch readiness, lighting, and amenities for confirmed slots without rate changes or delays. VSP ensures technical dispatching to prevent slot conflicts.',
              ),

              const SizedBox(height: VSPSpacing.md),

              // Section 2: Payouts & Deposit Settlement Policy
              _buildSectionCard(
                context,
                title: isArabic ? '2. سياسة العربون والتحصيل المباشر' : '2. Direct Deposit & Payout Policy',
                content: isArabic
                    ? 'يلتزم المالك بتأكيد مبالغ العربون والحجوزات المستلمة مباشرة عبر (انستا باي أو فودافون كاش أو التحويل البنكي) وتحديث حالة الحجز في التطبيق فور استلام المبلغ، والالتزام بتوفير الملعب للحاجز.'
                    : 'Owners must promptly verify and confirm direct deposits received via InstaPay, Vodafone Cash, or Bank Transfer in-app, honoring the reservation for the player.',
              ),

              const SizedBox(height: VSPSpacing.md),

              // Section 3: Sudden Cancellation Prohibition
              _buildSectionCard(
                context,
                title: isArabic ? '3. سياسة منع الإلغاء المفاجئ' : '3. Cancellation & Commitment Policy',
                content: isArabic
                    ? 'يُحظر على صاحب الملعب إلغاء أي حجز مؤكد إلا في حالات القوة القاهرة المثبتة، مع الالتزام بإخطار الحاجز وإعادة كامل العربون أو المبالغ المدفوعة إليه فوراً دون أي اقتطاع.'
                    : 'Owners are prohibited from cancelling confirmed bookings except in proven force majeure cases, with mandatory immediate full refund to the customer.',
              ),

              const SizedBox(height: VSPSpacing.md),

              // Section 4: Tournament & Dispute Integrity
              _buildSectionCard(
                context,
                title: isArabic ? '4. نزاهة البطولات والجوائز' : '4. Tournament Integrity & Prizes',
                content: isArabic
                    ? 'يلتزم المالك بإدارة البطولات والتحديات المعروضة على ملعبه بنزاهة تامة، والالتزام بالجدول المعلن، وتأكيد النتائج وتسليم الجوائز المعلنة للفرق الفائزة دون تأخير.'
                    : 'Owners hosting tournaments commit to fair refereeing, strictly adhering to scheduled brackets, and promptly distributing announced prizes to winning teams.',
              ),

              const SizedBox(height: VSPSpacing.md),

              // Section 5: Privacy & Player Data Protection
              _buildSectionCard(
                context,
                title: isArabic ? '5. سياسة حماية بيانات اللاعبين (PDPL 2020)' : '5. Player Privacy & Data Protection',
                content: isArabic
                    ? 'وفقاً لقانون حماية البيانات الشخصية المصري (PDPL 2020)، يلتزم المالك بالحفاظ على سرية وخصوصية الحاجزين وعدم استخدام أو استغلال بيانات الاتصال الخاصة باللاعبين في أي أغراض تسويقية أو خارج نطاق تنظيم المباريات.'
                    : 'Under Egyptian Law PDPL 2020, owners agree to keep player contact information strictly confidential and use it solely for match coordination.',
              ),
            ] else ...[
              // Player Terms
              _buildSectionCard(
                context,
                title: isArabic ? '1. طبيعة المنصة واستخدام خدمة VSP' : '1. VSP Platform Services & Usage',
                content: isArabic
                    ? 'تُعد منصة VSP وسيطاً تقنياً لتنظيم وتسهيل حجز ملاعب كرة القدم والمباريات التنافسية. إدارة الملعب هي المسؤولة عن سلامة المنشأة والمرافق. يلتزم اللاعبون بالحضور في الموعد المحدد والتحلي بالأخلاق الرياضية داخل الملعب.'
                    : 'VSP acts as a digital intermediary facilitating pitch bookings and competitive matches. Facility management is responsible for pitch readiness. Players must arrive on time and uphold sportsmanship.',
              ),

              const SizedBox(height: VSPSpacing.md),

              _buildSectionCard(
                context,
                title: isArabic ? '2. سياسة الإلغاء والاسترداد المالي' : '2. Cancellation & Refund Policy',
                content: isArabic
                    ? '• يُسمح بإلغاء الحجز حتى قبل موعد بدء المباراة بساعتين (2 Hours) للحصول على استرداد مالي كامل.\n• تتم معالجة ومراجعة طلبات الاسترداد المالي من قِبل فريق VSP خلال 3-5 أيام عمل عبر وسيلة الدفع الأصلية أو التحويل المباشر.\n• الإلغاء بعد انتهاء المهلة المحددة (أقل من ساعتين) أو عدم الحضور (No-Show) لا يمنح الحق في استرداد العربون أو المبالغ المدفوعة.'
                    : '• Free cancellation is available up to 2 hours before kickoff for a full refund.\n• Refund requests are processed by the VSP team within 3-5 business days via the original payment method or direct transfer.\n• Late cancellations (within 2 hours) or no-shows forfeit deposit/fee refunds.',
              ),

              const SizedBox(height: VSPSpacing.md),

              // Section 3: Fees & Pricing Transparency
              _buildSectionCard(
                context,
                title: isArabic ? '3. سياسة الرسوم والشفافية المالية' : '3. Fees & Pricing Transparency',
                content: isArabic
                    ? '• طبيعة الرسوم: عند الحجز الإلكتروني، قد يُضاف مبلغ خدمة وتشغيل تقني ورسوم معالجة مصرفية لتغطية تكاليف السيرفرات السحابية وتأمين المواعيد وبوابات الدفع البنكية المرخصة (Paymob).\n• الشفافية ومنع الرسوم الخفية: يظهر إجمالي المبلغ المطلوب سداده وتفاصيله بوضوح في شاشة تأكيد الحجز قبل إتمام أي عملية دفع، ولا توجد أي رسوم غير معلنة.\n• الحجز النقدي: عند اختيار السداد النقدي بالملعب، يدفع اللاعب قيمة إيجار الملعب المحددة من الإدارة دون أي رسوم معالجة دفع رقمي إضافية من المنصة.'
                    : '• Nature of Fees: For online bookings, platform service and banking processing fees cover cloud servers, real-time lock security, and licensed payment gateways (Paymob).\n• Full Transparency: Total payable amounts are clearly itemized before checkout with zero hidden fees.\n• Cash Bookings: Direct on-pitch cash payments cover standard pitch rental only without digital processing charges.',
              ),

              const SizedBox(height: VSPSpacing.md),

              _buildSectionCard(
                context,
                title: isArabic ? '4. سياسة تتبع الحضور والغياب (No-Show)' : '4. Attendance & No-Show Policy',
                content: isArabic
                    ? '• تسجيل حالتي (2) غياب يؤدي إلى تقييد ميزة الحجز النقدي المباشر.\n• تسجيل 3 حالات غياب متكررة يؤدي إلى تعليق الحساب لحماية أوقات الملاعب واللاعبين الآخرين.\n• يمكن للاعب تقديم طعن جغرافي (GPS) لإثبات الحضور خلال 60 دقيقة من نهاية المباراة، بشرط التواجد ضمن نطاق 150 متراً من الملعب بدقة GPS تقل عن 50 متراً.'
                    : '• 2 recorded no-shows restrict cash booking privileges.\n• 3 recorded no-shows lead to account suspension.\n• Players can dispute a no-show via GPS within 60 minutes post-match if present within 150m of the stadium with GPS accuracy under 50m.',
              ),

              const SizedBox(height: VSPSpacing.md),

              _buildSectionCard(
                context,
                title: isArabic ? '5. نزاهة التحديات وترتيب الـ Elo' : '5. Challenge Matches & Elo Ranking',
                content: isArabic
                    ? 'يلتزم كباتن الفرق بإدخال النتائج الحقيقية بعد المباراة. في حال وجود نزاع أو تضارب في النتائج، تُجمد نقاط الترتيب تلقائياً لحين المراجعة الإدارية. أي تلاعب متعمد بالنتائج يعرض الحساب للحظر النهائي.'
                    : 'Captains must submit truthful match results. Disputed outcomes freeze ranking points for administrative review. Intentional result manipulation results in permanent ban.',
              ),

              const SizedBox(height: VSPSpacing.md),

              _buildSectionCard(
                context,
                title: isArabic ? '6. قواعد الفرق وحماية البيانات والخصوصية' : '6. Team Rules, Privacy & Data Rights',
                content: isArabic
                    ? '• الحد الأقصى لقائمة الفريق هو 12 لاعباً، ويحق للاعب الانضمام إلى 3 فرق كحد أقصى.\n• لا نبيع أو نؤجر بياناتك الشخصية لأي طرف ثالث نهائياً.\n• يحق لك تعديل بياناتك أو حذف حسابك وكافة سجلاتك نهائياً من داخل التطبيق (الملف الشخصي -> حذف الحساب) في أي وقت.\n• للدعم والاستفسارات: WhatsApp على 01100229462.'
                    : '• Max 12 players per team roster, and players can join up to 3 teams.\n• We never sell personal data to third parties.\n• You may edit or permanently delete your account and all data directly in-app at any time.\n• For support: WhatsApp +201100229462.',
              ),
            ],

            const SizedBox(height: VSPSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }
}
