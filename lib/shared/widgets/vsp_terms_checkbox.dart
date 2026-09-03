import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'dart:ui';
import '../../core/ui/tokens/vsp_tokens.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'vsp_icon_badge.dart';

/// مربع اختيار الموافقة على الشروط وسياسة الخصوصية مع إمكانية فتح التفاصيل
class VSPTermsCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onTermsTap;

  const VSPTermsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.onTermsTap,
  });

  static void showTermsModal(BuildContext context) {
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
                    child: Row(
                      children: [
                        const VSPIconBadge(icon: Iconsax.security_safe_copy, color: VSPColors.accent, size: 36, iconSize: 20),
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
                          icon: const Icon(Icons.close, color: VSPColors.textSecondary, size: 20),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: VSPColors.divider),
                  // Body Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSection(
                            dialogContext,
                            icon: Iconsax.document_text_copy,
                            title: isAr ? '١. شروط الاستخدام العامة' : '1. General Terms of Use',
                            content: isAr
                                ? '• يلتزم المستخدم بتقديم بيانات صحيحة ودقيقة عند إنشاء الحساب.\n• الحساب شخصي ولا يجوز مشاركته أو استخدامه لأغراض تجارية غير مصرح بها.\n• يحق لإدارة VSP تعليق أو إنهاء أي حساب يخالف المعايير الأخلاقية أو الرياضية.'
                                : '• You must provide accurate and truthful information during registration.\n• Accounts are personal and non-transferable.\n• VSP reserves the right to suspend or terminate accounts violating community or sports standards.',
                          ),
                          const SizedBox(height: 12),
                          _buildSection(
                            dialogContext,
                            icon: Iconsax.calendar_tick_copy,
                            title: isAr ? '٢. سياسة الحجوزات والإلغاء' : '2. Booking & Cancellation Policy',
                            content: isAr
                                ? '• يُتاح إلغاء الحجز واسترداد العربون بالكامل قبل موعد المباراة بـ 12 ساعة على الأقل.\n• في حال الإلغاء قبل أقل من 12 ساعة، يُخصم العربون لتعويض صاحب الملعب.\n• في حال عدم الحضور (No-Show) بدون إخطار، يتم تسجيل مخالفة وخصم نقاط من تقييم اللاعب/الفريق.'
                                : '• Free cancellation with full deposit refund is available up to 12 hours before match start.\n• Cancellations within 12 hours forfeit the deposit to compensate the stadium owner.\n• No-shows reduce Fair Play score and may trigger booking restrictions.',
                          ),
                          const SizedBox(height: 12),
                          _buildSection(
                            dialogContext,
                            icon: Iconsax.shield_tick_copy,
                            title: isAr ? '٣. سياسة الخصوصية وحماية البيانات' : '3. Privacy & Data Protection',
                            content: isAr
                                ? '• نلتزم بحماية بياناتك الشخصية (الاسم، الهاتف، الموقع، البريد) بأعلى معايير التشفير.\n• تُستخدم البيانات فقط لتقديم خدمات الحجز، وتنسيق المباريات، وإرسال الإشعارات المهمة.\n• لن يتم بيع أو مشاركة بياناتك مع أي طرف ثالث لأغراض تسويقية دون إذنك المسبق.'
                                : '• We protect your personal data (name, phone, location, email) with industry-standard encryption.\n• Data is strictly used for booking operations, match coordination, and essential notifications.\n• We never sell or share your data with third parties for marketing purposes.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: VSPColors.divider),
                  // Footer Button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VSPColors.accent,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(VSPRadius.button),
                          ),
                        ),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(
                          buttonText,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
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

  static Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VSPColors.surfaceLight,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: VSPColors.accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: VSPColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              color: VSPColors.textSecondary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(!value);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: value ? VSPColors.accent : VSPColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: value ? VSPColors.accent : VSPColors.borderLight,
                  width: 1.5,
                ),
              ),
              child: value
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.black,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(!value);
              },
              child: RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: VSPColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                  children: [
                    TextSpan(text: l10n.iAgreeTo),
                    TextSpan(
                      text: l10n.termsOfService,
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          if (onTermsTap != null) {
                            onTermsTap!();
                          } else {
                            showTermsModal(context);
                          }
                        },
                      style: const TextStyle(
                        color: VSPColors.accent,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    TextSpan(text: l10n.and),
                    TextSpan(
                      text: l10n.privacyPolicy,
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          if (onTermsTap != null) {
                            onTermsTap!();
                          } else {
                            showTermsModal(context);
                          }
                        },
                      style: const TextStyle(
                        color: VSPColors.accent,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
