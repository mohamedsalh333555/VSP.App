import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../core/ui/tokens/vsp_tokens.dart';
import '../widgets/primary_button.dart';
import '../widgets/vsp_icon_badge.dart';

/// Modal dialog displaying Terms of Service & Privacy Policy.
class VSPTermsAndPrivacyModal {
  static void show(BuildContext context, {bool isOwner = false}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        final isAr = Localizations.localeOf(dialogContext).languageCode == 'ar';
        final titleText = isAr ? 'الشروط وأحكام الخصوصية' : 'Terms & Privacy Policy';
        final buttonText = isAr ? 'موافق' : 'I Understand';

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(dialogContext).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.xl),
                border: Border.all(color: VSPColors.divider, width: 1),
                boxShadow: VSPShadow.strongList,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
                    child: Row(
                      children: [
                        const VSPIconBadge(
                          icon: Iconsax.security_safe_copy,
                          color: VSPColors.accent,
                          size: 36,
                          iconSize: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            titleText,
                            style: Theme.of(dialogContext).textTheme.titleMedium?.copyWith(
                              color: VSPColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Iconsax.close_circle_copy, color: VSPColors.textSecondary, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: VSPColors.divider, height: 1),

                  // Content Body
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Badge
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: VSPColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(VSPRadius.lg),
                              border: Border.all(color: VSPColors.divider),
                            ),
                            child: Row(
                              children: [
                                const Icon(Iconsax.info_circle_copy, color: VSPColors.textSecondary, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    isAr
                                        ? 'معلومات الشروط والخصوصية وحماية البيانات'
                                        : 'Terms, privacy and data protection information',
                                    style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                                      color: VSPColors.accent,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (isOwner) ...[
                            _buildSectionCard(
                              dialogContext,
                              icon: Iconsax.building_copy,
                              title: isAr ? '١. شروط وإلتزامات تشغيل الملاعب والأهلية' : '1. Stadium Operations & Age Eligibility',
                              content: isAr
                                  ? '• يلتزم صاحب الملعب بدقة بيانات الملعب والمعلومات المعروضة، وتجهيز الإضاءة والمرافق في المواعيد المحجوزة للاعبين دون أي تأخير أو تغيير في السعر المتفق عليه. تضمن المنصة تنظيم الحجوزات بدقة ومنع التضارب.\n• يُشترط ألا يقل عمر صاحب حساب المالك عن 18 عاماً لاستخدام المنصة، وألا يقل عمر المفوض بالتوقيع على التعاقدات التجارية للمنشأة عن 21 عاماً وفقاً للأهلية القانونية الكاملة بموجب القانون المصري.'
                                  : '• Stadium owners must guarantee pitch readiness, lighting, and amenities for confirmed slots without rate changes or delays. VSP ensures technical dispatching to prevent slot conflicts.\n• Account holders must be at least 18 years of age to use the platform, while authorized signatories for commercial venue agreements must be at least 21 years of age with full legal capacity.',
                            ),
                            const SizedBox(height: 12),
                            _buildSectionCard(
                              dialogContext,
                              icon: Iconsax.wallet_1_copy,
                              title: isAr ? '٢. السداد الإلكتروني والعمولة وصرف المستحقات' : '2. Online Payment, Commission & Payout Policy',
                              content: isAr
                                  ? 'تُسدد جميع الحجوزات الجديدة بالكامل أونلاين (100%) عبر بوابة Paymob المعتمدة دون إتاحة الدفع النقدي أو العربون للحجوزات الجديدة (مع بقاء الإيصالات التاريخية خاضعة لقواعد وقت إنشائها). تُخصم عمولة المنصة (5%) من سعر الملعب الأساسي دون خصم رسوم الدفع الخاصة باللاعب، وتُتاح المستحقات للسحب بعد إتمام الحجز عبر إنستاباي أو المحافظ الإلكترونية أو التحويل البنكي.'
                                  : 'All new bookings are paid 100% online via Paymob; cash and deposit modes are retired for new bookings (historical receipts remain governed by rules at creation time). Only the 5% VSP commission is deducted from the base pitch price (player gateway fees are never deducted from owner earnings), and payouts are withdrawable post-match via InstaPay, Mobile Wallet, or Bank Transfer.',
                            ),
                            const SizedBox(height: 12),
                            _buildSectionCard(
                              dialogContext,
                              icon: Iconsax.shield_cross_copy,
                              title: isAr ? '٣. سياسة منع الإلغاء المفاجئ' : '3. Cancellation & Commitment Policy',
                              content: isAr
                                  ? 'يُحظر على صاحب الملعب إلغاء أي حجز مؤكد إلا في حالات القوة القاهرة المثبتة، مع الالتزام بإخطار الحاجز وإعادة كامل المبالغ المدفوعة إليه فوراً دون أي اقتطاع.'
                                  : 'Owners are prohibited from cancelling confirmed bookings except in proven force majeure cases, with mandatory immediate full refund to the customer.',
                            ),
                            const SizedBox(height: 12),
                            _buildSectionCard(
                              dialogContext,
                              icon: Iconsax.cup_copy,
                              title: isAr ? '٤. نزاهة البطولات والجوائز وحظر المراهنات' : '4. Tournament Integrity & Anti-Wagering Policy',
                              content: isAr
                                  ? 'يلتزم المالك بإدارة البطولات والتحديات المعروضة على ملعبه بنزاهة تامة وفقاً لقواعد المهارة الرياضية وتكافؤ الفرص، وتأكيد النتائج وتسليم الجوائز المعلنة للفرق الفائزة دون تأخير. رسوم الاشتراك مخصصة حصرياً لتغطية تكاليف التنظيم والتشغيل، والجوائز برعاية VSP والجهات الراعية، مع الحظر التام والمطلق لأي رهان أو مقامرة.'
                                  : 'Owners hosting tournaments commit to fair refereeing, adhering to skill-based brackets, and promptly distributing announced prizes. Entry fees strictly cover operational expenses; awards are sponsored by VSP and partners with an absolute ban on wagering.',
                            ),
                            const SizedBox(height: 12),
                            _buildSectionCard(
                              dialogContext,
                              icon: Iconsax.lock_copy,
                              title: isAr ? '٥. سياسة حماية بيانات اللاعبين (PDPL 2020)' : '5. Player Privacy & Data Protection',
                              content: isAr
                                  ? 'وفقاً لقانون حماية البيانات الشخصية المصري (PDPL 2020)، يلتزم المالك بالحفاظ على سرية وخصوصية الحاجزين وعدم استخدام أو استغلال بيانات الاتصال الخاصة باللاعبين في أي أغراض تسويقية أو خارج نطاق تنظيم المباريات.'
                                  : 'Under Egyptian Law PDPL 2020, owners agree to keep player contact information strictly confidential and use it solely for match coordination.',
                            ),
                            const SizedBox(height: 12),
                            _buildSectionCard(
                              dialogContext,
                              icon: Iconsax.security_safe_copy,
                              title: isAr ? '٦. القانون الواجب التطبيق والاختصاص القضائي' : '6. Governing Law & Jurisdiction',
                              content: isAr
                                  ? 'تخضع هذه الشروط وكافة المعاملات الناتجة عنها وتُفسر وفقاً لقوانين جمهورية مصر العربية، وتختص محاكم أسوان بنظر أي نزاع قضائي قد ينشأ بخصوص هذه الاتفاقية.'
                                  : 'These terms and all resulting transactions are governed by the laws of the Arab Republic of Egypt. The courts of Aswan hold exclusive jurisdiction over any legal disputes.',
                            ),
                            const SizedBox(height: 12),
                            _buildSectionCard(
                              dialogContext,
                              icon: Iconsax.call_copy,
                              title: isAr ? '٧. بيانات المقر والتواصل الرسمي' : '7. Official Headquarters & Contact',
                              content: isAr
                                  ? '• المقر الرئيسي: أسوان، جمهورية مصر العربية.\n• البريد الإلكتروني الرسمي: vspapp.eg@gmail.com\n• الدعم الفني وخدمة العملاء: +201100229462 (متاح عبر WhatsApp).'
                                  : '• Headquarters: Aswan, Arab Republic of Egypt.\n• Official Email: vspapp.eg@gmail.com\n• Customer Support: +201100229462 (available via WhatsApp).',
                            ),
                          ] else ...[
                            _buildSectionCard(
                              dialogContext,
                              icon: Iconsax.document_text_copy,
                              title: isAr ? '١. طبيعة المنصة وشروط الأهلية' : '1. Platform Services & Eligibility',
                              content: isAr
                                  ? '• تُعد منصة VSP وسيطاً تقنياً لتنظيم وتسهيل حجز ملاعب كرة القدم والمباريات التنافسية.\n• يُشترط ألا يقل عمر المستخدم (اللاعب أو مالك الملعب) عن 18 عاماً لاستخدام المنصة وإجراء الحجوزات والمدفوعات الإلكترونية، و21 عاماً للتعاقد التجاري كمفوض عن منشأة رياضية.\n• يلتزم اللاعبون بالحضور في الموعد المحدد والتحلي بالأخلاق والروح الرياضية واحترام منشآت ومرافق الملعب المضيف.'
                                  : '• VSP operates as a digital platform facilitating pitch bookings and competitive matches.\n• Users (players and venue owners) must be at least 18 years of age to use the platform and make online bookings (and 21 years of age to execute commercial venue agreements).\n• Players must arrive on time and uphold sportsmanship and respect facility amenities.',
                            ),
                            const SizedBox(height: 12),
                            _buildSectionCard(
                              dialogContext,
                              icon: Iconsax.wallet_1_copy,
                              title: isAr ? '٢. سياسة الإلغاء والاسترداد المالي (Paymob)' : '2. Cancellation & Paymob Refund Policy',
                              content: isAr
                                  ? '• الإلغاء المبكر (أكثر من 6 ساعات قبل المباراة): استرداد مالي كامل (100%) يتم استرجاعه تلقائياً لنفس وسيلة الدفع الأصلية عبر بوابة Paymob مباشرة.\n• البطولات الرياضية: يُسمح بالإلغاء واسترداد رسوم الاشتراك بالكامل قبل انطلاق البطولة بيومين (48 ساعة) وقبل إجراء القرعة الرسمية.\n• مهلة الـ 20 دقيقة الأولى: عند إلغاء الحجز خلال أول 20 دقيقة من إتمامه وسداده، يُسترد المبلغ مخصوماً منه المصاريف الإدارية والتشغيلية غير المستردة (رسوم بوابة الدفع الإلكتروني).\n• مدة الاسترداد ونافذة الـ 90 يوماً: يستغرق ظهور المبلغ في الحساب من 3 إلى 7 أيام عمل وفقاً لدورة المقاصة بالبنك المصدر (شريطة تقديم طلب الاسترداد خلال 90 يوماً كحد أقصى من تاريخ العملية وفقاً لسياسة Paymob).\n• الإلغاء المتأخر (أقل من 6 ساعات) أو عدم الحضور (No-Show) لا يمنح الحق في استرداد المبالغ المدفوعة.'
                                  : '• Early Cancellation (over 6 hours prior to match): Full 100% refund processed automatically back to the original payment method via Paymob.\n• Tournaments: Full refund when withdrawing at least 48 hours prior to kickoff and before the official bracket draw.\n• 20-Minute Grace Window: Cancellations within the first 20 minutes of booking are refunded minus non-refundable gateway processing fees.\n• Bank Settlement & 90-Day Window: Refunds reflect within 3-7 business days per issuer clearing cycles (provided refund requests are initiated within a 90-day maximum window per Paymob policy).\n• Late cancellations or no-shows forfeit refunds.',
                            ),
                            const SizedBox(height: 12),
                            _buildSectionCard(
                              dialogContext,
                              icon: Iconsax.coin_copy,
                              title: isAr ? '٣. أمان المدفوعات والشفافية (PCI-DSS & Paymob)' : '3. Payment Security & Transparency (PCI-DSS & Paymob)',
                              content: isAr
                                  ? '• تتم معالجة كافة المدفوعات الإلكترونية عبر بيئة مشفرة تديرها بوابة الدفع المعتمدة Paymob والممتثلة لمعايير أمان بطاقات الدفع العالمية (PCI-DSS). لا نقوم بحفظ أرقام البطاقات السرية أو رموز CVC.\n• الشفافية ومنع الرسوم الخفية: تُدفع جميع الحجوزات الجديدة أونلاين بالكامل (100%) في عملية واحدة مع إضافة عمولة المنصة (5%) ورسوم بوابة Paymob بوضوح في شاشة التأكيد قبل الدفع؛ ولا يتاح الدفع النقدي أو العربون للحجوزات الجديدة.'
                                  : '• All electronic transactions are processed through encrypted environments managed by certified gateway Paymob, complying with global Payment Card Industry Data Security Standards (PCI-DSS). We do not store CVV/PINs.\n• Full Transparency: All new bookings are paid 100% online in a single transaction, with the 5% platform fee and Paymob gateway fees itemized clearly before checkout; cash and direct deposit bookings are retired for new bookings.',
                            ),
                            const SizedBox(height: 12),
                            _buildSectionCard(
                              dialogContext,
                              icon: Iconsax.location_cross_copy,
                              title: isAr ? '٤. سياسة تتبع الحضور والغياب (No-Show)' : '4. Attendance & No-Show Policy',
                              content: isAr
                                  ? '• التغيب عن الحجز المؤكد دون إلغاء رسمي مسبق يُسقط حق استرداد المبلغ المدفوع ويُعرض الحساب لقيود تصاعدية لحماية أوقات الملاعب.\n• تسجيل 3 حالات غياب متكررة يؤدي إلى تعليق الحساب لحماية أوقات الملاعب واللاعبين الآخرين.\n• يمكن للاعب تقديم طعن جغرافي (GPS) لإثبات الحضور خلال 60 دقيقة من نهاية المباراة، بشرط التواجد ضمن نطاق 150 متراً من الملعب بدقة GPS تقل عن 50 متراً.'
                                  : '• Failing to attend a confirmed booking without prior cancellation forfeits the booking refund and triggers progressive account restrictions.\n• 3 recorded no-shows lead to account suspension to protect venues and other players.\n• Players can dispute a no-show via GPS within 60 minutes post-match if present within 150m of the stadium with GPS accuracy under 50m.',
                            ),
                            const SizedBox(height: 12),
                            _buildSectionCard(
                              dialogContext,
                              icon: Iconsax.cup_copy,
                              title: isAr ? '٥. نزاهة البطولات والتحديات ومنع المراهنات' : '5. Tournament Integrity & Anti-Wagering Policy',
                              content: isAr
                                  ? '• بطولات كروية تنافسية بالكامل على أساس المهارة والأداء الرياضي. رسوم الاشتراك تُستخدم حصرياً لتغطية تكاليف تنظيم البطولة. الجوائز والكؤوس مقدَّمة من VSP والجهات الراعية للبطولة، وليست ممولة من رسوم اشتراك الفرق المتنافسة.\n• حظر تام للرهانات والمقامرة: نظام التحديات ونقاط Elo هو نظام تقني لقياس المهارة الرياضية فقط؛ يُحظر حظراً قاطعاً استخدام المنصة لأي مراهنات مالية أو مقامرة، وأي مخالفة تؤدي للحظر النهائي والمساءلة القانونية.\n• يلتزم كباتن الفرق بإدخال النتائج الحقيقية بعد المباراة بنزاهة وشفافية.'
                                  : '• Purely skill-based competitive sports tournaments. Entry fees are utilized exclusively to cover operational costs. Trophies and prizes are sponsored by VSP and official partners and are not funded by competitor fees.\n• Strict Anti-Wagering Ban: The challenge and Elo system measures athletic skill only; monetary betting or gambling is strictly prohibited and results in permanent ban and legal liability.\n• Team captains must submit truthful, verified match results.',
                            ),
                            const SizedBox(height: 12),
                            _buildSectionCard(
                              dialogContext,
                              icon: Iconsax.lock_copy,
                              title: isAr ? '٦. قواعد الفرق وحقوق الخصوصية وحذف الحساب' : '6. Team Rules, Privacy & Account Erasure',
                              content: isAr
                                  ? '• الحد الأقصى لقائمة الفريق هو 12 لاعباً، ويحق للاعب الانضمام إلى 3 فرق كحد أقصى.\n• نحن لا نبيع أو نؤجر بياناتك الشخصية لأي طرف ثالث نهائياً.\n• يحق لك في أي وقت تعديل بياناتك أو طلب حذف حسابك وكافة سجلاتك نهائياً من داخل التطبيق عبر: (الملف الشخصي -> حذف الحساب) أو بمراسلة فريق الدعم الفني.'
                                  : '• Max 12 players per team roster, and players can join up to 3 teams.\n• We never sell or lease personal data to third parties.\n• You have the right to edit data or request permanent account deletion via Profile -> Delete Account or contacting support.',
                            ),
                            const SizedBox(height: 12),
                            _buildSectionCard(
                              dialogContext,
                              icon: Iconsax.security_safe_copy,
                              title: isAr ? '٧. القانون الواجب التطبيق والاختصاص القضائي' : '7. Governing Law & Jurisdiction',
                              content: isAr
                                  ? 'تخضع هذه الشروط وكافة المعاملات الناتجة عنها وتُفسر وفقاً لقوانين جمهورية مصر العربية، وتختص محاكم أسوان بنظر أي نزاع قضائي قد ينشأ بخصوص هذه الاتفاقية.'
                                  : 'These terms and all resulting transactions are governed by the laws of the Arab Republic of Egypt. The courts of Aswan hold exclusive jurisdiction over any legal disputes.',
                            ),
                            const SizedBox(height: 12),
                            _buildSectionCard(
                              dialogContext,
                              icon: Iconsax.call_copy,
                              title: isAr ? '٨. بيانات المقر والتواصل الرسمي' : '8. Official Headquarters & Contact',
                              content: isAr
                                  ? '• المقر الرئيسي: أسوان، جمهورية مصر العربية.\n• البريد الإلكتروني الرسمي: vspapp.eg@gmail.com\n• الدعم الفني وخدمة العملاء: +201100229462 (متاح عبر WhatsApp).'
                                  : '• Headquarters: Aswan, Arab Republic of Egypt.\n• Official Email: vspapp.eg@gmail.com\n• Customer Support: +201100229462 (available via WhatsApp).',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Action Button Footer
                  const Divider(color: VSPColors.divider, height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        text: buttonText,
                        onPressed: () => Navigator.pop(dialogContext),
                        height: 50,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: VSPColors.surface,
                  borderRadius: BorderRadius.circular(VSPRadius.sm),
                  border: Border.all(color: VSPColors.divider),
                ),
                child: Icon(icon, color: VSPColors.textSecondary, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: VSPColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: VSPColors.textSecondary,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
