import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';
import '../../../shared/widgets/social_auth_button.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';

import '../../../shared/widgets/vsp_auth_header.dart';
import '../../../shared/widgets/vsp_icon_badge.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/utils/vsp_feedback.dart';

/// شاشة إنشاء حساب جديد - تظهر بعد اختيار الدور
class CreateAccountScreen extends StatefulWidget {
 final bool isOwner;

 const CreateAccountScreen({
 super.key,
 this.isOwner = false, // Default to player to be safe
 });

 @override
 State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {

  late TapGestureRecognizer _termsRecognizer;
  late TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
 super.initState();
 _termsRecognizer = TapGestureRecognizer()..onTap = _onTermsOrPrivacyTap;
 _privacyRecognizer = TapGestureRecognizer()..onTap = _onTermsOrPrivacyTap;
 WidgetsBinding.instance.addPostFrameCallback((_) {
 if (!mounted) return;
 Provider.of<AuthProvider>(context, listen: false).setUserType(widget.isOwner ? 'owner' : 'player');
 });
 }

 void _onTermsOrPrivacyTap() {
 _showTermsAndPrivacyModal(context);
 }

 @override
 void dispose() {
 _termsRecognizer.dispose();
 _privacyRecognizer.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 final authProvider = Provider.of<AuthProvider>(context, listen: false);
 final bool isUserOwner = widget.isOwner;

 // تحديد النصوص بناءً على نوع المستخدم
 final String greeting = !isUserOwner
 ? AppLocalizations.of(context)!.hiSporty
 : AppLocalizations.of(context)!.hiPitch;

 final String subtitle = !isUserOwner
 ? AppLocalizations.of(context)!.playerSubtitle
 : AppLocalizations.of(context)!.ownerSubtitle;

 return AnnotatedRegion<SystemUiOverlayStyle>(
 value: SystemUiOverlayStyle(
 statusBarColor: VSPColors.background.withValues(alpha: 0),
 statusBarIconBrightness: Brightness.light,
 systemNavigationBarColor: VSPColors.background,
 systemNavigationBarIconBrightness: Brightness.light,
 systemNavigationBarDividerColor: VSPColors.background.withValues(alpha: 0),
 ),
 child: Scaffold(
 backgroundColor: VSPColors.background,
 body: Stack(
 children: [
 // 1. Subtle Background Elements
 Positioned(
 top: -100,
 right: -100,
 child: Container(
 width: 300,
 height: 300,
 decoration: const BoxDecoration(
 shape: BoxShape.circle,
 color: VSPColors.accentGlow,
 ),
 child: BackdropFilter(
 filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
 child: Container(color: VSPColors.background.withValues(alpha: 0)),
 ),
 ),
 ),
 
 // 2. Main Content
 SafeArea(
 child: SingleChildScrollView(
 keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
 physics: const BouncingScrollPhysics(),
 padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.lg),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const SizedBox(height: 12),
 
 // Header Nav
              const VSPAuthHeader(showLogo: true),

 const SizedBox(height: 24),

 // Greeting Section
 VSPFadeInItem(
 index: 1,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 greeting,
 style: Theme.of(context).textTheme.displayLarge?.copyWith(
 fontSize: MediaQuery.of(context).size.width < 360 ? 38 : 46,
 height: 0.9,
 letterSpacing: -1,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 AppLocalizations.of(context)!.createNewAccount,
 style: Theme.of(context).textTheme.bodyLarge?.copyWith(
 color: VSPColors.textSecondary,
 letterSpacing: 1.2,
 fontWeight: FontWeight.w300,
 ),
 ),
 ],
 ),
 ),

 const SizedBox(height: 24),

 // Subtitle - Clean text under title
 VSPFadeInItem(
 index: 2,
 child: Text(
 subtitle,
 style: Theme.of(context).textTheme.bodyMedium?.copyWith(
 color: VSPColors.textSecondary,
 height: 1.5,
 fontSize: 15,
 ),
 ),
 ),

					const SizedBox(height: 32),

					// Action Buttons
					VSPFadeInItem(
						index: 3,
						child: PrimaryButton(
							text: AppLocalizations.of(context)!.continueWithEmail,
							height: 60,
							onPressed: () {
								context.push(isUserOwner ? '/signup-owner' : '/signup-player');
							},
						),
					),

					const SizedBox(height: 28),

					VSPFadeInItem(
						index: 4,
						child: Row(
							children: [
								const Expanded(child: Divider(color: VSPColors.borderMedium)),
								Padding(
									padding: const EdgeInsets.symmetric(horizontal: 16),
									child: Text(
										AppLocalizations.of(context)!.or,
										style: TextStyle(
											color: VSPColors.textSecondary.withValues(alpha: 0.5),
										),
									),
								),
								const Expanded(child: Divider(color: VSPColors.borderMedium)),
							],
						),
					),

					const SizedBox(height: 28),

					// Social Sign-In Buttons (Google & Apple)
					VSPFadeInItem(
						index: 5,
						child: Row(
							children: [
								if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) ...[
									Expanded(
										child: SocialAuthButton(
											height: 56,
											iconWidget: Row(
												mainAxisSize: MainAxisSize.min,
												mainAxisAlignment: MainAxisAlignment.center,
												children: [
													Image.asset(
														'assets/images/apple_logo.png',
														width: 20,
														height: 20,
														color: VSPColors.textPrimary,
													),
													const SizedBox(width: 10),
													Text(
														'Apple',
														style: Theme.of(context).textTheme.labelLarge?.copyWith(
																fontWeight: FontWeight.bold,
																color: VSPColors.textPrimary,
															),
													),
												],
											),
											onPressed: () async {
												final role = isUserOwner ? 'owner' : 'player';
												authProvider.setUserType(role);
												await SecureStorageService.writeSecure('pending_oauth_role', role);
												final prefs = await SharedPreferences.getInstance();
												await prefs.setString('pending_oauth_role', role);
												await prefs.setBool('pending_oauth_is_login_only', false);
												final success = await authProvider.signInWithApple(isLoginOnly: false);
												if (context.mounted && !success) {
													VSPFeedback.showError(context, authProvider.errorMessage ?? 'Apple Sign-In failed');
												}
											},
										),
									),
									const SizedBox(width: 12),
								],
								Expanded(
									child: SocialAuthButton(
										height: 56,
										iconWidget: Row(
											mainAxisSize: MainAxisSize.min,
											mainAxisAlignment: MainAxisAlignment.center,
											children: [
												Image.asset(
													'assets/images/google_logo.png',
													width: 22,
													height: 22,
												),
												const SizedBox(width: 10),
												Text(
													AppLocalizations.of(context)!.continueWithGoogle,
													style: Theme.of(context).textTheme.labelLarge?.copyWith(
															fontWeight: FontWeight.bold,
															color: VSPColors.textPrimary,
														),
												),
											],
										),
										onPressed: () async {
											final role = isUserOwner ? 'owner' : 'player';
											authProvider.setUserType(role);
											await SecureStorageService.writeSecure('pending_oauth_role', role);
											final prefs = await SharedPreferences.getInstance();
											await prefs.setString('pending_oauth_role', role);
											await prefs.setBool('pending_oauth_is_login_only', false);
											final success = await authProvider.signInWithGoogle(isLoginOnly: false);
											if (context.mounted && !success) {
												VSPFeedback.showError(context, authProvider.errorMessage ?? 'Google Sign-In failed');
											}
										},
									),
								),
							],
						),
					),

					const SizedBox(height: 32),

					// Already have an account? Sign in
					VSPFadeInItem(
						index: 6,
						child: Row(
							mainAxisAlignment: MainAxisAlignment.center,
							children: [
								Text(
									AppLocalizations.of(context)!.alreadyHaveAccount,
									style: Theme.of(context).textTheme.bodyMedium?.copyWith(
											color: VSPColors.textSecondary,
											fontSize: 14,
										),
								),
								const SizedBox(width: 6),
								GestureDetector(
									onTap: () {
										context.push('/login');
									},
									child: Text(
										AppLocalizations.of(context)!.login,
										style: Theme.of(context).textTheme.bodyMedium?.copyWith(
												color: VSPColors.accent,
												fontWeight: FontWeight.bold,
												fontSize: 14,
											),
									),
								),
							],
						),
					),

					const SizedBox(height: 32),

					// Footer Links
					VSPFadeInItem(
						index: 7,
						child: Center(
							child: Opacity(
								opacity: 0.75,
								child: RichText(
									textAlign: TextAlign.center,
									text: TextSpan(
										style: Theme.of(context).textTheme.bodySmall?.copyWith(
												color: VSPColors.textSecondary,
												height: 1.5,
											),
										children: [
											TextSpan(text: AppLocalizations.of(context)!.byUsingVsp),
											TextSpan(
												text: AppLocalizations.of(context)!.termsOfService,
												recognizer: _termsRecognizer,
												style: const TextStyle(
													color: VSPColors.accent,
													fontWeight: FontWeight.bold,
													decoration: TextDecoration.underline,
												),
											),
											TextSpan(text: AppLocalizations.of(context)!.and),
											TextSpan(
												text: AppLocalizations.of(context)!.privacyPolicy,
												recognizer: _privacyRecognizer,
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
					),
					const SizedBox(height: 40),
 ],
 ),
 ),
 ),
 ],
 ),
 ),
 );
 }

