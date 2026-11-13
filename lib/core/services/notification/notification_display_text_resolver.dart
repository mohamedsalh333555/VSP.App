import '../../../data/models/notification_models.dart';

/// Canonical text selection for the notification center (also for legacy rows).
class NotificationDisplayTextResolver {
  const NotificationDisplayTextResolver._();

  static String resolve(
    AppNotification notification, {
    required bool isArabic,
    required bool isTitle,
  }) {
    final metadata = notification.metadata ?? const <String, dynamic>{};
    final field = isTitle
        ? (isArabic ? 'title_ar' : 'title_en')
        : (isArabic ? 'body_ar' : 'body_en');
    final localized = metadata[field]?.toString().trim();
    if (localized != null && localized.isNotEmpty) return localized;
    return _localizedLegacyTimeText(
      isTitle ? notification.title : notification.body,
      isArabic: isArabic,
    );
  }

  // Historical notifications have Arabic month/time tokens. Translate only
  // the fixed tokens at display time, never the database's body/message text.
  static String _localizedLegacyTimeText(
    String text, {
    required bool isArabic,
  }) {
    if (isArabic) return text;
    const replacements = <String, String>{
      'يناير': 'Jan',
      'فبراير': 'Feb',
      'مارس': 'Mar',
      'أبريل': 'Apr',
      'مايو': 'May',
      'يونيو': 'Jun',
      'يوليو': 'Jul',
      'أغسطس': 'Aug',
      'سبتمبر': 'Sep',
      'أكتوبر': 'Oct',
      'نوفمبر': 'Nov',
      'ديسمبر': 'Dec',
      ' م': ' PM',
      ' ص': ' AM',
      'مـ': 'PM',
      'صـ': 'AM',
    };
    var result = text;
    replacements.forEach((from, to) {
      result = result.replaceAll(from, to);
    });
    return result;
  }
}
