import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
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
import '../../../core/repositories/chat_repository.dart';
import '../../../core/models/chat_model.dart';

class PaymentGatewayScreen extends StatefulWidget {
  final BookingDraft bookingDraft;
  final bool forceFullPayment;

  const PaymentGatewayScreen({
    super.key,
    required this.bookingDraft,
    this.forceFullPayment = false,
  });

  @override
  State<PaymentGatewayScreen> createState() => _PaymentGatewayScreenState();
}

class _PaymentGatewayScreenState extends State<PaymentGatewayScreen> {
  bool _isLoading = false;
  int _selectedOptionIndex = 0;
  bool _depositConfirmed = false;
  String? _ownerPhone;
  String? _ownerInstapay;
  String? _ownerVodafone;
  String? _ownerBank;
  bool _isLoadingPhone = true;
  XFile? _receiptImage;
  Timer? _timer;
  int _secondsRemaining = 600;

  Booking? _booking;
  late TextEditingController _chatController;
  bool _receiptUploaded = false;
  String? _uploadedReceiptUrl;

  @override
  void initState() {
    super.initState();
    _chatController = TextEditingController();
    _fetchOwnerPhone();
    _startTimer();
    _createPendingBooking();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _createPendingBooking() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.uid;
    if (userId != null) {
      final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
      final draft = widget.bookingDraft.copyWith(
        paymentStatus: 'pending',
        paymentMethod: 'manual_transfer',
      );
      final booking = await bookingProvider.createBooking(draft, userId);
      if (mounted) {
        setState(() {
          _booking = booking;
        });
      }
    }
  }

  void _sendChatMessage() {
    if (_chatController.text.trim().isEmpty || _booking == null) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.userModel;
    if (user == null) return;

    final message = ChatMessage(
      id: '',
      senderId: user.uid,
      senderName: user.name ?? 'Guest',
      text: _chatController.text.trim(),
      timestamp: DateTime.now(),
    );

    ChatRepository().sendMessage(_booking!.id, message);
    _chatController.clear();
  }

