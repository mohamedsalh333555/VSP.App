import '../../l10n/app_localizations.dart';

enum RefundChannel { wallet, card, cash }

enum RefundEta { minutes, businessDays, immediate }

class RefundInfo {
  final String? refundTransactionId;
  final DateTime? refundedAt;
  final RefundChannel channel;
  final RefundEta eta;
  final double refundAmount;
  final bool amountConfirmed;
  final bool hasNoPaidAmount;

  /// صح لو الحجز كاش صافي ومفيش أي عربون أونلاين مدفوع
  final bool isPureCashNoDeposit;

  const RefundInfo({
    this.refundTransactionId,
    this.refundedAt,
    required this.channel,
    required this.eta,
    required this.refundAmount,
    this.amountConfirmed = true,
    this.hasNoPaidAmount = false,
    this.isPureCashNoDeposit = false,
  });

  factory RefundInfo.fromBookingRow(Map<String, dynamic> row) {
    final channelStr = row['refund_channel'] as String? ?? 
        _detectChannel(row['refund_payment_method'] ?? row['payment_method']);
    final etaStr = row['refund_eta'] as String? ?? 
        _detectEta(channelStr);

    final rawDate = row['refunded_at'] ?? row['cancelled_at'];
    DateTime? parsedDate;
    if (rawDate != null) {
      if (rawDate is DateTime) {
        parsedDate = rawDate;
      } else {
        parsedDate = DateTime.tryParse(rawDate.toString());
      }
    }

    final displayRef = row['display_refund_ref'] as String? ??
        row['refund_transaction_id'] as String? ??
        row['refund_txn_id'] as String? ??
        row['payment_reference'] as String? ??
        row['paymob_transaction_id'] as String?;

    final recordedAmount = (row['refund_amount'] as num?)?.toDouble();
    final paymentStatus = row['payment_status']?.toString().toLowerCase() ?? '';
    final hasPaidAmount = row['is_paid'] == true ||
        row['is_deposit_paid'] == true ||
        ((row['deposit_paid'] as num?)?.toDouble() ?? 0) > 0 ||
        ['paid', 'refund_pending', 'refunded'].contains(paymentStatus);
    final isPureCash = _detectChannel(row['payment_method']) == 'cash' && !hasPaidAmount;

    return RefundInfo(
      refundTransactionId: displayRef,
      refundedAt: parsedDate,
      channel: switch (channelStr) {
        'wallet' => RefundChannel.wallet,
        'card'   => RefundChannel.card,
        _        => RefundChannel.cash,
      },
      eta: switch (etaStr) {
        'minutes'          => RefundEta.minutes,
        '3-5_business_days' => RefundEta.businessDays,
        _                  => RefundEta.immediate,
      },
      refundAmount: recordedAmount ?? 0.0,
      amountConfirmed: recordedAmount != null || !hasPaidAmount,
      hasNoPaidAmount: !hasPaidAmount,
      isPureCashNoDeposit: isPureCash,
    );
  }

  static String _detectChannel(dynamic method) {
    final m = method?.toString().toLowerCase() ?? '';
    if (m == 'wallet' || m == 'vodafone_cash' || m == 'instapay') return 'wallet';
    if (m == 'card' || m == 'paymob' || m == 'online') return 'card';
    return 'cash';
  }

  static String _detectEta(String channel) {
    if (channel == 'wallet') return 'minutes';
    if (channel == 'card') return '3-5_business_days';
    return 'immediate';
  }

  bool get hasReference => refundTransactionId != null && refundTransactionId!.isNotEmpty;

  String get badgeText => switch (channel) {
    RefundChannel.wallet => 'مسترد للمحفظة',
    RefundChannel.card   => 'مسترد بنكياً',
    RefundChannel.cash   => 'مسترد نقداً',
  };

  String get etaText => switch (eta) {
    RefundEta.minutes      => 'خلال دقائق',
    RefundEta.businessDays => '3–5 أيام عمل',
    RefundEta.immediate    => 'فوري',
  };

  String localizedBadgeText(AppLocalizations l10n) => switch (channel) {
    RefundChannel.wallet => l10n.refundChannelWalletBadge,
    RefundChannel.card   => l10n.refundChannelCardBadge,
    RefundChannel.cash   => l10n.refundChannelCashBadge,
  };

  String localizedEtaText(AppLocalizations l10n) => switch (eta) {
    RefundEta.minutes      => l10n.refundEtaMinutes,
    RefundEta.businessDays => l10n.refundEtaDays,
    RefundEta.immediate    => 'فوري',
  };

