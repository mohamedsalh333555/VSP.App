class AppSettings {
  final String supportPhone;
  final String whatsappNumber;
  final String supportEmail;
  final String vodafoneCashNumber;
  final String instapayHandle;
  final bool cashBookingEnabled;
  final bool onlinePaymentEnabled;

  const AppSettings({
    this.supportPhone = '',
    this.whatsappNumber = '',
    this.supportEmail = '',
    this.vodafoneCashNumber = '',
    this.instapayHandle = '',
    this.cashBookingEnabled = false,
    this.onlinePaymentEnabled = false,
  });

  factory AppSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) throw StateError('App settings row is missing from Supabase.');
    return AppSettings(
      supportPhone: data['support_phone'] ?? data['supportPhone'] ?? '',
      whatsappNumber: data['whatsapp_number'] ?? data['whatsappNumber'] ?? '',
      supportEmail: data['support_email'] ?? data['supportEmail'] ?? '',
      vodafoneCashNumber: data['vodafone_cash_number'] ?? data['vodafoneCashNumber'] ?? data['vodafone_cash'] ?? '',
      instapayHandle: data['instapay_handle'] ?? data['instapayHandle'] ?? data['instapay'] ?? '',
      cashBookingEnabled: data['cash_booking_enabled'] ?? data['cashBookingEnabled'] ?? false,
      onlinePaymentEnabled: data['online_payment_enabled'] ?? data['onlinePaymentEnabled'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': '00000000-0000-0000-0000-000000000001',
      'support_phone': supportPhone,
      'whatsapp_number': whatsappNumber,
      'support_email': supportEmail,
      'vodafone_cash_number': vodafoneCashNumber,
      'instapay_handle': instapayHandle,
      'cash_booking_enabled': cashBookingEnabled,
      'online_payment_enabled': onlinePaymentEnabled,
    };
  }
}
