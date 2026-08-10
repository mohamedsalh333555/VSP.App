import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';

class TermsAndPrivacyScreen extends StatelessWidget {
  const TermsAndPrivacyScreen({super.key});

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
          'الشروط والأحكام وسياسة الخصوصية',
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
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: VSPColors.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.shieldCheck, color: VSPColors.accent, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'اتفاقية الاستخدام وحماية البيانات',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'مطابق لقوانين وحماية البيانات المصرية (PDPL 2020)',
                          style: TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: VSPSpacing.lg),

            // Section 1: Terms of Use
            _buildSectionCard(
              context,
              icon: LucideIcons.fileText,
              title: '1. شروط استخدام منصة VSP',
              content: 'تُعتبر منصة VSP وسيطاً تقنياً لتنظيم وتسهيل حجز ملاعب كرة القدم والتحديات التنافسية بين الفرق. يلتزم الحاحزون والكباتن بالحضور في الموعد المحدد والاحترام المتبادل في الملاعب. أي إلغاء للحجز يخضع لسياسة الملعب المحددة.',
            ),

            const SizedBox(height: VSPSpacing.md),

            // Section 2: Privacy Policy (PDPL 2020)
            _buildSectionCard(
              context,
              icon: LucideIcons.lock,
              title: '2. سياسة حماية البيانات والخصوصية',
              content: 'وفقاً لقانون حماية البيانات الشخصية المصري (PDPL 2020)، تُجمع البيانات الأساسية (الاسم، رقم الهاتف، والمحافظة) لغرض تنظيم الحجوزات والتواصل بين كباتن الفرق فقط. تلتزم VSP بعدم مشاركة أو بيع أي من بيانات المستخدمين لأطراف خارجية.',
            ),

            const SizedBox(height: VSPSpacing.md),

            // Section 3: Financial Fees Policy
            _buildSectionCard(
              context,
              icon: LucideIcons.creditCard,
              title: '3. سياسة الرسوم والدفع أونلاين',
              content: 'تتم معالجة جميع المدفوعات الرقمية بشكل آمن عبر بوابة Paymob المرخصة. تُحسب وتظهر رسوم خدمة المنصة ورسوم معالجة الدفع بوضوح في تفاصيل الحساب قبل إتمام الدفع، لتضمن تأكيد الحجز فورياً بنزاهة وشفافية.',
            ),

            const SizedBox(height: VSPSpacing.md),

            // Section 4: League & Dispute Policy
            _buildSectionCard(
              context,
              icon: LucideIcons.trophy,
              title: '4. سياسة نتايج المباريات والـ Elo Rating',
              content: 'يُعتمد إدخال نتائج التحديات بين الكباتن تلقائياً بعد مرور 24 ساعة في حال عدم تقديم اعتراض رسمي من الفريق الخصم، وتُحدث نقاط الترتيب والـ Elo بناءً عليها بنزاهة.',
            ),

            const SizedBox(height: VSPSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
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
          Row(
            children: [
              Icon(icon, color: VSPColors.accent, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
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