  String refundNoticeText(String amountFormatted) {
    if (hasNoPaidAmount || (amountConfirmed && refundAmount <= 0)) {
      return 'لا يوجد مبلغ مسترد مستحق وفق بيانات الدفع المسجلة لهذا الحجز.';
    }
    if (!amountConfirmed) {
      return 'سيتم تأكيد مبلغ الاسترداد من الخادم بعد إلغاء الحجز.';
    }
    // لو كاش صافي — اللاعب ما دفعش أي مبلغ إلكتروني، مفيش حاجة هتسترد
    if (isPureCashNoDeposit) {
      return 'لم يتم سداد أي مبلغ إلكتروني لهذا الحجز. سيتم إلغاؤه دون أي خصم.';
    }
    return switch (channel) {
      RefundChannel.wallet =>
        'سيتم استرداد $amountFormatted إلى محفظتك الإلكترونية خلال دقائق معدودة.',
      RefundChannel.card =>
        'سيتم تحويل $amountFormatted إلى حساب بطاقتك البنكية خلال 3–5 أيام عمل بحسب نظام بنكك.',
      RefundChannel.cash =>
        'سيتم استرداد $amountFormatted نقداً فور إلغاء الحجز.',
    };
  }

  String localizedNoticeText(AppLocalizations l10n, String typeText, String amountFormatted) {
    if (hasNoPaidAmount || (amountConfirmed && refundAmount <= 0)) {
      return l10n.localeName == 'ar'
          ? 'لا يوجد مبلغ مسترد مستحق وفق بيانات الدفع المسجلة لهذا الحجز.'
          : 'No refund is due according to the recorded payment details.';
    }
    if (!amountConfirmed) {
      return l10n.localeName == 'ar'
          ? 'سيتم تأكيد مبلغ الاسترداد من الخادم بعد إلغاء الحجز.'
          : 'The server will confirm the refundable amount after cancellation.';
    }
    return switch (channel) {
    RefundChannel.wallet => l10n.refundNoticeWallet(typeText, amountFormatted),
    RefundChannel.card   => l10n.refundNoticeCard(typeText, amountFormatted),
    RefundChannel.cash   => l10n.refundNoticeCash(amountFormatted),
    };
  }

  String refundSuccessText() {
    if (hasNoPaidAmount || (amountConfirmed && refundAmount <= 0)) {
      return 'تم إلغاء الحجز. لا يوجد مبلغ مسترد مستحق وفق بيانات الدفع المسجلة.';
    }
    if (!amountConfirmed) {
      return 'تم إلغاء الحجز. سيتم تأكيد مبلغ الاسترداد من الخادم بعد معالجة الطلب.';
    }
    // لو كاش صافي — رسالة واضحة إن الإلغاء تم ومفيش مبلغ هيسترد
    if (isPureCashNoDeposit) {
      return 'تم إلغاء الحجز بنجاح. لم يتم خصم أي مبلغ من حسابك.';
    }
    return switch (channel) {
      RefundChannel.wallet =>
        'تم إلغاء الحجز بنجاح وجاري إيداع المبلغ في محفظتك.',
      RefundChannel.card =>
        'تم إلغاء الحجز بنجاح، وتستغرق المعاملة البنكية 3–5 أيام عمل للظهور في كشف حساب بطاقتك.',
      RefundChannel.cash =>
        'تم إلغاء الحجز بنجاح وسيتم استرداد المبلغ نقداً.',
    };
  }

  String localizedSuccessText(AppLocalizations l10n) {
    if (hasNoPaidAmount || (amountConfirmed && refundAmount <= 0)) {
      return l10n.localeName == 'ar'
          ? 'تم إلغاء الحجز. لا يوجد مبلغ مسترد مستحق وفق بيانات الدفع المسجلة.'
          : 'Booking cancelled. No refund is due according to the recorded payment details.';
    }
    if (!amountConfirmed) {
      return l10n.localeName == 'ar'
          ? 'تم إلغاء الحجز. سيتم تأكيد مبلغ الاسترداد من الخادم بعد معالجة الطلب.'
          : 'Booking cancelled. The server will confirm the refundable amount after processing.';
    }
    return switch (channel) {
    RefundChannel.wallet => l10n.refundSuccessWallet,
    RefundChannel.card   => l10n.refundSuccessCard,
    RefundChannel.cash   => l10n.refundSuccessCash,
    };
  }
}
