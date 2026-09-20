import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/copilot/services/vsp_copilot_service.dart';
import 'package:vsp_application/features/copilot/widgets/copilot_chat_bubble.dart';
import 'package:vsp_application/data/models/copilot_models.dart';

void main() {
  group('⚽ VSP Copilot v16: Egyptian Sports & Cultural Linguistic Engine Tests', () {
    late VspCopilotService service;

    setUp(() {
      service = const VspCopilotService(enableLocalTestEngine: true);
      service.resetRateLimiter();
    });

    // =========================================================================
    // 1. Ambiguity & Progressive Clarification (Understand -> Clarify -> No Guessing)
    // =========================================================================
    group('🎯 Ambiguity & Progressive Clarification', () {
      test('1. "الجمعة الجاية" without explicit date returns date disambiguation chips (never guesses)', () async {
        final response = await service.sendMessage(
          message: 'احجزلي الجمعة الجاية الساعة 9',
          conversationId: 'disambig_friday_test',
        );

        expect(response.sender, equals('assistant'));
        expect(response.hasClarification, isTrue);
        expect(response.clarification, isNotNull);
        expect(response.clarification!.type, equals('date'));
        expect(response.clarification!.options.length, greaterThanOrEqualTo(2));
        expect(response.clarification!.question, contains('تقصد أنهي'));
        // Confirm no booking was prematurely dispatched
        expect(response.action?.isOpenPayment, isNot(true));
      });

      test('2. "عايز كورة" alone triggers clarification chips (rent ball vs book field)', () async {
        final response = await service.sendMessage(
          message: 'عايز كورة',
          conversationId: 'slang_ball_clarification_test',
        );

        expect(response.sender, equals('assistant'));
        expect(response.hasClarification, isTrue);
        expect(response.clarification, isNotNull);
        expect(response.clarification!.type, equals('ball_intent'));
        expect(response.clarification!.options.length, equals(2));
        expect(response.clarification!.options.any((o) => o.id == 'rent_ball_booking'), isTrue);
        expect(response.clarification!.options.any((o) => o.id == 'book_field'), isTrue);
      });
    });

    // =========================================================================
    // 2. Egyptian Football Lexicon & Context
    // =========================================================================
    group('🧤 Egyptian Football Lexicon', () {
      test('3. "ناقصنا جون بكرة" triggers open match search for goalkeeper (جون)', () async {
        final response = await service.sendMessage(
          message: 'ناقصنا جون بكرة',
          conversationId: 'goalkeeper_search_test',
        );

        expect(response.sender, equals('assistant'));
        expect(response.hasOpenMatches, isTrue);
        expect(response.openMatchResults.isNotEmpty, isTrue);
        expect(response.openMatchResults.first.notes, contains('جون'));
        expect(response.hasAction, isTrue);
        expect(response.action?.route, equals('/matches/open'));
        expect(response.action?.label, contains('حارس'));
      });

      test('4. "عايز كورة" in booking context sets rent_ball = true and does not ask', () async {
        final response = await service.sendMessage(
          message: 'احجزلي ملعب الصداقة بكرة الساعة 8 وكمان عايز كورة',
          conversationId: 'booking_with_ball_test',
        );

        expect(response.sender, equals('assistant'));
        expect(response.text, contains('تأجير كرة'));
        expect(response.hasAction, isTrue);
        expect(response.action?.isOpenPayment, isTrue);
        expect(response.action?.params?['rent_ball'], equals(true));
      });

      test('5. "تثبيتة" / "عايز أثبت ميعاد" explains recurring booking in Egyptian football culture', () async {
        final response = await service.sendMessage(
          message: 'عايز أثبت ميعاد أسبوعي للتقسيمة',
          conversationId: 'fixed_slot_test',
        );

        expect(response.sender, equals('assistant'));
        expect(response.text, contains('تثبيت'));
        expect(response.hasAction, isTrue);
      });
    });

    // =========================================================================
    // 3. Egyptian Temporal Engine & Cairo Timezone
    // =========================================================================
    group('⏰ Egyptian Temporal Engine', () {
      test('6. "12 بليل" maps to midnight 00:00 (12:00 ص)', () async {
        final response = await service.sendMessage(
          message: 'احجزلي 12 بليل في ملعب الصداقة',
          conversationId: 'night_12_test',
        );

        expect(response.text, contains('12:00 ص - 01:00 ص'));
        expect(response.action?.isOpenPayment, isTrue);
      });

      test('7. Late-night "2 بليل" preserves operational session and maps to 02:00 ص', () async {
        final response = await service.sendMessage(
          message: 'احجزلي 2 بليل في ملعب الصداقة',
          conversationId: 'night_2_test',
        );

        expect(response.text, contains('02:00 ص - 03:00 ص'));
        expect(response.action?.isOpenPayment, isTrue);
      });

      test('8. Late-night "3 بليل" maps to 03:00 ص', () async {
        final response = await service.sendMessage(
          message: 'احجزلي 3 بليل في ملعب الصداقة',
          conversationId: 'night_3_test',
        );

        expect(response.text, contains('03:00 ص - 04:00 ص'));
        expect(response.action?.isOpenPayment, isTrue);
      });

      test('9. Prayer Anchor: "بعد العصر" maps to 04:00 م', () async {
        final response = await service.sendMessage(
          message: 'احجزلي بعد العصر في ملعب الصداقة',
          conversationId: 'prayer_asr_test',
        );

        expect(response.text, contains('04:00 م - 05:00 م'));
        expect(response.action?.isOpenPayment, isTrue);
      });

      test('10. Prayer Anchor: "بعد المغرب" maps to 06:00 م', () async {
        final response = await service.sendMessage(
          message: 'احجزلي بعد المغرب في ملعب الصداقة',
          conversationId: 'prayer_maghrib_test',
        );

        expect(response.text, contains('06:00 م - 07:00 م'));
        expect(response.action?.isOpenPayment, isTrue);
      });

      test('11. Prayer Anchor: "بعد العشا" maps to 08:00 م (8:00 مساءً)', () async {
        final response = await service.sendMessage(
          message: 'ماتش بعد العشا في ملعب الصداقة',
          conversationId: 'prayer_isha_test',
        );

        expect(response.text, contains('08:00 م - 09:00 م'));
        expect(response.action?.isOpenPayment, isTrue);
      });
    });

    // =========================================================================
    // 4. Conditional Fallback Engine
    // =========================================================================
    group('🔀 Conditional Fallback Engine', () {
      test('12. "لو مفيش 8 خليه 9" locks preferred slot 8 PM with 9 PM fallback', () async {
        final response = await service.sendMessage(
          message: 'احجزلي ملعب الصداقة ولو مفيش 8 خليه 9',
          conversationId: 'fallback_slot_test',
        );

        expect(response.text, contains('08:00 م - 09:00 م'));
        expect(response.text, contains('09:00 م'));
        expect(response.action?.isOpenPayment, isTrue);
        expect(response.action?.params?['fallback_slots'], contains('21:00'));
      });
    });

    // =========================================================================
    // 5. Model Serialization & Deserialization Tests
    // =========================================================================
    group('📦 Copilot Message & Clarification Schema', () {
      test('13. CopilotClarification and Option serialization round-trip', () {
        const option = CopilotClarificationOption(id: 'opt_1', label: 'الجمعة 25 سبتمبر');
        final optMap = option.toMap();
        expect(optMap['id'], equals('opt_1'));
        expect(optMap['label'], equals('الجمعة 25 سبتمبر'));

        final deserializedOpt = CopilotClarificationOption.fromMap(optMap);
        expect(deserializedOpt.id, equals('opt_1'));
        expect(deserializedOpt.label, equals('الجمعة 25 سبتمبر'));

        const clarification = CopilotClarification(
          type: 'date',
          question: 'تقصد أنهي جمعة يا كابتن؟',
          options: [
            CopilotClarificationOption(id: '2026-09-25', label: 'الجمعة 25 سبتمبر'),
            CopilotClarificationOption(id: '2026-10-02', label: 'الجمعة 2 أكتوبر'),
          ],
        );

        final clarMap = clarification.toMap();
        expect(clarMap['type'], equals('date'));
        expect(clarMap['question'], contains('تقصد'));
        expect((clarMap['options'] as List).length, equals(2));

        final deserializedClar = CopilotClarification.fromMap(clarMap);
        expect(deserializedClar.type, equals('date'));
        expect(deserializedClar.options.length, equals(2));
        expect(deserializedClar.options[0].id, equals('2026-09-25'));
        expect(deserializedClar.options[1].id, equals('2026-10-02'));
      });

      test('14. CopilotMessage with clarification preserves hasClarification getter', () {
        final msg = CopilotMessage(
          id: 'test_msg_1',
          sender: 'assistant',
          text: 'تقصد أنهي جمعة؟',
          timestamp: DateTime(2026, 9, 20, 20, 0),
          clarification: const CopilotClarification(
            type: 'date',
            question: 'تقصد أنهي جمعة؟',
            options: [
              CopilotClarificationOption(id: 'd1', label: 'جمعة 1'),
              CopilotClarificationOption(id: 'd2', label: 'جمعة 2'),
            ],
          ),
        );

        expect(msg.hasClarification, isTrue);
        expect(msg.clarification?.options.length, equals(2));
      });
    });

    // =========================================================================
    // 6. Action Chips UI & Interaction Tests
    // =========================================================================
    group('🎨 Clarification Action Chips Widget Tests', () {
      testWidgets('15. CopilotChatBubble renders clarification chips and handles tap', (tester) async {
        CopilotClarificationOption? tappedOption;

        final msg = CopilotMessage(
          id: 'clar_msg_1',
          sender: 'assistant',
          text: 'تقصد أنهي جمعة يا كابتن؟',
          timestamp: DateTime.now(),
          clarification: const CopilotClarification(
            type: 'date',
            question: 'تقصد أنهي جمعة يا كابتن؟',
            options: [
              CopilotClarificationOption(id: '2026-09-25', label: 'الجمعة 25 سبتمبر'),
              CopilotClarificationOption(id: '2026-10-02', label: 'الجمعة 2 أكتوبر'),
            ],
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CopilotChatBubble(
                message: msg,
                onSelectClarificationOption: (option) => tappedOption = option,
              ),
            ),
          ),
        );

        expect(find.text('الجمعة 25 سبتمبر'), findsOneWidget);
        expect(find.text('الجمعة 2 أكتوبر'), findsOneWidget);

        await tester.tap(find.text('الجمعة 25 سبتمبر'));
        await tester.pumpAndSettle();

        expect(tappedOption, isNotNull);
        expect(tappedOption!.id, equals('2026-09-25'));
        expect(tappedOption!.label, equals('الجمعة 25 سبتمبر'));
      });
    });
  });
}
