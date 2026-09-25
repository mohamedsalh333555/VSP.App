import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/repositories/owner_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../screens/owner_account_management_screen.dart';

/// Modal dialogs for requesting digital balance payouts and settlements.
class OwnerPayoutDialog {
  const OwnerPayoutDialog._();

  /// Displays payout request modal with payment destination verification.
  static void show(BuildContext context, double digitalBalance, bool isAr) {
    HapticFeedback.mediumImpact();
    if (digitalBalance <= 0) {
      VSPFeedback.showWarning(
        context,
        isAr ? 'لا يوجد رصيد إلكتروني متاح للسحب حالياً.' : 'No available digital balance for payout.',
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.userModel;

    final hasPayoutMethod = (user?.p2pInstapay?.isNotEmpty ?? false) ||
        (user?.p2pVodafone?.isNotEmpty ?? false) ||
        (user?.p2pBank?.isNotEmpty ?? false);

    if (!hasPayoutMethod) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: VSPColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
          title: Text(
            isAr ? 'وسيلة التحصيل غير مسجلة' : 'Payout Method Required',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          content: Text(
            isAr
                ? 'يرجى تسجيل وسيلة تحصيل واحدة على الأقل (إنستاباي أو محفظة إلكترونية أو حساب بنكي) في إعدادات الحساب لتتمكن من استلام مستحقاتك.'
                : 'Please add at least one payout method (InstaPay, Mobile Wallet, or Bank IBAN) in Account Settings to request settlements.',
            style: const TextStyle(color: VSPColors.textSecondary, height: 1.5, fontSize: 13),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isAr ? 'إلغاء' : 'Cancel', style: const TextStyle(color: VSPColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OwnerAccountManagementScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: VSPColors.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.sm)),
              ),
              child: Text(
                isAr ? 'إضافة وسيلة تحصيل' : 'Add Payout Method',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
      return;
    }

    final availableDestinations = <Map<String, String>>[];
    if (user?.p2pInstapay?.isNotEmpty ?? false) {
      availableDestinations.add({
        'id': 'instapay',
        'title': isAr ? 'إنستاباي (InstaPay)' : 'InstaPay',
        'value': user!.p2pInstapay!,
      });
    }
    if (user?.p2pVodafone?.isNotEmpty ?? false) {
      availableDestinations.add({
        'id': 'wallet',
        'title': isAr ? 'محفظة إلكترونية (فودافون كاش / وغيرها)' : 'Mobile Wallet',
        'value': user!.p2pVodafone!,
      });
    }
    if (user?.p2pBank?.isNotEmpty ?? false) {
      availableDestinations.add({
        'id': 'bank',
        'title': isAr ? 'حساب بنكي (IBAN)' : 'Bank IBAN',
        'value': user!.p2pBank!,
      });
    }

    showDialog(
      context: context,
      builder: (ctx) => _PayoutDialogContent(
        digitalBalance: digitalBalance,
        isAr: isAr,
        destinations: availableDestinations,
        onCancel: () => Navigator.pop(ctx),
        onSubmit: (amount, method, destination) async {
          final res = await OwnerRepository().requestPayoutSettlement(
            amount: amount,
            method: method,
            destination: destination,
          );

          if (!ctx.mounted) return;
          Navigator.pop(ctx);

          if (context.mounted) {
            if (res['success'] == true) {
              VSPFeedback.showSuccess(
                context,
                isAr
                    ? 'تم إرسال طلب تسوية بمبلغ ${amount.toStringAsFixed(0)} ج.م للإدارة بنجاح.\nسيتم إشعارك فور إتمام التحويل.'
                    : 'Payout settlement request of ${amount.toStringAsFixed(0)} EGP submitted successfully.',
              );
            } else {
              VSPFeedback.showError(
                context,
                res['error']?.toString() ?? (isAr ? 'فشل إرسال طلب التسوية' : 'Failed to submit request'),
              );
            }
          }
        },
      ),
    );
  }
}

class _PayoutDialogContent extends StatefulWidget {
  final double digitalBalance;
  final bool isAr;
  final List<Map<String, String>> destinations;
  final VoidCallback onCancel;
  final Future<void> Function(double amount, String method, String destination) onSubmit;

  const _PayoutDialogContent({
    required this.digitalBalance,
    required this.isAr,
    required this.destinations,
    required this.onCancel,
    required this.onSubmit,
  });

  @override
  State<_PayoutDialogContent> createState() => _PayoutDialogContentState();
}

class _PayoutDialogContentState extends State<_PayoutDialogContent> {
  late final TextEditingController _amountController;
  late String _selectedMethodId;
  bool _isSubmitting = false;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.digitalBalance.toStringAsFixed(0));
    _selectedMethodId = widget.destinations.first['id']!;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _validateAmount(String val) {
    final parsed = double.tryParse(val.trim());
    setState(() {
      if (parsed == null || parsed <= 0) {
        _amountError = widget.isAr ? 'يرجى إدخال مبلغ صحيح أكبر من صفر' : 'Enter a valid amount';
      } else if (parsed > widget.digitalBalance) {
        _amountError = widget.isAr ? 'المبلغ المطلوب أكبر من رصيدك المتاح' : 'Amount exceeds available balance';
      } else {
        _amountError = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedDest = widget.destinations.firstWhere(
      (d) => d['id'] == _selectedMethodId,
      orElse: () => widget.destinations.first,
    );

    return AlertDialog(
      backgroundColor: VSPColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
      title: Text(
        widget.isAr ? 'طلب تسوية وسحب الرصيد' : 'Request Payout Settlement',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.isAr ? 'الرصيد المتاح للسحب:' : 'Available Balance:',
                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                ),
                Text(
                  '${widget.digitalBalance.toStringAsFixed(0)} ${widget.isAr ? "ج.م" : "EGP"}',
                  style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.isAr ? 'المبلغ المطلوب سحبه:' : 'Payout Amount:',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
              onChanged: _validateAmount,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              decoration: InputDecoration(
                filled: true,
                fillColor: VSPColors.inputFill,
                hintText: '0',
                suffixText: widget.isAr ? 'ج.م' : 'EGP',
                suffixStyle: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold),
                errorText: _amountError,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(VSPRadius.sm), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: widget.isAr ? Alignment.centerLeft : Alignment.centerRight,
              child: GestureDetector(
                onTap: () {
                  _amountController.text = widget.digitalBalance.toStringAsFixed(0);
                  _validateAmount(_amountController.text);
                },
                child: Text(
                  widget.isAr ? 'سحب كامل الرصيد (${widget.digitalBalance.toInt()} ج.م)' : 'Withdraw Full Balance (${widget.digitalBalance.toInt()} EGP)',
                  style: const TextStyle(color: VSPColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.isAr ? 'جهة التحويل المطلوبة:' : 'Transfer Destination:',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            ...widget.destinations.map((dest) {
              final isSelected = dest['id'] == _selectedMethodId;
              return GestureDetector(
                onTap: () => setState(() => _selectedMethodId = dest['id']!),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? VSPColors.accent.withValues(alpha: 0.1) : VSPColors.inputFill,
                    borderRadius: BorderRadius.circular(VSPRadius.sm),
                    border: Border.all(
                      color: isSelected ? VSPColors.accent : Colors.white.withValues(alpha: 0.08),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: isSelected ? VSPColors.accent : VSPColors.textSecondary,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dest['title']!,
                              style: TextStyle(
                                color: isSelected ? Colors.white : VSPColors.textSecondary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              dest['value']!,
                              style: TextStyle(
                                color: isSelected ? VSPColors.accent : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            Text(
              widget.isAr
                  ? 'تتم مراجعة طلبات التسوية وإتمام التحويل من قِبل الإدارة خلال 24 ساعة.'
                  : 'Settlements are reviewed and disbursed by administration within 24 hours.',
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11, height: 1.4),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _isSubmitting ? null : widget.onCancel,
                child: Text(widget.isAr ? 'إلغاء' : 'Cancel', style: const TextStyle(color: VSPColors.textSecondary)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: (_isSubmitting || _amountError != null)
                    ? null
                    : () async {
                        final parsed = double.tryParse(_amountController.text.trim()) ?? 0.0;
                        if (parsed <= 0 || parsed > widget.digitalBalance) {
                          _validateAmount(_amountController.text);
                          return;
                        }
                        setState(() => _isSubmitting = true);
                        await widget.onSubmit(parsed, selectedDest['id']!, selectedDest['value']!);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: VSPColors.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.sm)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : Text(widget.isAr ? 'تأكيد الإرسال' : 'Confirm Request', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

