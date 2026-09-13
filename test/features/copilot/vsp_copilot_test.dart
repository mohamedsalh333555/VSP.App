import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/models/copilot_message.dart';
import 'package:vsp_application/core/services/vsp_copilot_service.dart';
import 'package:vsp_application/features/copilot/screens/vsp_copilot_sheet.dart';

class MockVspCopilotService extends VspCopilotService {
  final CopilotMessage Function(String) onSendMessage;

  const MockVspCopilotService(this.onSendMessage);

  @override
  Future<CopilotMessage> sendMessage({
    String? message,
    String? text,
    String? conversationId,
    String? governorate,
  }) async {
    return onSendMessage(message ?? text ?? '');
  }
}

void main() {
  group('VSP Copilot Models Tests', () {
    test('CopilotStadiumSummary fromMap and toMap serialization', () {
      final map = {
        'id': 'std_101',
        'name': 'Camp Nou Cairo',
        'governorate': 'Cairo',
        'price_per_hour': 350.0,
        'image_url': 'https://example.com/stadium.jpg',
        'rating': 4.8,
      };

      final summary = CopilotStadiumSummary.fromMap(map);
      expect(summary.id, 'std_101');
      expect(summary.name, 'Camp Nou Cairo');
      expect(summary.governorate, 'Cairo');
      expect(summary.pricePerHour, 350.0);
      expect(summary.imageUrl, 'https://example.com/stadium.jpg');
      expect(summary.rating, 4.8);

      final exported = summary.toMap();
      expect(exported['id'], 'std_101');
      expect(exported['price_per_hour'], 350.0);
    });

    test('CopilotMessage user and assistant constructors', () {
      final userMsg = CopilotMessage.user('ملاعب المعادي');
      expect(userMsg.isUser, isTrue);
      expect(userMsg.text, 'ملاعب المعادي');
      expect(userMsg.hasStadiums, isFalse);

      final assistantMsg = CopilotMessage.assistant(
        'لقيتلك ملعبين',
        stadiums: [
          const CopilotStadiumSummary(
            id: 'std_1',
            name: 'Wembley',
            governorate: 'Cairo',
            pricePerHour: 400,
          ),
        ],
      );
      expect(assistantMsg.isUser, isFalse);
      expect(assistantMsg.hasStadiums, isTrue);
      expect(assistantMsg.stadiumResults.length, 1);
    });
  });

  group('VspCopilotSheet Widget Tests', () {
    testWidgets('Renders header, quick prompt, and handles sending messages', (tester) async {
      final mockService = MockVspCopilotService((query) {
        if (query.contains('دور لي على ملاعب')) {
          return CopilotMessage.assistant(
            'لقيتلك أفضل الملاعب في القاهرة:',
            stadiums: [
              const CopilotStadiumSummary(
                id: 'std_cairo_1',
                name: 'ملعب النجوم',
                governorate: 'Cairo',
                pricePerHour: 300,
                rating: 4.9,
              ),
            ],
          );
        }
        return CopilotMessage.assistant('رد تجريبي لطلب: $query');
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VspCopilotSheet(
              copilotService: mockService,
              isArabic: true,
            ),
          ),
        ),
      );

      // Verify header and initial greeting
      expect(find.text('كابتن VSP الذكي'), findsOneWidget);
      expect(find.text('دور لي على ملاعب فاضية النهاردة'), findsOneWidget);
      expect(find.textContaining('أهلاً يا كابتن'), findsOneWidget);

      // Tap the single quick prompt chip
      await tester.tap(find.text('دور لي على ملاعب فاضية النهاردة'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify message sent and response received with stadium card
      expect(find.text('دور لي على ملاعب فاضية النهاردة'), findsNWidgets(2)); // in chip & in user bubble
      expect(find.text('لقيتلك أفضل الملاعب في القاهرة:'), findsOneWidget);
      expect(find.text('ملعب النجوم'), findsOneWidget);
      expect(find.text('300 ج.م/ساعة'), findsOneWidget);
      expect(find.text('4.9'), findsOneWidget);
    });
  });
}
