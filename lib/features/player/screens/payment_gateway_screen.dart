import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../data/models.dart';
import 'booking_success_screen.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/utils/vsp_feedback.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/repositories/user_repository.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';
import '../../../core/services/storage_service.dart';

class PaymentGatewayScreen extends StatefulWidget {
  final BookingDraft bookingDraft;

  const PaymentGatewayScreen({
    super.key,
    required this.bookingDraft,
  });

  @override
  State<PaymentGatewayScreen> createState() => _PaymentGatewayScreenState();
}

class _PaymentGatewayScreenState extends State<PaymentGatewayScreen> {
  bool _isLoading = false;
  int _selectedOptionIndex = 0;
  bool _depositConfirmed = false;
  String? _ownerPhone;
  bool _isLoadingPhone = true;
  XFile? _receiptImage;

  @override
  void initState() {
    super.initState();
    _fetchOwnerPhone();
  }

  Future<void> _fetchOwnerPhone() async {
    try {
      final ownerId = widget.bookingDraft.ownerId;
      if (ownerId.isNotEmpty) {
        final userData = await UserRepository().getUserData(ownerId);
        if (userData != null && mounted) {
          setState(() {
            _ownerPhone = userData['phone']?.toString();
            _isLoadingPhone = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching owner phone: $e');
    }
    if (mounted) {
      setState(() => _isLoadingPhone = false);
    }
  }

  void _processPayment() async {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.uid;
    
    if (userId == null) {
      VSPFeedback.showError(context, l10n.sessionExpiredError);
      return;
    }

    final isCashLocked = (authProvider.userModel?.noShowCount ?? 0) >= 2;
    final activeOptionIndex = isCashLocked ? 1 : _selectedOptionIndex;
    final hasDeposit = widget.bookingDraft.depositPaid > 0 && widget.bookingDraft.needsDeposit;

    if (hasDeposit && activeOptionIndex == 0) {
      if (_receiptImage == null) {
        VSPFeedback.showError(context, isArabic ? 'يرجى إرفاق صورة إيصال تحويل العربون أولاً' : 'Please upload the deposit receipt first.');
        return;
      }
      
      setState(() => _isLoading = true);
      
      try {
        // رفع إيصال التحويل على السيرفر
        final receiptUrl = await StorageService().uploadFile(
          file: _receiptImage!,
          bucket: 'deposit-receipts', // تم التحديث هنا لمطابقة لقطة الشاشة
          path: 'bookings/$userId/receipts/rec_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );

        if (receiptUrl == null) throw Exception('Failed to upload receipt');

        final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
        final draftWithPayment = widget.bookingDraft.copyWith(
          isPaid: false,
          isDepositPaid: true,
          depositPaid: widget.bookingDraft.depositPaid,
          paymentStatus: 'awaiting_verification', // حالة مخصصة للمراجعة اليدوية
          paymentMethod: 'manual_transfer',
          paymentTransactionId: 'TRANSFER_RC_manual',
          notes: '${widget.bookingDraft.notes ?? ""}\n[Manual Receipt]: $receiptUrl'.trim(),
        );

        final booking = await bookingProvider.createBooking(draftWithPayment, userId);
        if (!mounted) return;
        setState(() => _isLoading = false);

        if (booking != null) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => BookingSuccessScreen(booking: booking)));
        } else {
          final errorMsg = bookingProvider.errorMessage ?? '';
          if (errorMsg.contains('Overlapping') || errorMsg.contains('overlapping') || errorMsg.contains('already booked')) {
            VSPFeedback.showError(
              context,
              isArabic 
                ? 'عذراً، هذه الساعة تم حجزها وتأكيدها من لاعب آخر للتو! ⚠️' 
                : 'Sorry, this slot was just booked and confirmed by another player! ⚠️'
            );
          } else {
            VSPFeedback.showError(context, errorMsg.replaceFirst('Failed to create booking: ', '').replaceFirst('Exception: ', ''));
          }
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        VSPFeedback.showError(context, l10n.bookingFailedError(e.toString()));
      }
    } else {
      // التدفق القديم للدفع النقدي بالكامل أو الدفع الإلكتروني المباشر
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      try {
        final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
        
        bool isPaid = false;
        bool isDepositPaid = false;
        double depositPaidVal = widget.bookingDraft.depositPaid;
        String paymentStatus = 'pending';
        String paymentMethod = 'cash';

        if (hasDeposit) {
          setState(() => _isLoading = false);
          VSPFeedback.showError(context, isArabic ? 'الدفع الإلكتروني غير متاح حالياً' : 'Online payment is currently unavailable.');
          return;
        } else {
          if (activeOptionIndex == 0) {
            isPaid = false;
            isDepositPaid = false;
            depositPaidVal = 0.0;
            paymentStatus = 'unpaid';
            paymentMethod = 'cash';
          } else {
            setState(() => _isLoading = false);
            VSPFeedback.showError(context, isArabic ? 'الدفع الإلكتروني غير متاح حالياً' : 'Online payment is currently unavailable.');
            return;
          }
        }

        final draftWithPayment = widget.bookingDraft.copyWith(
          isPaid: isPaid,
          isDepositPaid: isDepositPaid,
          depositPaid: depositPaidVal,
          paymentStatus: paymentStatus,
          paymentMethod: paymentMethod,
          paymentTransactionId: '_',
        );

        final booking = await bookingProvider.createBooking(draftWithPayment, userId);
        if (!mounted) return;
        setState(() => _isLoading = false);

        if (booking != null) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => BookingSuccessScreen(booking: booking)));
        } else {
          final errorMsg = bookingProvider.errorMessage ?? '';
          if (errorMsg.contains('Overlapping') || errorMsg.contains('overlapping') || errorMsg.contains('already booked')) {
            VSPFeedback.showError(
              context,
              isArabic 
                ? 'عذراً، هذه الساعة تم حجزها وتأكيدها من لاعب آخر للتو! ⚠️' 
                : 'Sorry, this slot was just booked and confirmed by another player! ⚠️'
            );
          } else {
            VSPFeedback.showError(context, errorMsg.replaceFirst('Failed to create booking: ', '').replaceFirst('Exception: ', ''));
          }
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        VSPFeedback.showError(context, l10n.bookingFailedError(e.toString()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasDeposit = widget.bookingDraft.depositPaid > 0 && widget.bookingDraft.needsDeposit;
    final authProvider = Provider.of<AuthProvider>(context);
    final isCashLocked = (authProvider.userModel?.noShowCount ?? 0) >= 2;
    final activeOptionIndex = isCashLocked ? 1 : _selectedOptionIndex;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final showAcknowledgement = hasDeposit && activeOptionIndex == 0;

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft, color: VSPColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(l10n.confirmBooking, style: Theme.of(context).textTheme.displaySmall),
      ),
      body: Stack(
        children: [
          Positioned(
            top: -100, right: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: VSPColors.accent.withValues(alpha: 0.12)),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(color: Colors.transparent)),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(VSPSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isCashLocked) ...[
                  _buildRestrictedWarningCard(context, isArabic),
                  const SizedBox(height: 24),
                ],
                VSPFadeInItem(delay: const Duration(milliseconds: 100), child: _SectionHeader(title: l10n.bookingSummary)),
                const SizedBox(height: 16),
                VSPFadeInItem(delay: const Duration(milliseconds: 200), child: _BookingSummaryCard(bookingDraft: widget.bookingDraft)),
                const SizedBox(height: 32),
                VSPFadeInItem(delay: const Duration(milliseconds: 300), child: _SectionHeader(title: l10n.paymentMethod)),
                const SizedBox(height: 16),
                VSPFadeInItem(delay: const Duration(milliseconds: 400), child: _buildPaymentOptionsList(context, isCashLocked, activeOptionIndex)),
                const SizedBox(height: 24),
                if (!_isLoadingPhone && _ownerPhone != null && _ownerPhone!.isNotEmpty) ...[
                  VSPFadeInItem(
                    delay: const Duration(milliseconds: 420),
                    child: _buildContactPitchButton(context, _ownerPhone!),
                  ),
                  const SizedBox(height: 24),
                ],
                const SizedBox(height: 8),
                if (showAcknowledgement) ...[
                  VSPFadeInItem(
                    delay: const Duration(milliseconds: 450),
                    child: _DepositAcknowledgementCard(
                      depositAmount: widget.bookingDraft.depositPaid,
                      confirmed: _depositConfirmed,
                      onChanged: (val) => setState(() => _depositConfirmed = val ?? false),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
                const SizedBox(height: 20),
                VSPFadeInItem(
                  delay: const Duration(milliseconds: 600),
                  child: PrimaryButton(
                    text: l10n.confirmBooking,
                    isLoading: _isLoading,
                    onPressed: (showAcknowledgement && !_depositConfirmed) ? null : _processPayment,
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOptionsList(BuildContext context, bool isCashLocked, int activeOptionIndex) {
    final hasDeposit = widget.bookingDraft.depositPaid > 0 && widget.bookingDraft.needsDeposit;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final total = widget.bookingDraft.totalPrice;
    final deposit = widget.bookingDraft.depositPaid;
    final remaining = (total - deposit).clamp(0.0, double.infinity);
    final showAcknowledgement = hasDeposit && activeOptionIndex == 0;

    Widget optionsColumn;
    if (isCashLocked) {
      optionsColumn = Column(
        children: [
          _buildOptionCard(
            index: 1,
            title: isArabic ? 'دفع كامل المبلغ أونلاين' : 'Pay Full Amount Online',
            description: isArabic
                ? "ادفع كامل قيمة الحجز الآن (${total.toInt()} ج.م) ووفر الوقت عند وصولك"
                : "Pay the full booking amount now (${total.toInt()} EGP) online",
            tag: isArabic ? 'تأكيد بالكامل' : 'Full Payment',
            priceText: '${total.toInt()} ${isArabic ? 'ج.م' : 'EGP'}',
            icon: LucideIcons.wallet,
            activeOptionIndex: activeOptionIndex,
          ),
        ],
      );
    } else if (hasDeposit) {
      optionsColumn = Column(
        children: [
          _buildOptionCard(
            index: 0,
            title: isArabic ? 'دفع العربون فقط' : 'Pay Deposit Only',
            description: isArabic 
                ? "ادفع العربون لتأكيد حجزك (${deposit.toInt()} ج.م) والباقي نقداً في الملعب (${remaining.toInt()} ج.م)"
                : "Pay deposit to secure booking (${deposit.toInt()} EGP), rest in cash (${remaining.toInt()} EGP)",
            tag: isArabic ? 'عربون مسبق' : 'Deposit',
            priceText: '${deposit.toInt()} ${isArabic ? 'ج.م' : 'EGP'}',
            icon: LucideIcons.lock,
            activeOptionIndex: activeOptionIndex,
          ),
          const SizedBox(height: 16),
          _buildOptionCard(
            index: 1,
            title: isArabic ? 'دفع كامل المبلغ أونلاين' : 'Pay Full Amount Online',
            description: isArabic
                ? "ادفع كامل قيمة الحجز الآن (${total.toInt()} ج.م) ووفر الوقت عند وصولك"
                : "Pay the full booking amount now (${total.toInt()} EGP) online",
            tag: isArabic ? 'تأكيد بالكامل' : 'Full Payment',
            priceText: '${total.toInt()} ${isArabic ? 'ج.م' : 'EGP'}',
            icon: LucideIcons.wallet,
            activeOptionIndex: activeOptionIndex,
          ),
        ],
      );
    } else {
      optionsColumn = Column(
        children: [
          _buildOptionCard(
            index: 0,
            title: isArabic ? 'الدفع نقداً في الملعب' : 'Pay Cash at Pitch',
            description: isArabic
                ? "ادفع كامل المبلغ (${total.toInt()} ج.م) نقداً لصاحب الملعب عند وصولك"
                : "Pay the full amount (${total.toInt()} EGP) in cash at the stadium",
            tag: isArabic ? 'دفع عند الوصول' : 'Cash',
            priceText: '${total.toInt()} ${isArabic ? 'ج.م' : 'EGP'}',
            icon: LucideIcons.banknote,
            activeOptionIndex: activeOptionIndex,
          ),
          const SizedBox(height: 16),
          _buildOptionCard(
            index: 1,
            title: isArabic ? 'دفع كامل المبلغ أونلاين' : 'Pay Full Amount Online',
            description: isArabic
                ? "ادفع كامل قيمة الحجز الآن (${total.toInt()} ج.م) ووفر الوقت عند وصولك"
                : "Pay the full booking amount now (${total.toInt()} EGP) online",
            tag: isArabic ? 'تأكيد بالكامل' : 'Full Payment',
            priceText: '${total.toInt()} ${isArabic ? 'ج.م' : 'EGP'}',
            icon: LucideIcons.wallet,
            activeOptionIndex: activeOptionIndex,
          ),
        ],
      );
    }

    if (showAcknowledgement) {
      return Column(
        children: [
          optionsColumn,
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.xl),
              border: Border.all(color: VSPColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'بيانات تحويل العربون اليدوي:' : 'Manual Deposit Details:',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: VSPColors.accent),
                ),
                const SizedBox(height: 8),
                Text(
                  isArabic 
                      ? 'يرجى تحويل مبلغ ${widget.bookingDraft.depositPaid.toInt()} ج.م إلى الرقم ${_ownerPhone ?? "غير متوفر"} عبر إنستاباي أو المحفظة الإلكترونية، ثم أرفق إيصال التحويل أدناه:'
                      : 'Please transfer ${widget.bookingDraft.depositPaid.toInt()} EGP to ${_ownerPhone ?? "N/A"} via InstaPay or Mobile Wallet, then attach the receipt:',
                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),
                _receiptImage == null 
                    ? ElevatedButton.icon(
                        onPressed: () async {
                          final picker = ImagePicker();
                          final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                          if (image != null) setState(() => _receiptImage = image);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VSPColors.accent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.sm)),
                        ),
                        icon: const Icon(LucideIcons.upload, color: Colors.black, size: 18),
                        label: Text(isArabic ? 'إرفاق إيصال التحويل' : 'Attach Receipt'),
                      )
                    : Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(_receiptImage!.path), width: 50, height: 50, fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 12),
                          Text(isArabic ? 'تم اختيار الإيصال' : 'Receipt Selected', style: const TextStyle(color: VSPColors.success, fontSize: 12)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(LucideIcons.trash2, color: VSPColors.error),
                            onPressed: () => setState(() => _receiptImage = null),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ],
      );
    }

    return optionsColumn;
  }

  Widget _buildOptionCard({
    required int index,
    required String title,
    required String description,
    required String tag,
    required String priceText,
    required IconData icon,
    required int activeOptionIndex,
  }) {
    final isSelected = activeOptionIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedOptionIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? VSPColors.accent.withValues(alpha: 0.08) : VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.xl),
          border: Border.all(
            color: isSelected ? VSPColors.accent : VSPColors.divider,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected 
              ? [BoxShadow(color: VSPColors.accent.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))]
              : [],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? VSPColors.accent.withValues(alpha: 0.15) : VSPColors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? VSPColors.accent : VSPColors.textSecondary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isSelected ? Colors.white : VSPColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? VSPColors.accent.withValues(alpha: 0.2) : VSPColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            color: isSelected ? VSPColors.accent : VSPColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      color: VSPColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    priceText,
                    style: const TextStyle(
                      color: VSPColors.accent,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactPitchButton(BuildContext context, String phone) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
            final path = cleanPhone.startsWith('0') && cleanPhone.length == 11
                ? '+2$cleanPhone'
                : (cleanPhone.startsWith('2') ? '+$cleanPhone' : cleanPhone);
            final Uri launchUri = Uri(
              scheme: 'tel',
              path: path,
            );
            try {
              if (await canLaunchUrl(launchUri)) {
                await launchUrl(launchUri, mode: LaunchMode.externalApplication);
              }
            } catch (e) {
              debugPrint('Error launching dialer: $e');
            }
          },
          borderRadius: BorderRadius.circular(VSPRadius.xl),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.phoneCall, color: VSPColors.accent, size: 20),
                const SizedBox(width: 10),
                Text(
                  isArabic ? 'اتصل بإدارة الملعب للاستفسار مباشر' : 'Call Pitch directly to inquire',
                  style: const TextStyle(
                    color: VSPColors.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRestrictedWarningCard(BuildContext context, bool isArabic) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VSPColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(color: VSPColors.error.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.alertTriangle, color: VSPColors.error, size: 20),
              const SizedBox(width: 10),
              Text(
                isArabic ? "تقييد الحساب" : "Account Restricted",
                style: const TextStyle(
                  color: VSPColors.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
                ? "تم تقييد حسابك مؤقتاً من الحجوزات النقدية بسبب تكرار عدم الحضور. للحجز، يجب دفع 100٪ من قيمة الحجز عبر الإنترنت باستخدام المحافظ الرقمية."
                : "Your account is temporarily restricted from Cash bookings due to multiple missed bookings. To book, you must pay 100% of the booking amount online via digital wallets.",
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
}

class _DepositAcknowledgementCard extends StatelessWidget {
  final double depositAmount;
  final bool confirmed;
  final ValueChanged<bool?> onChanged;

  const _DepositAcknowledgementCard({
    required this.depositAmount,
    required this.confirmed,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(VSPSpacing.lg),
      decoration: BoxDecoration(
        color: VSPColors.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(
          color: confirmed ? VSPColors.accent : VSPColors.accent.withValues(alpha: 0.4),
          width: confirmed ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.lock, color: VSPColors.accent, size: 20),
              const SizedBox(width: 10),
              Text(
                'تأكيد العربون المطلوب',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: VSPColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'يشترط صاحب الملعب دفع عربون مسبق بقيمة ${depositAmount.toInt()} ج.م لتأكيد الحجز.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: VSPColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onChanged(!confirmed);
            },
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: confirmed ? VSPColors.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: confirmed ? VSPColors.accent : VSPColors.borderMedium,
                      width: 2,
                    ),
                  ),
                  child: confirmed
                      ? Icon(LucideIcons.check, size: 14, color: Colors.black)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'أؤكد أنني سأدفع / دفعت العربون البالغ ${depositAmount.toInt()} ج.م',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: confirmed ? VSPColors.textPrimary : VSPColors.textSecondary,
                      fontWeight: confirmed ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: VSPColors.accent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 12),
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
      ],
    );
  }
}

class _BookingSummaryCard extends StatelessWidget {
  final BookingDraft bookingDraft;
  const _BookingSummaryCard({required this.bookingDraft});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Container(
      padding: const EdgeInsets.all(VSPSpacing.lg),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(color: VSPColors.divider),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: VSPColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(VSPRadius.md)),
                child: Icon(LucideIcons.building, color: VSPColors.accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bookingDraft.stadiumName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
                    Text(bookingDraft.bookingType == BookingType.challenge ? l10n.challengeMatch : l10n.privateBooking, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: VSPColors.divider, height: 1)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem(context, LucideIcons.calendar, 
                DateFormat('yyyy/MM/dd').format(bookingDraft.startTime)),
              _buildSummaryItem(context, LucideIcons.clock, 
                DateFormat('hh:mm a').format(bookingDraft.startTime)),
              _buildSummaryItem(context, LucideIcons.trophy, 
                bookingDraft.bookingType == BookingType.challenge ? l10n.ranked : l10n.friendly),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(VSPSpacing.md),
            decoration: BoxDecoration(color: VSPColors.background, borderRadius: BorderRadius.circular(VSPRadius.md)),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.subtotalAmount, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary)),
                    Text('${bookingDraft.totalPrice.toInt()} ${l10n.egCurrency}', style: TextStyle(color: (bookingDraft.needsDeposit && bookingDraft.depositPaid > 0) ? VSPColors.textPrimary : VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                if (bookingDraft.needsDeposit && bookingDraft.depositPaid > 0) ...[
                  const SizedBox(height: 10),
                  const Divider(color: VSPColors.divider, height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isArabic ? 'العربون (يُدفع الآن)' : 'Deposit (Pay Now)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.accent, fontWeight: FontWeight.bold)),
                      Text('${bookingDraft.depositPaid.toInt()} ${l10n.egCurrency}', style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isArabic ? 'المتبقي (في الملعب)' : 'Remaining (At Pitch)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary)),
                      Text('${(bookingDraft.totalPrice - bookingDraft.depositPaid).clamp(0, double.infinity).toInt()} ${l10n.egCurrency}', style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: VSPColors.accent, size: 14),
        const SizedBox(width: 6),
        Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}


