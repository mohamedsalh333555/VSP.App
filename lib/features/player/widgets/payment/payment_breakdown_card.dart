import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/paymob_service.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';

/// Card showing the full transparent financial breakdown, stadium timing details, and service fees.
class PaymentBreakdownCard extends StatefulWidget {
  final BookingDraft bookingDraft;
  final bool isChampionship;
  final bool hasDeposit;
  final double amountToPay;
  final bool isArabic;

  const PaymentBreakdownCard({
    super.key,
    required this.bookingDraft,
    required this.isChampionship,
    required this.hasDeposit,
    required this.amountToPay,
    required this.isArabic,
  });


  late Future<PaymobFeeBreakdown> _feeBreakdownFuture;

  @override
  void initState() {
    super.initState();
    _feeBreakdownFuture = PaymobService.getFeeBreakdown(widget.amountToPay);
  }

  @override
  void didUpdateWidget(covariant PaymentBreakdownCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amountToPay != widget.amountToPay) {
      _feeBreakdownFuture = PaymobService.getFeeBreakdown(widget.amountToPay);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PaymobFeeBreakdown>(
      future: _feeBreakdownFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildUnavailableCard(context);
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final fees = snapshot.data!;
        return _buildCard(context, fees);
      },
    );
  }

  Widget _buildUnavailableCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Text(
        widget.isArabic
            ? 'تعذر تحميل سياسة الرسوم الرسمية من الخادم. لا يمكن عرض إجمالي دفع غير موثوق.'
            : 'Unable to load the authoritative fee policy. An unverified payment total cannot be shown.',
        style: const TextStyle(color: VSPColors.error, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildCard(BuildContext context, PaymobFeeBreakdown fees) {
    final String displayStadiumName =
        (widget.bookingDraft.stadiumName.trim().isEmpty || widget.bookingDraft.stadiumName.trim() == 'Mo')
            ? (widget.isArabic ? 'الملعب الرئيسي' : 'Main Pitch')
            : widget.bookingDraft.stadiumName;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(widget.isChampionship ? Iconsax.cup_copy : Iconsax.building_copy,
                  color: VSPColors.textSecondary, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  displayStadiumName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Iconsax.calendar_1_copy, color: VSPColors.textSecondary, size: 14),
              const SizedBox(width: 8),
              Text(
                DateFormat('yyyy/MM/dd').format(widget.bookingDraft.startTime),
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(width: 14),
              const Icon(Iconsax.clock_copy, color: VSPColors.textSecondary, size: 14),
              const SizedBox(width: 6),
              Text(
                DateFormat('hh:mm a').format(widget.bookingDraft.startTime),
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const Divider(color: VSPColors.divider, height: 20),
          _buildFeeRow(
            label: widget.isChampionship
                ? (widget.isArabic ? 'رسوم اشتراك البطولة' : 'Championship Entry Fee')
                : (widget.hasDeposit
                    ? (widget.isArabic ? 'عربون حجز الملعب' : 'Stadium Deposit')
                    : (widget.isArabic ? 'إجمالي سعر حجز الملعب' : 'Stadium Total Price')),
            value: '${widget.amountToPay.toInt()} ${widget.isArabic ? 'ج.م' : 'EGP'}',
          ),
          const SizedBox(height: 6),
          _buildFeeRow(
            label: widget.isArabic ? 'رسوم خدمات المنصة' : 'Platform Service Fee',
            value: '${fees.totalFees.toStringAsFixed(2)} ${widget.isArabic ? 'ج.م' : 'EGP'}',
            onInfoTap: () => showFeeTransparencyModal(context, widget.isArabic),
          ),
          const SizedBox(height: 6),
          _buildFeeRow(
            label: widget.isArabic ? 'إجمالي الدفع النهائي' : 'Total Checkout Amount',
            value: '${fees.totalAmount.toStringAsFixed(2)} ${widget.isArabic ? 'ج.م' : 'EGP'}',
            isBold: true,
          ),
          if (widget.hasDeposit && (widget.bookingDraft.totalPrice - widget.amountToPay) > 0) ...[
            const SizedBox(height: 6),
            _buildFeeRow(
              label: widget.isArabic ? 'المتبقي وسداده كاش بالملعب' : 'Remaining Pay at Pitch',
              value: '${(widget.bookingDraft.totalPrice - widget.amountToPay).toInt()} ${widget.isArabic ? 'ج.م' : 'EGP'}',
            ),
          ],
        ],
      ),
    );
  }

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/paymob_service.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';

/// Card showing the full transparent financial breakdown, stadium timing details, and service fees.
class PaymentBreakdownCard extends StatefulWidget {
  final BookingDraft bookingDraft;
  final bool isChampionship;
  final bool hasDeposit;
  final double amountToPay;
  final bool isArabic;

  const PaymentBreakdownCard({
    super.key,
    required this.bookingDraft,
    required this.isChampionship,
    required this.hasDeposit,
    required this.amountToPay,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final double serviceFee = PaymobService.calculateServiceFee(amountToPay);
    final double totalWithFees = PaymobService.calculateTotalAmount(amountToPay);

    final String displayStadiumName =
        (bookingDraft.stadiumName.trim().isEmpty || bookingDraft.stadiumName.trim() == 'Mo')
            ? (isArabic ? 'الملعب الرئيسي' : 'Main Pitch')
            : bookingDraft.stadiumName;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(isChampionship ? Iconsax.cup_copy : Iconsax.building_copy,
                  color: VSPColors.textSecondary, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  displayStadiumName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Iconsax.calendar_1_copy, color: VSPColors.textSecondary, size: 14),
              const SizedBox(width: 8),
              Text(
                DateFormat('yyyy/MM/dd').format(bookingDraft.startTime),
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(width: 14),
              const Icon(Iconsax.clock_copy, color: VSPColors.textSecondary, size: 14),
              const SizedBox(width: 6),
              Text(
                DateFormat('hh:mm a').format(bookingDraft.startTime),
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const Divider(color: VSPColors.divider, height: 20),
          _buildFeeRow(
            label: isChampionship
                ? (isArabic ? 'رسوم اشتراك البطولة' : 'Championship Entry Fee')
                : (hasDeposit
                    ? (isArabic ? 'عربون حجز الملعب' : 'Stadium Deposit')
                    : (isArabic ? 'إجمالي سعر حجز الملعب' : 'Stadium Total Price')),
            value: '${amountToPay.toInt()} ${isArabic ? 'ج.م' : 'EGP'}',
            isBold: false,
          ),
          const SizedBox(height: 6),
          _buildFeeRow(
            label: isArabic ? 'رسوم خدمات المنصة' : 'Platform Service Fee',
            value: '${serviceFee.toStringAsFixed(1)} ${isArabic ? 'ج.م' : 'EGP'}',
            isBold: false,
            onInfoTap: () => showFeeTransparencyModal(context, isArabic),
          ),
          const SizedBox(height: 6),
          _buildFeeRow(
            label: isArabic ? 'إجمالي الدفع النهائي' : 'Total Checkout Amount',
            value: '${totalWithFees.toStringAsFixed(1)} ${isArabic ? 'ج.م' : 'EGP'}',
            isBold: true,
          ),
          if (hasDeposit && (bookingDraft.totalPrice - amountToPay) > 0) ...[
            const SizedBox(height: 6),
            _buildFeeRow(
              label: isArabic ? 'المتبقي وسداده كاش بالملعب' : 'Remaining Pay at Pitch',
              value: '${(bookingDraft.totalPrice - amountToPay).toInt()} ${isArabic ? 'ج.م' : 'EGP'}',
            ),
          ],
        ],
      ),
    );
  }

