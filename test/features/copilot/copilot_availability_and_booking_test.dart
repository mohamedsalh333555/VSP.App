import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/services/vsp_copilot_service.dart';

void main() {
  group('🤖 VSP Copilot - Real Availability & In-Chat Booking Tests', () {
    late VspCopilotService service;

    setUp(() {
      service = const VspCopilotService(enableLocalTestEngine: true);
      service.resetRateLimiter();
    });

    // =========================================================================
    // 1. فحص التوافر الحقيقي ومواعيد الملاعب (Real Stadium Availability Engine)
    // =========================================================================
    test('1. استعلام توافر المواعيد لملعب محدد يرجع الساعات الشاغرة بدقة', () async {
      final response = await service.sendMessage(
        message: 'هل ملعب الأبطال متاح بكرة الساعة 8 بالليل؟',
        conversationId: 'avail_test_1',
      );

      expect(response.sender, equals('assistant'));
      expect(response.text, contains('جدول مواعيد'));
      expect(response.text, contains('الفترات المتاحة'));
      expect(response.text, contains('08:00 م - 09:00 م'));
      expect(response.hasStadiums, isTrue);
      expect(response.stadiums.first.name, contains('الأبطال'));
      expect(response.hasAction, isTrue);
      expect(response.action?.route, contains('/stadium/'));
    });

    test('2. استعلام مواعيد ملعب الصداقة يرجع الفترات المفتوحة وسعر الساعة الحقيقي', () async {
      final response = await service.sendMessage(
        message: 'عايز أعرف الفترات المتاحة في ملعب الصداقة الجديدة',
        conversationId: 'avail_test_2',
      );

      expect(response.text, contains('ملعب الصداقة الجديدة'));
      expect(response.text, contains('200 ج.م'));
      expect(response.text, contains('08:00 م - 09:00 م'));
      expect(response.stadiums.first.pricePerHour, equals(200.0));
    });

    // =========================================================================
    // 2. الحجز المباشر من داخل الشات وتوليد OPEN_PAYMENT (In-Chat Booking Dispatch)
    // =========================================================================
    test('3. طلب الحجز المباشر من الشات يولد إجراء OPEN_PAYMENT إلى /checkout مع العربون', () async {
      final convId = 'booking_dispatch_conv_${DateTime.now().millisecondsSinceEpoch}';

      // الخطوة 1: فحص التوافر لملعب معين
      await service.sendMessage(
        message: 'هل في مواعيد في ملعب الأبطال بالدقي؟',
        conversationId: convId,
      );

      // الخطوة 2: طلب الحجز المباشر
      final bookResponse = await service.sendMessage(
        message: 'احجزلي الميعاد ده',
        conversationId: convId,
      );

      expect(bookResponse.sender, equals('assistant'));
      expect(bookResponse.text, contains('تم قفل موعدك بنجاح'));
      expect(bookResponse.text, contains('دفع العربون'));
      expect(bookResponse.hasAction, isTrue);

      final action = bookResponse.action!;
      expect(action.actionType, equals('OPEN_PAYMENT'));
      expect(action.isOpenPayment, isTrue);
      expect(action.route, equals('/checkout'));
      expect(action.params, isNotNull);
      expect(action.params!['booking_id'], isNotNull);
      expect(action.params!['deposit_amount'], equals(50.0));
      expect(action.label, contains('دفع العربون'));
    });

    test('4. طلب "احجز الساعة 8" مباشرة يولد إجراء الدفع مع حجز الموعد', () async {
      final response = await service.sendMessage(
        message: 'احجز الساعة 8 في ملعب النجوم بالمعادي',
        conversationId: 'direct_book_test_4',
      );

      expect(response.hasAction, isTrue);
      expect(response.action?.isOpenPayment, isTrue);
      expect(response.action?.route, equals('/checkout'));
      expect(response.text, contains('5 دقائق'));
    });

    // =========================================================================
    // 3. ذاكرة الجلسة التراكمية (Multi-Turn State Machine & Context Snapshot)
    // =========================================================================
    test('5. تذكر الملعب والموعد عبر الأدوار المتعددة دون تكرار اسم الملعب', () async {
      final convId = 'multi_turn_booking_${DateTime.now().millisecondsSinceEpoch}';

      // دور 1: السؤال عن الملعب
      final turn1 = await service.sendMessage(
        message: 'عايز ملعب في زايد',
        conversationId: convId,
      );
      expect(turn1.stadiums, isNotEmpty);

      // دور 2: فحص المواعيد بدون ذكر الاسم
      final turn2 = await service.sendMessage(
        message: 'إيه المواعيد المتاحة بكرة؟',
        conversationId: convId,
      );
      expect(turn2.text, contains('الفترات المتاحة'));

      // دور 3: الحجز الفوري
      final turn3 = await service.sendMessage(
        message: 'تمام، أكد الحجز',
        conversationId: convId,
      );
      expect(turn3.action?.isOpenPayment, isTrue);
      expect(turn3.action?.route, equals('/checkout'));
    });

    // =========================================================================
    // 4. اختبار فك ومعالجة استجابة السحابة (Cloud Payload Parser for OPEN_PAYMENT)
    // =========================================================================
    test('6. parseCloudResponse يفك شفرة إجراء OPEN_PAYMENT ومعلماته بشكل صحيح', () {
      final cloudPayload = {
        'conversation_id': 'cloud_conv_123',
        'message': 'تم قفل موعدك بنجاح! يرجى إتمام العربون لتأكيد الحجز.',
        'stadiums': [
          {
            'id': 'std_100',
            'name': 'ملعب الأبطال',
            'governorate': 'الجيزة',
            'price_per_hour': 250,
            'image_url': 'https://example.com/stadium.jpg',
            'rating': 4.8,
          }
        ],
        'action': {
          'action_type': 'OPEN_PAYMENT',
          'route': '/checkout',
          'label': 'إتمام دفع العربون (50 ج.م) وتأكيد الحجز 💳',
          'params': {
            'booking_id': 'book_9999',
            'stadium_id': 'std_100',
            'deposit_amount': 50.0,
            'total_price': 250.0,
          },
        },
      };

      final parsedMessage = service.parseCloudResponse(cloudPayload, 'cloud_conv_123');

      expect(parsedMessage.conversationId, equals('cloud_conv_123'));
      expect(parsedMessage.hasStadiums, isTrue);
      expect(parsedMessage.hasAction, isTrue);

      final action = parsedMessage.action!;
      expect(action.isOpenPayment, isTrue);
      expect(action.actionType, equals('OPEN_PAYMENT'));
      expect(action.route, equals('/checkout'));
      expect(action.params?['booking_id'], equals('book_9999'));
      expect(action.params?['deposit_amount'], equals(50.0));
      expect(action.params?['total_price'], equals(250.0));
    });
  });
}
