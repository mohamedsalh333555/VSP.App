import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models/notification_models.dart';
import 'package:vsp_application/core/services/notification/notification_display_text_resolver.dart';

void main() {
  test('legacy message displays in both locales without mutating the source', () {
    final raw = <String, dynamic>{
      'id': 'old-message',
      'title': 'إشعار المباراة',
      'message': 'موعد المباراة الجديد',
      'created_at': '2026-11-13T10:00:00Z',
    };
    final notification = AppNotification.fromMap(raw);
    for (final isArabic in [true, false]) {
      expect(
        NotificationDisplayTextResolver.resolve(
          notification, isArabic: isArabic, isTitle: false,
        ),
        'موعد المباراة الجديد',
      );
    }
    expect(raw.containsKey('body'), isFalse);
    expect(notification.toFirestore()['body'], 'موعد المباراة الجديد');
  });

  test('canonical body outranks legacy alias and localized metadata wins', () {
    final notification = AppNotification.fromMap({
      'id': 'mixed',
      'title': 'Original title',
      'body': 'Canonical body',
      'message': 'Old alias',
      'metadata': {
        'title_ar': 'عنوان عربي',
        'body_ar': 'رسالة عربية',
        'title_en': 'English title',
        'body_en': 'English body',
      },
    });
    expect(
      NotificationDisplayTextResolver.resolve(
        notification, isArabic: true, isTitle: false,
      ),
      'رسالة عربية',
    );
    expect(
      NotificationDisplayTextResolver.resolve(
        notification, isArabic: false, isTitle: true,
      ),
      'English title',
    );
    expect(notification.body, 'Canonical body');
  });

  test('empty localized field still renders legacy fallback', () {
    final notification = AppNotification.fromMap({
      'id': 'blank',
      'title': 'Match',
      'body': ' ',
      'message': 'Fallback message',
      'metadata': {'body_ar': '   ', 'body_en': ''},
    });
    expect(
      NotificationDisplayTextResolver.resolve(
        notification, isArabic: true, isTitle: false,
      ),
      'Fallback message',
    );
    expect(
      NotificationDisplayTextResolver.resolve(
        notification, isArabic: false, isTitle: false,
      ),
      'Fallback message',
    );
  });

  testWidgets('synthetic legacy notification renders real Flutter Text', (tester) async {
    final notification = AppNotification.fromMap({
      'id': 'legacy-render',
      'title': 'Old template',
      'message': 'Visible legacy body',
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Text(NotificationDisplayTextResolver.resolve(
          notification, isArabic: false, isTitle: false,
        )),
      ),
    ));
    expect(find.text('Visible legacy body'), findsOneWidget);
  });

  test('historical month/time tokens are localized without persisting changes', () {
    final notification = AppNotification.fromMap({
      'id': 'arabic-month',
      'title': 'التحدي 13 نوفمبر 5 م',
    });
    expect(
      NotificationDisplayTextResolver.resolve(
        notification, isArabic: false, isTitle: true,
      ),
      'التحدي 13 Nov 5 PM',
    );
    expect(
      NotificationDisplayTextResolver.resolve(
        notification, isArabic: true, isTitle: true,
      ),
      'التحدي 13 نوفمبر 5 م',
    );
  });
}
