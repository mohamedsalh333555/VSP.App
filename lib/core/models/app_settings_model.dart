class AppSettings {
  final String supportPhone;
  final String whatsappNumber;
  final String supportEmail;
  final String vodafoneCashNumber;
  final String instapayHandle;
  final bool cashBookingEnabled;
  final bool onlinePaymentEnabled;

  const AppSettings({
    this.supportPhone = '01100229462',
    this.whatsappNumber = '+201100229462',
    this.supportEmail = 'support@vspapp.com',
    this.vodafoneCashNumber = '01100229462',
    this.instapayHandle = 'vsp@instapay',
    this.cashBookingEnabled = true,
    this.onlinePaymentEnabled = true,
  });

  factory AppSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const AppSettings();
    return AppSettings(
      supportPhone: data['support_phone'] ?? data['supportPhone'] ?? '01100229462',
      whatsappNumber: data['whatsapp_number'] ?? data['whatsappNumber'] ?? '+201100229462',
      supportEmail: data['support_email'] ?? data['supportEmail'] ?? 'support@vspapp.com',
      vodafoneCashNumber: data['vodafone_cash_number'] ?? data['vodafoneCashNumber'] ?? data['vodafone_cash'] ?? '01100229462',
      instapayHandle: data['instapay_handle'] ?? data['instapayHandle'] ?? data['instapay'] ?? 'vsp@instapay',
      cashBookingEnabled: data['cash_booking_enabled'] ?? data['cashBookingEnabled'] ?? true,
      onlinePaymentEnabled: data['online_payment_enabled'] ?? data['onlinePaymentEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
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
