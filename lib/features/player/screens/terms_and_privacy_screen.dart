import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/providers/auth_provider.dart';

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
        leading: IconButton(
          icon: Icon(
            isArabic ? Iconsax.arrow_right_1_copy : Iconsax.arrow_left_2_copy,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
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
            // 🛡️ Header Badge
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
                    ? 'يلتزم صاحب الملعب بدقة بيانات الملعب والمعلومات المعروضة، وتجهيز الإضاءة والمرافق في المواعيد المحجوزة للاعبين. تضمن المنصة تنظيم الحجوزات وعدم التعارض.'
                    : 'Stadium owners must guarantee pitch readiness, lighting, and amenities for confirmed slots. VSP manages technical dispatching to prevent conflicts.',
              ),

              const SizedBox(height: VSPSpacing.md),

              // Section 2: Privacy & Player Data Protection
              _buildSectionCard(
                context,
                title: isArabic ? '2. سياسة حماية بيانات اللاعبين (PDPL 2020)' : '2. Player Privacy & Data Protection',
                content: isArabic
                    ? 'وفقاً لقانون حماية البيانات الشخصية المصري (PDPL 2020)، يلتزم المالك بالحفاظ على خصوصية الحاحزين وعدم استغلال بيانات الاتصال الخاصة باللاعبين خارج نطاق تنظيم المباريات.'
                    : 'Under Egyptian Law PDPL 2020, owners agree to keep player phone numbers strictly confidential and use them only for booking communication.',
              ),

              const SizedBox(height: VSPSpacing.md),

              // Section 3: Payouts & Deposit Guarantee
              _buildSectionCard(
                context,
                title: isArabic ? '3. سياسة التحصيل والعربون المباشر' : '3. Payouts & Deposit Settlement Policy',
                content: isArabic
                    ? 'يلتزم المالك بتأكيد مبالغ العربون والحجوزات المستلمة عبر (انستا باي أو فودافون كاش أو البنك)، والالتزام بتوفير الملعب للحاحز دون تغيير الأسعار أو الإلغاء المفاجئ.'
                    : 'Owners must verify and honor direct deposits received via InstaPay, Vodafone Cash, or Bank Transfer, maintaining fixed rates.',
              ),

              const SizedBox(height: VSPSpacing.md),

              // Section 4: Tournament & Dispute Integrity
              _buildSectionCard(
                context,
                title: isArabic ? '4. نزاهة البطولات والشفافية' : '4. Tournament Integrity & Transparency',
                content: isArabic
                    ? 'يلتزم المالك بإدارة البطولات والتحديات المعروضة على ملعبه بنزاهة تامة، وتأكيد النتائج وتسليم الجوائز المعلنة للفرق الفائزة دون تأخير.'
                    : 'Owners hosting tournaments commit to fair refereeing, prompt score confirmation, and timely prize distribution to winning teams.',
              ),
            ] else ...[
              // Player Terms
              _buildSectionCard(
                context,
                title: isArabic ? '1. شروط استخدام منصة VSP' : '1. Terms of VSP Platform Use',
                content: isArabic
                    ? 'تُعتبر منصة VSP وسيطاً تقنياً لتنظيم وتسهيل حجز ملاعب كرة القدم والتحديات التنافسية بين الفرق. يلتزم الحاحزون والكباتن بالحضور في الموعد المحدد والاحترام المتبادل في الملاعب.'
                    : 'VSP acts as a digital intermediary facilitating pitch bookings and team challenges. Players must attend scheduled times with mutual respect.',
              ),

              const SizedBox(height: VSPSpacing.md),

              _buildSectionCard(
                context,
                title: isArabic ? '2. سياسة حماية البيانات والخصوصية' : '2. Privacy & Data Protection Policy',
                content: isArabic
                    ? 'وفقاً لقانون حماية البيانات الشخصية المصري (PDPL 2020)، تُجمع البيانات الأساسية (الاسم، رقم الهاتف، والمحافظة) لغرض تنظيم الحجوزات والتواصل بين كباتن الفرق فقط. تلتزم VSP بعدم مشاركة أو بيع أي من بيانات المستخدمين لأطراف خارجية.'
                    : 'In accordance with PDPL 2020, basic data is processed strictly for match organization. VSP never sells user data to third parties.',
              ),

              const SizedBox(height: VSPSpacing.md),

              _buildSectionCard(
                context,
                title: isArabic ? '3. سياسة الرسوم والدفع أونلاين' : '3. Payments & Refund Policy',
                content: isArabic
                    ? 'تتم معالجة جميع المدفوعات الرقمية بشكل آمن عبر بوابة Paymob المرخصة. تُحسب وتظهر رسوم خدمة المنصة ورسوم معالجة الدفع بوضوح في تفاصيل الحساب قبل إتمام الدفع.'
                    : 'Digital payments are safely processed via Paymob. Applicable service fees are clearly shown before checkout.',
              ),

              const SizedBox(height: VSPSpacing.md),

              _buildSectionCard(
                context,
                title: isArabic ? '4. سياسة نتائج المباريات والترتيب الرسمي' : '4. Match Results & Ranking Policy',
                content: isArabic
                    ? 'يُعتمد إدخال نتائج التحديات بين الكباتن تلقائياً بعد مرور 24 ساعة في حال عدم تقديم اعتراض رسمي من الفريق الخصم، وتُحدث نقاط الترتيب بناءً عليها بنزاهة.'
                    : 'Captains submit challenge scores post-match. Uncontested scores are verified within 24 hours to update rankings.',
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