 /// pop-up Modal (Dialog) displaying Terms of Service & Privacy Policy matching VSP design system
 void _showTermsAndPrivacyModal(BuildContext context) {
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
 color: VSPColors.accent.withValues(alpha: 0.08),
 borderRadius: BorderRadius.circular(VSPRadius.lg),
 border: Border.all(color: VSPColors.accent.withValues(alpha: 0.25)),
 ),
 child: Row(
 children: [
 const Icon(Iconsax.info_circle_copy, color: VSPColors.accent, size: 18),
 const SizedBox(width: 10),
 Expanded(
 child: Text(
 isAr
 ? 'مطابق لقوانين وحماية البيانات المصرية (PDPL 2020)'
 : 'Compliant with Egyptian Data Protection Law (PDPL 2020)',
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

 if (widget.isOwner) ...[
 _buildModalSectionCard(
 dialogContext,
 icon: Iconsax.building_copy,
 title: isAr ? '١. شروط وإلتزامات تشغيل الملاعب' : '1. Stadium Operations & Listing Terms',
 content: isAr
 ? 'يلتزم صاحب الملعب بدقة بيانات الملعب والمعلومات المعروضة، وتجهيز الإضاءة والمرافق في المواعيد المحجوزة للاعبين دون أي تأخير أو تغيير في السعر المتفق عليه. تضمن المنصة تنظيم الحجوزات بدقة ومنع التضارب.'
 : 'Stadium owners must guarantee pitch readiness, lighting, and amenities for confirmed slots without rate changes or delays. VSP ensures technical dispatching to prevent slot conflicts.',
 ),
 const SizedBox(height: 12),

 _buildModalSectionCard(
 dialogContext,
 icon: Iconsax.wallet_1_copy,
 title: isAr ? '٢. سياسة العربون والتحصيل المباشر' : '2. Direct Deposit & Payout Policy',
 content: isAr
 ? 'يلتزم المالك بتأكيد مبالغ العربون والحجوزات المستلمة مباشرة عبر (انستا باي أو فودافون كاش أو التحويل البنكي) وتحديث حالة الحجز في التطبيق فور استلام المبلغ، والالتزام بتوفير الملعب للحاجز.'
 : 'Owners must promptly verify and confirm direct deposits received via InstaPay, Vodafone Cash, or Bank Transfer in-app, honoring the reservation for the player.',
 ),
 const SizedBox(height: 12),

 _buildModalSectionCard(
 dialogContext,
 icon: Iconsax.shield_cross_copy,
 title: isAr ? '٣. سياسة منع الإلغاء المفاجئ' : '3. Cancellation & Commitment Policy',
 content: isAr
 ? 'يُحظر على صاحب الملعب إلغاء أي حجز مؤكد إلا في حالات القوة القاهرة المثبتة، مع الالتزام بإخطار الحاجز وإعادة كامل العربون أو المبالغ المدفوعة إليه فوراً دون أي اقتطاع.'
 : 'Owners are prohibited from cancelling confirmed bookings except in proven force majeure cases, with mandatory immediate full refund to the customer.',
 ),
 const SizedBox(height: 12),

 _buildModalSectionCard(
 dialogContext,
 icon: Iconsax.cup_copy,
 title: isAr ? '٤. نزاهة البطولات والجوائز' : '4. Tournament Integrity & Prizes',
 content: isAr
 ? 'يلتزم المالك بإدارة البطولات والتحديات المعروضة على ملعبه بنزاهة تامة، والالتزام بالجدول المعلن، وتأكيد النتائج وتسليم الجوائز المعلنة للفرق الفائزة دون تأخير.'
 : 'Owners hosting tournaments commit to fair refereeing, strictly adhering to scheduled brackets, and promptly distributing announced prizes to winning teams.',
 ),
 const SizedBox(height: 12),

 _buildModalSectionCard(
 dialogContext,
 icon: Iconsax.lock_copy,
 title: isAr ? '٥. سياسة حماية بيانات اللاعبين (PDPL 2020)' : '5. Player Privacy & Data Protection',
 content: isAr
 ? 'وفقاً لقانون حماية البيانات الشخصية المصري (PDPL 2020)، يلتزم المالك بالحفاظ على سرية وخصوصية الحاجزين وعدم استخدام أو استغلال بيانات الاتصال الخاصة باللاعبين في أي أغراض تسويقية أو خارج نطاق تنظيم المباريات.'
 : 'Under Egyptian Law PDPL 2020, owners agree to keep player contact information strictly confidential and use it solely for match coordination.',
 ),
 ] else ...[
                    _buildModalSectionCard(
                      dialogContext,
                      icon: Iconsax.document_text_copy,
                      title: isAr ? '١. طبيعة المنصة واستخدام خدمة VSP' : '1. VSP Platform Services & Usage',
                      content: isAr
                          ? 'تُعد منصة VSP وسيطاً تقنياً لتنظيم وتسهيل حجز ملاعب كرة القدم والمباريات التنافسية. إدارة الملعب هي المسؤولة عن سلامة المنشأة والمرافق. يلتزم اللاعبون بالحضور في الموعد المحدد والتحلي بالأخلاق الرياضية داخل الملعب.'
                          : 'VSP acts as a digital intermediary facilitating pitch bookings and competitive matches. Facility management is responsible for pitch readiness. Players must arrive on time and uphold sportsmanship.',
                    ),
                    const SizedBox(height: 12),

                    _buildModalSectionCard(
                      dialogContext,
                      icon: Iconsax.wallet_1_copy,
                      title: isAr ? '٢. سياسة الإلغاء والاسترداد المالي' : '2. Cancellation & Refund Policy',
                      content: isAr
                          ? '• يُسمح بإلغاء الحجز حتى قبل موعد بدء المباراة بساعتين (2 Hours) للحصول على استرداد مالي كامل.\n• تتم معالجة ومراجعة طلبات الاسترداد المالي من قِبل فريق VSP خلال 3-5 أيام عمل عبر وسيلة الدفع الأصلية أو التحويل المباشر.\n• الإلغاء بعد انتهاء المهلة المحددة (أقل من ساعتين) أو عدم الحضور (No-Show) لا يمنح الحق في استرداد العربون أو المبالغ المدفوعة.'
                          : '• Free cancellation is available up to 2 hours before kickoff for a full refund.\n• Refund requests are processed by the VSP team within 3-5 business days via the original payment method or direct transfer.\n• Late cancellations (within 2 hours) or no-shows forfeit deposit/fee refunds.',
                    ),
                    const SizedBox(height: 12),

                    _buildModalSectionCard(
                      dialogContext,
                      icon: Iconsax.coin_copy,
                      title: isAr ? '٣. سياسة الرسوم والشفافية المالية' : '3. Fees & Pricing Transparency',
                      content: isAr
                          ? '• طبيعة الرسوم: عند الحجز الإلكتروني، قد يُضاف مبلغ خدمة وتشغيل تقني ورسوم معالجة مصرفية لتغطية تكاليف السيرفرات السحابية وتأمين المواعيد وبوابات الدفع البنكية المرخصة (Paymob).\n• الشفافية ومنع الرسوم الخفية: يظهر إجمالي المبلغ المطلوب سداده وتفاصيله بوضوح في شاشة تأكيد الحجز قبل إتمام أي عملية دفع، ولا توجد أي رسوم غير معلنة.\n• الحجز النقدي: عند اختيار السداد النقدي بالملعب، يدفع اللاعب قيمة إيجار الملعب المحددة من الإدارة دون أي رسوم معالجة دفع رقمي إضافية من المنصة.'
                          : '• Nature of Fees: For online bookings, platform service and banking processing fees cover cloud servers, real-time lock security, and licensed payment gateways (Paymob).\n• Full Transparency: Total payable amounts are clearly itemized before checkout with zero hidden fees.\n• Cash Bookings: Direct on-pitch cash payments cover standard pitch rental only without digital processing charges.',
                    ),
                    const SizedBox(height: 12),

                    _buildModalSectionCard(
                      dialogContext,
                      icon: Iconsax.location_cross_copy,
                      title: isAr ? '٤. سياسة تتبع الحضور والغياب (No-Show)' : '4. Attendance & No-Show Policy',
                      content: isAr
                          ? '• تسجيل حالتي (2) غياب يؤدي إلى تقييد ميزة الحجز النقدي المباشر.\n• تسجيل 3 حالات غياب متكررة يؤدي إلى تعليق الحساب لحماية أوقات الملاعب واللاعبين الآخرين.\n• يمكن للاعب تقديم طعن جغرافي (GPS) لإثبات الحضور خلال 60 دقيقة من نهاية المباراة، بشرط التواجد ضمن نطاق 150 متراً من الملعب بدقة GPS تقل عن 50 متراً.'
                          : '• 2 recorded no-shows restrict cash booking privileges.\n• 3 recorded no-shows lead to account suspension.\n• Players can dispute a no-show via GPS within 60 minutes post-match if present within 150m of the stadium with GPS accuracy under 50m.',
                    ),
                    const SizedBox(height: 12),

                    _buildModalSectionCard(
                      dialogContext,
                      icon: Iconsax.cup_copy,
                      title: isAr ? '٥. نزاهة التحديات وترتيب الـ Elo' : '5. Challenge Matches & Elo Ranking',
                      content: isAr
                          ? 'يلتزم كباتن الفرق بإدخال النتائج الحقيقية بعد المباراة. في حال وجود نزاع أو تضارب في النتائج، تُجمد نقاط الترتيب تلقائياً لحين المراجعة الإدارية. أي تلاعب متعمد بالنتائج يعرض الحساب للحظر النهائي.'
                          : 'Captains must submit truthful match results. Disputed outcomes freeze ranking points for administrative review. Intentional result manipulation results in permanent ban.',
                    ),
                    const SizedBox(height: 12),

                    _buildModalSectionCard(
                      dialogContext,
                      icon: Iconsax.lock_copy,
                      title: isAr ? '٦. قواعد الفرق وحماية البيانات والخصوصية' : '6. Team Rules, Privacy & Data Rights',
                      content: isAr
                          ? '• الحد الأقصى لقائمة الفريق هو 12 لاعباً، ويحق للاعب الانضمام إلى 3 فرق كحد أقصى.\n• لا نبيع أو نؤجر بياناتك الشخصية لأي طرف ثالث نهائياً.\n• يحق لك تعديل بياناتك أو حذف حسابك وكافة سجلاتك نهائياً من داخل التطبيق (الملف الشخصي -> حذف الحساب) في أي وقت.\n• للدعم والاستفسارات: WhatsApp على 01100229462.'
                          : '• Max 12 players per team roster, and players can join up to 3 teams.\n• We never sell personal data to third parties.\n• You may edit or permanently delete your account and all data directly in-app at any time.\n• For support: WhatsApp +201100229462.',
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

 Widget _buildModalSectionCard(
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
 color: VSPColors.accent.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Icon(icon, color: VSPColors.accent, size: 16),
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
} // end CreateAccountScreen


