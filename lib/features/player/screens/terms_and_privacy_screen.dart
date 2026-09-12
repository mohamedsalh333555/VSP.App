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
                title: isArabic ? '1. شروط وإلتزامات تشغيل الملاعب والأهلية' : '1. Stadium Operations & Age Eligibility',
                content: isArabic
                    ? '• يلتزم صاحب الملعب بدقة بيانات الملعب والمعلومات المعروضة، وتجهيز الإضاءة والمرافق في المواعيد المحجوزة للاعبين دون أي تأخير أو تغيير في السعر المتفق عليه. تضمن المنصة تنظيم الحجوزات بدقة ومنع التضارب.\n• يُشترط في المفوض بإدارة حساب المنشأة الرياضية (صاحب الملعب) أو التوقيع على التعاقدات ألا يقل عمره عن 21 عاماً وأن يتمتع بالأهلية القانونية الكاملة للتعاقد وإدارة المنشأة.'
                    : '• Stadium owners must guarantee pitch readiness, lighting, and amenities for confirmed slots without rate changes or delays. VSP ensures technical dispatching to prevent slot conflicts.\n• Authorized venue managers and signatories must be at least 21 years of age and possess full legal capacity to contract and manage operations.',
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
                title: isArabic ? '4. نزاهة البطولات والجوائز وحظر المراهنات' : '4. Tournament Integrity & Anti-Wagering Policy',
                content: isArabic
                    ? 'يلتزم المالك بإدارة البطولات والتحديات المعروضة على ملعبه بنزاهة تامة وفقاً لقواعد المهارة الرياضية وتكافؤ الفرص، وتأكيد النتائج وتسليم الجوائز المعلنة للفرق الفائزة دون تأخير. رسوم الاشتراك مخصصة حصرياً لتغطية تكاليف التنظيم والتشغيل، والجوائز برعاية VSP والجهات الراعية، مع الحظر التام والمطلق لأي رهان أو مقامرة.'
                    : 'Owners hosting tournaments commit to fair refereeing, adhering to skill-based brackets, and promptly distributing announced prizes. Entry fees strictly cover operational expenses; awards are sponsored by VSP and partners with an absolute ban on wagering.',
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

              const SizedBox(height: VSPSpacing.md),

              // Section 6: Jurisdiction
              _buildSectionCard(
                context,
                title: isArabic ? '6. القانون الواجب التطبيق والاختصاص القضائي' : '6. Governing Law & Jurisdiction',
                content: isArabic
                    ? 'تخضع هذه الشروط وكافة المعاملات الناتجة عنها وتُفسر وفقاً لقوانين جمهورية مصر العربية، وتختص محاكم أسوان بنظر أي نزاع قضائي قد ينشأ بخصوص هذه الاتفاقية.'
                    : 'These terms and all resulting transactions are governed by the laws of the Arab Republic of Egypt. The courts of Aswan hold exclusive jurisdiction over any legal disputes.',
              ),

              const SizedBox(height: VSPSpacing.md),

              // Section 7: Contact Info
              _buildSectionCard(
                context,
                title: isArabic ? '7. بيانات المقر والتواصل الرسمي' : '7. Official Headquarters & Contact',
                content: isArabic
                    ? '• المقر الرئيسي: أسوان، جمهورية مصر العربية.\n• البريد الإلكتروني الرسمي: vspapp.eg@gmail.com\n• الدعم الفني وخدمة العملاء: +201100229462 (متاح عبر WhatsApp).'
                    : '• Headquarters: Aswan, Arab Republic of Egypt.\n• Official Email: vspapp.eg@gmail.com\n• Customer Support: +201100229462 (available via WhatsApp).',
              ),
            ] else ...[
              // Player Terms
              _buildSectionCard(
                context,
                title: isArabic ? '1. طبيعة المنصة وشروط الأهلية' : '1. Platform Services & Eligibility',
                content: isArabic
                    ? '• تُعد منصة VSP وسيطاً تقنياً لتنظيم وتسهيل حجز ملاعب كرة القدم والمباريات التنافسية.\n• يُشترط ألا يقل عمر المستخدم العادي (اللاعب) عن 16 عاماً، أو أن تتم المعاملات المالية تحت إشراف ولي الأمر.\n• يلتزم اللاعبون بالحضور في الموعد المحدد والتحلي بالأخلاق والروح الرياضية واحترام منشآت ومرافق الملعب المضيف.'
                    : '• VSP operates as a digital platform facilitating pitch bookings and competitive matches.\n• Regular users (players) must be at least 16 years of age, or conduct financial transactions under parental supervision.\n• Players must arrive on time and uphold sportsmanship and respect facility amenities.',
              ),

              const SizedBox(height: VSPSpacing.md),

              _buildSectionCard(
                context,
                title: isArabic ? '2. سياسة الإلغاء والاسترداد المالي (Paymob)' : '2. Cancellation & Paymob Refund Policy',
                content: isArabic
                    ? '• الإلغاء المبكر (أكثر من 6 ساعات قبل المباراة): استرداد مالي كامل (100%) يتم استرجاعه تلقائياً لنفس وسيلة الدفع الأصلية عبر بوابة Paymob مباشرة.\n• البطولات الرياضية: يُسمح بالإلغاء واسترداد رسوم الاشتراك بالكامل قبل انطلاق البطولة بيومين (48 ساعة) وقبل إجراء القرعة الرسمية.\n• مهلة الـ 20 دقيقة الأولى: عند إلغاء الحجز خلال أول 20 دقيقة من إتمامه وسداده، يُسترد المبلغ مخصوماً منه المصاريف الإدارية والتشغيلية غير المستردة (رسوم بوابة الدفع الإلكتروني).\n• مدة الاسترداد ونافذة الـ 90 يوماً: يستغرق ظهور المبلغ في الحساب من 3 إلى 7 أيام عمل وفقاً لدورة المقاصة بالبنك المصدر (شريطة تقديم طلب الاسترداد خلال 90 يوماً كحد أقصى من تاريخ العملية وفقاً لسياسة Paymob).\n• الإلغاء المتأخر (أقل من 6 ساعات) أو عدم الحضور (No-Show) لا يمنح الحق في استرداد المبالغ المدفوعة.'
                    : '• Early Cancellation (over 6 hours prior to match): Full 100% refund processed automatically back to the original payment method via Paymob.\n• Tournaments: Full refund when withdrawing at least 48 hours prior to kickoff and before the official bracket draw.\n• 20-Minute Grace Window: Cancellations within the first 20 minutes of booking are refunded minus non-refundable gateway processing fees.\n• Bank Settlement & 90-Day Window: Refunds reflect within 3-7 business days per issuer clearing cycles (provided refund requests are initiated within a 90-day maximum window per Paymob policy).\n• Late cancellations or no-shows forfeit refunds.',
              ),

              const SizedBox(height: VSPSpacing.md),

              // Section 3: Fees & Pricing Transparency
              _buildSectionCard(
                context,
                title: isArabic ? '3. أمان المدفوعات والشفافية (PCI-DSS & Paymob)' : '3. Payment Security & Transparency (PCI-DSS & Paymob)',
                content: isArabic
                    ? '• تتم معالجة كافة المدفوعات الإلكترونية عبر بيئة مشفرة تديرها بوابة الدفع المعتمدة Paymob والممتثلة لمعايير أمان بطاقات الدفع العالمية (PCI-DSS). لا نقوم بحفظ أرقام البطاقات السرية أو رموز CVC.\n• الشفافية ومنع الرسوم الخفية: يظهر إجمالي المبلغ المطلوب سداده وتفاصيله بوضوح في شاشة تأكيد الحجز قبل إتمام أي عملية دفع، ولا توجد أي رسوم غير معلنة.\n• الحجز النقدي: عند اختيار السداد النقدي بالملعب، يدفع اللاعب قيمة إيجار الملعب المحددة من الإدارة دون أي رسوم معالجة دفع رقمي إضافية من المنصة.'
                    : '• All electronic transactions are processed through encrypted environments managed by certified gateway Paymob, complying with global Payment Card Industry Data Security Standards (PCI-DSS). We do not store CVV/PINs.\n• Full Transparency: Total breakdown is itemized before checkout with zero hidden fees.\n• Cash bookings cover regular venue rental without digital payment processing charges.',
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
                title: isArabic ? '5. نزاهة البطولات والتحديات ومنع المراهنات' : '5. Tournament Integrity & Anti-Wagering Policy',
                content: isArabic
                    ? '• بطولات كروية تنافسية بالكامل على أساس المهارة والأداء الرياضي. رسوم الاشتراك تُستخدم حصرياً لتغطية تكاليف تنظيم البطولة. الجوائز والكؤوس مقدَّمة من VSP والجهات الراعية للبطولة، وليست ممولة من رسوم اشتراك الفرق المتنافسة.\n• حظر تام للرهانات والمقامرة: نظام التحديات ونقاط Elo هو نظام تقني لقياس المهارة الرياضية فقط؛ يُحظر حظراً قاطعاً استخدام المنصة لأي مراهنات مالية أو مقامرة، وأي مخالفة تؤدي للحظر النهائي والمساءلة القانونية.\n• يلتزم كباتن الفرق بإدخال النتائج الحقيقية بعد المباراة بنزاهة وشفافية.'
                    : '• Purely skill-based competitive sports tournaments. Entry fees are utilized exclusively to cover operational costs. Trophies and prizes are sponsored by VSP and official partners and are not funded by competitor fees.\n• Strict Anti-Wagering Ban: The challenge and Elo system measures athletic skill only; monetary betting or gambling is strictly prohibited and results in permanent ban and legal liability.\n• Team captains must submit truthful, verified match results.',
              ),

              const SizedBox(height: VSPSpacing.md),

              _buildSectionCard(
                context,
                title: isArabic ? '6. قواعد الفرق وحقوق الخصوصية وحذف الحساب' : '6. Team Rules, Privacy & Account Erasure',
                content: isArabic
                    ? '• الحد الأقصى لقائمة الفريق هو 12 لاعباً، ويحق للاعب الانضمام إلى 3 فرق كحد أقصى.\n• نحن لا نبيع أو نؤجر بياناتك الشخصية لأي طرف ثالث نهائياً.\n• يحق لك في أي وقت تعديل بياناتك أو طلب حذف حسابك وكافة سجلاتك نهائياً من داخل التطبيق عبر: (الملف الشخصي -> حذف الحساب) أو بمراسلة فريق الدعم الفني.'
                    : '• Max 12 players per team roster, and players can join up to 3 teams.\n• We never sell or lease personal data to third parties.\n• You have the right to edit data or request permanent account deletion via Profile -> Delete Account or contacting support.',
              ),

              const SizedBox(height: VSPSpacing.md),

              // Section 7: Jurisdiction
              _buildSectionCard(
                context,
                title: isArabic ? '7. القانون الواجب التطبيق والاختصاص القضائي' : '7. Governing Law & Jurisdiction',
                content: isArabic
                    ? 'تخضع هذه الشروط وكافة المعاملات الناتجة عنها وتُفسر وفقاً لقوانين جمهورية مصر العربية، وتختص محاكم أسوان بنظر أي نزاع قضائي قد ينشأ بخصوص هذه الاتفاقية.'
                    : 'These terms and all resulting transactions are governed by the laws of the Arab Republic of Egypt. The courts of Aswan hold exclusive jurisdiction over any legal disputes.',
              ),

              const SizedBox(height: VSPSpacing.md),

              // Section 8: Contact Info
              _buildSectionCard(
                context,
                title: isArabic ? '8. بيانات المقر والتواصل الرسمي' : '8. Official Headquarters & Contact',
                content: isArabic
                    ? '• المقر الرئيسي: أسوان، جمهورية مصر العربية.\n• البريد الإلكتروني الرسمي: vspapp.eg@gmail.com\n• الدعم الفني وخدمة العملاء: +201100229462 (متاح عبر WhatsApp).'
                    : '• Headquarters: Aswan, Arab Republic of Egypt.\n• Official Email: vspapp.eg@gmail.com\n• Customer Support: +201100229462 (available via WhatsApp).',
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