  Future<void> _uploadReceiptFromChat() async {
    if (_booking == null) return;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userId = auth.currentUser?.uid;
      if (userId == null) return;

      final receiptUrl = await StorageService().uploadFile(
        file: image,
        bucket: 'deposit-receipts',
        path: 'bookings/$userId/receipts/rec_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      if (receiptUrl != null) {
        final message = ChatMessage(
          id: '',
          senderId: userId,
          senderName: auth.userModel?.name ?? 'Player',
          text: '[Receipt]: $receiptUrl',
          timestamp: DateTime.now(),
        );
        await ChatRepository().sendMessage(_booking!.id, message);
        
        setState(() {
          _uploadedReceiptUrl = receiptUrl;
          _receiptUploaded = true;
          _isLoading = false;
        });

        if (mounted) {
          VSPFeedback.showSuccess(context, isArabic ? 'تم رفع الإيصال في المحادثة بنجاح!' : 'Receipt uploaded successfully to chat!');
        }
      } else {
        throw Exception('Failed to upload file');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        VSPFeedback.showError(context, isArabic ? 'فشل رفع الإيصال: $e' : 'Failed to upload receipt: $e');
      }
    }
  }

  Widget _buildOwnerPaymentDetails(BuildContext context, bool isArabic) {
    if (_isLoadingPhone) {
      return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
    }

    final hasInstapay = _ownerInstapay != null && _ownerInstapay!.trim().isNotEmpty;
    final hasVodafone = _ownerVodafone != null && _ownerVodafone!.trim().isNotEmpty;
    final hasBank = _ownerBank != null && _ownerBank!.trim().isNotEmpty;

    if (!hasInstapay && !hasVodafone && !hasBank) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.xl),
          border: Border.all(color: VSPColors.divider),
        ),
        child: Text(
          isArabic
              ? 'تنبيه: لم يقم صاحب الملعب بتحديد إعدادات تحصيل P2P بعد. يرجى التواصل معه هاتفياً.'
              : 'Warning: Stadium owner has not set up P2P receivables yet. Please contact them directly.',
          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
        ),
      );
    }

    return Container(
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
            isArabic ? 'حسابات تحويل صاحب الملعب:' : 'Stadium Owner Payment Details:',
            style: const TextStyle(fontWeight: FontWeight.bold, color: VSPColors.accent, fontSize: 14),
          ),
          const SizedBox(height: 12),
          if (hasInstapay)
            _buildCopyableRow(
              context,
              icon: LucideIcons.smartphone,
              label: isArabic ? 'عنوان إنستا باي / InstaPay IPN:' : 'InstaPay IPN:',
              value: _ownerInstapay!,
              successMsg: isArabic ? 'تم نسخ عنوان إنستا باي!' : 'InstaPay IPN copied!',
            ),
          if (hasInstapay && (hasVodafone || hasBank)) const SizedBox(height: 12),
          if (hasVodafone)
            _buildCopyableRow(
              context,
              icon: LucideIcons.banknote,
              label: isArabic ? 'رقم محفظة فودافون كاش:' : 'Vodafone Cash:',
              value: _ownerVodafone!,
              successMsg: isArabic ? 'تم نسخ رقم فودافون كاش!' : 'Vodafone Cash number copied!',
            ),
          if (hasVodafone && hasBank) const SizedBox(height: 12),
          if (hasBank)
            _buildCopyableRow(
              context,
              icon: LucideIcons.building,
              label: isArabic ? 'تفاصيل الحساب البنكي / IBAN:' : 'Bank Account/IBAN Details:',
              value: _ownerBank!,
              successMsg: isArabic ? 'تم نسخ تفاصيل الحساب البنكي!' : 'Bank details copied!',
            ),
        ],
      ),
    );
  }

  Widget _buildCopyableRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required String successMsg,
  }) {
    return Row(
      children: [
        Icon(icon, color: VSPColors.textSecondary, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11)),
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
        IconButton(
          icon: Icon(LucideIcons.copy, color: VSPColors.accent, size: 16),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(successMsg, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  backgroundColor: VSPColors.accent,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildForceFullPaymentWarningCard(BuildContext context, bool isArabic) {
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
                isArabic ? "تأكيد الحجز الإجباري" : "Required Online Booking",
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
                ? "تنبيه: نظراً لوجود حجز آخر نشط لم يتم لعبه بعد، يتعين دفع كامل قيمة هذا الحجز الجديد (الأجرة كاملة) لتأكيده."
                : "Warning: Because you have another active booking, you must pay the full price to confirm this new booking.",
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

  Widget _buildDepositWarningCard(BuildContext context, bool isArabic, double depositAmount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VSPColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.alertCircle, color: VSPColors.accent, size: 20),
              const SizedBox(width: 10),
              Text(
                isArabic ? "متطلبات العربون" : "Deposit Required",
                style: const TextStyle(
                  color: VSPColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
                ? "تنبيه: يشترط هذا الملعب دفع عربون بقيمة ${depositAmount.toInt()} ج.م لتأكيد حجز الساعة."
                : "Warning: This stadium requires a deposit of ${depositAmount.toInt()} EGP to confirm the booking.",
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

  Widget _buildEmbeddedChat(BuildContext context, bool isArabic) {
    if (_booking == null) {
      return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUser?.uid;

    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: ChatRepository().getChatMessages(_booking!.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
                }
                final messages = snapshot.data ?? [];
                
                final hasReceipt = messages.any((msg) =>
                    msg.senderId == currentUserId && msg.text.startsWith('[Receipt]:'));
                
                if (hasReceipt && !_receiptUploaded) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() {
                      _receiptUploaded = true;
                    });
                  });
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUserId;
                    return _buildEmbeddedChatBubble(message, isMe);
                  },
                );
              },
            ),
          ),
          const Divider(color: VSPColors.divider, height: 1),
          _buildChatInputRow(isArabic),
        ],
      ),
    );
  }

  Widget _buildEmbeddedChatBubble(ChatMessage message, bool isMe) {
    final isReceipt = message.text.startsWith('[Receipt]:');
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? VSPColors.accent : VSPColors.surfaceAlt,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMe ? 12 : 3),
            bottomRight: Radius.circular(isMe ? 3 : 12),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe)
              Text(
                message.senderName,
                style: const TextStyle(color: VSPColors.accent, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            if (!isMe) const SizedBox(height: 2),
            if (isReceipt)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  message.text.substring(10).trim(),
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              )
            else
              Text(
                message.text,
                style: TextStyle(color: isMe ? VSPColors.background : VSPColors.textPrimary, fontSize: 13),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatInputRow(bool isArabic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: VSPColors.surface,
      child: Row(
        children: [
          IconButton(
            icon: Icon(LucideIcons.paperclip, color: VSPColors.accent, size: 20),
            onPressed: _uploadReceiptFromChat,
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: VSPColors.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: VSPColors.divider, width: 0.5),
              ),
              child: TextField(
                controller: _chatController,
                style: const TextStyle(color: VSPColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: isArabic ? 'اكتب رسالة...' : 'Type a message...',
                  hintStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendChatMessage(),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(LucideIcons.send, color: VSPColors.accent, size: 20),
            onPressed: _sendChatMessage,
          ),
        ],
      ),
    );
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  String get _formattedTime {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _fetchOwnerPhone() async {
    try {
      final ownerId = widget.bookingDraft.ownerId;
      if (ownerId.isNotEmpty) {
        final userData = await UserRepository().getUserData(ownerId);
        if (userData != null && mounted) {
          setState(() {
            _ownerPhone = userData['phone']?.toString();
            _ownerInstapay = userData['p2p_instapay'] ?? userData['p2pInstapay'];
            _ownerVodafone = userData['p2p_vodafone'] ?? userData['p2pVodafone'];
            _ownerBank = userData['p2p_bank'] ?? userData['p2pBank'];
            _isLoadingPhone = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching owner details: $e');
    }
    if (mounted) {
      setState(() => _isLoadingPhone = false);
    }
  }

  void _showCashLimitDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: VSPColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VSPRadius.lg),
            side: const BorderSide(color: VSPColors.error, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(LucideIcons.alertTriangle, color: VSPColors.error),
              SizedBox(width: 8),
              Text(
                'تنبيه النظام 🛑',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Text(
            message.replaceFirst('Failed to create booking: ', '').replaceFirst('Exception: ', ''),
            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('موافق', style: TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDoubleBookingDialog() {
    HapticFeedback.heavyImpact();
    final outerContext = context;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: AlertDialog(
            backgroundColor: VSPColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                const Icon(
                  LucideIcons.calendarX,
                  color: VSPColors.error,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'عذراً، جزء من هذا الوقت تم حجزه وتأكيده للتو من لاعب آخر. يرجى العودة وتحديث الأوقات المتاحة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: VSPColors.textPrimary,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  text: 'العودة لاختيار وقت آخر',
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    if (outerContext.mounted) {
                      Navigator.pop(outerContext);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _processPayment() async {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.uid;
    
    if (userId == null || _booking == null) {
      VSPFeedback.showError(context, l10n.sessionExpiredError);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final receiptUrl = _uploadedReceiptUrl;
      
      // Update the pending booking in Supabase to awaiting_verification
      await Supabase.instance.client.from('bookings').update({
        'payment_status': 'awaiting_verification',
        'payment_method': 'manual_transfer',
        'payment_transaction_id': 'TRANSFER_RC_manual',
        'notes': '${_booking!.notes ?? ""}\n[Manual Receipt]: $receiptUrl'.trim(),
      }).eq('id', _booking!.id);

      final updatedBooking = await Provider.of<BookingProvider>(context, listen: false)
          .getBookingById(_booking!.id);

      setState(() => _isLoading = false);

      if (updatedBooking != null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => BookingSuccessScreen(booking: updatedBooking),
            ),
          );
        }
      } else {
        throw Exception('Failed to reload updated booking');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
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
    final activeOptionIndex = (isCashLocked || widget.forceFullPayment) ? 1 : _selectedOptionIndex;
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
                // ⏳ FOMO Timer Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: VSPColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(color: VSPColors.error),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.clock, color: VSPColors.error, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '⏳ يرجى إتمام الدفع أو إرفاق الإيصال خلال $_formattedTime وإلا سيتم إلغاء الحجز.',
                          style: const TextStyle(
                            color: VSPColors.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Volt Green Bordered Alert Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: VSPColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(color: VSPColors.accent, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.alertCircle, color: VSPColors.accent, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isArabic 
                              ? '📸 حوّل وابعت اسكرين تأكيد في الشات لمنع إلغاء الحجز تلقائياً 💳'
                              : '📸 Transfer and send confirmation screen in chat to prevent auto cancellation 💳',
                          style: const TextStyle(
                            color: VSPColors.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (widget.forceFullPayment) ...[
                  _buildForceFullPaymentWarningCard(context, isArabic),
                  const SizedBox(height: 24),
                ] else if (isCashLocked) ...[
                  _buildRestrictedWarningCard(context, isArabic),
                  const SizedBox(height: 24),
                ] else if (hasDeposit) ...[
                  _buildDepositWarningCard(context, isArabic, widget.bookingDraft.depositPaid),
                  const SizedBox(height: 24),
                ],

                VSPFadeInItem(delay: const Duration(milliseconds: 100), child: _SectionHeader(title: l10n.bookingSummary)),
                const SizedBox(height: 16),
                VSPFadeInItem(delay: const Duration(milliseconds: 200), child: _BookingSummaryCard(bookingDraft: widget.bookingDraft)),
                const SizedBox(height: 32),
                VSPFadeInItem(delay: const Duration(milliseconds: 300), child: _SectionHeader(title: l10n.paymentMethod)),
                const SizedBox(height: 16),
                VSPFadeInItem(delay: const Duration(milliseconds: 400), child: _buildPaymentOptionsList(context, isCashLocked || widget.forceFullPayment, activeOptionIndex)),
                const SizedBox(height: 24),
                VSPFadeInItem(
                  delay: const Duration(milliseconds: 410),
                  child: _buildOwnerPaymentDetails(context, isArabic),
                ),
                const SizedBox(height: 24),
                if (!_isLoadingPhone && _ownerPhone != null && _ownerPhone!.isNotEmpty) ...[
                  VSPFadeInItem(
                    delay: const Duration(milliseconds: 420),
                    child: _buildContactPitchButton(context, _ownerPhone!),
                  ),
                  const SizedBox(height: 24),
                ],
                const SizedBox(height: 8),
                VSPFadeInItem(
                  delay: const Duration(milliseconds: 430),
                  child: _buildEmbeddedChat(context, isArabic),
                ),
                const SizedBox(height: 24),
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
                    text: _secondsRemaining == 0 
                      ? (isArabic ? 'انتهى وقت الحجز' : 'Booking expired') 
                      : (isArabic ? 'تم التحويل، إخطار المالك' : 'Transferred, notify seller'),
                    isLoading: _isLoading,
                    onPressed: (_secondsRemaining == 0 || !_receiptUploaded) ? null : _processPayment,
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


