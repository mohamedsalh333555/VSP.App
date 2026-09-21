import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/services/vsp_copilot_service.dart';

void main() {
  group('🏟️ VSP Copilot - اختبار ذكاء مالك الملعب، النزاهة التامة ورفض ما هو خارج التطبيق', () {
    late VspCopilotService service;

    setUp(() {
      service = const VspCopilotService(enableLocalTestEngine: true);
      service.resetRateLimiter();
    });

    // =========================================================================
    // 1️⃣ اختبار استرجاع بيانات الملاعب الحقيقية من قاعدة البيانات دون تأليف
    // =========================================================================
    group('📊 1. ربط قاعدة البيانات الحقيقية لملاعب المالك (Zero-Hallucination Stadiums)', () {
      test('عندما يكون للمالك ملاعب مسجلة في قاعدة البيانات، يعرضها بدقة تامة وبنفس الأسعار والأسماء', () async {
        final realDatabaseStadiums = [
          {
            'id': 'stadium-cairo-1',
            'name': 'ستاد الأبطال الدولي بالتجمع',
            'governorate': 'القاهرة',
            'price_per_hour': 450,
          },
          {
            'id': 'stadium-giza-2',
            'name': 'ملعب الفرسان الخماسي بالمهندسين',
            'governorate': 'الجيزة',
            'price_per_hour': 380,
          },
        ];

        final ownerService = VspCopilotService(
          mockOwnerDb: OwnerDatabaseMockData(
            stadiums: realDatabaseStadiums,
          ),
        );

        final response = await ownerService.sendMessage(
          message: 'وريني ملاعبي المسجلة في التطبيق',
        );

        // التحقق من أن الرد يحتوي على نفس الملاعب من الداتابيز حرفياً
        expect(response.message, contains('ستاد الأبطال الدولي بالتجمع'));
        expect(response.message, contains('450 ج.م/ساعة'));
        expect(response.message, contains('ملعب الفرسان الخماسي بالمهندسين'));
        expect(response.message, contains('380 ج.م/ساعة'));

        // التحقق من أنه لا يؤلف ملاعب وهمية من عنده
        expect(response.message, isNot(contains('ملعب السلام الخيالي')));
        expect(response.message, isNot(contains('ملعب النجوم الوهمي')));
        expect(response.action?.route, equals('/bookings'));
      });

      test('عندما لا يمتلك المالك أي ملاعب (0 ملاعب في قاعدة البيانات)، يخبره بأمانة ولا يخترع ملاعب وهمية', () async {
        const emptyOwnerService = VspCopilotService(
          mockOwnerDb: OwnerDatabaseMockData(
            stadiums: [], // قاعدة البيانات خالية
          ),
        );

        final response = await emptyOwnerService.sendMessage(
          message: 'ايه هي الملاعب المسجلة باسمي؟',
        );

        // التحقق من الشفافية والصدق مع الداتابيز
        expect(response.message, contains('راجعت قاعدة بيانات VSP ولم أجد أي ملاعب مسجلة باسمك حالياً'));
        expect(response.message, isNot(contains('ملعب النجوم')));
        expect(response.action?.route, equals('/add-stadium'));
        expect(response.action?.label, contains('إضافة ملعب'));
      });
    });

    // =========================================================================
    // 2️⃣ اختبار استرجاع السجل المالي والأرباح الحقيقية من RPC داتابيز
    // =========================================================================
    group('💰 2. استرجاع الأرباح والرصيد الحقيقي من داتابيز get_owner_financial_summary', () {
      test('يعرض الأرقام الدقيقة للرصيد المتاح والكاش والأونلاين المسجلة في قاعدة البيانات', () async {
        final realFinancialRecord = {
          'available_balance': 8750,
          'cash_revenue': 3200,
          'total_online_revenue': 5550,
          'total_completed_bookings': 18,
          'accumulated_cash_debt': 480,
        };

        final ownerService = VspCopilotService(
          mockOwnerDb: OwnerDatabaseMockData(
            financialSummary: realFinancialRecord,
          ),
        );

        final response = await ownerService.sendMessage(
          message: 'عايز اعرف أرباحي ورصيدي المتاح في السجل المالي كام؟',
        );

        // التحقق من تطابق الأرقام بدقة بالغة مع قيم الداتابيز
        expect(response.message, contains('8750 ج.م'));
        expect(response.message, contains('3200 ج.م'));
        expect(response.message, contains('5550 ج.م'));
        expect(response.message, contains('18'));

        // التأكد من عدم تأليف أي أرقام عشوائية
        expect(response.message, isNot(contains('10000 ج.م')));
        expect(response.message, isNot(contains('50000 ج.م')));
        expect(response.action?.route, equals('/ledger'));
        expect(response.action?.label, contains('السجل المالي'));
      });

      test('عندما يكون الحساب المالي جديداً (0 أرباح في الداتابيز)، يذكر 0 بدقة دون تجميل أو اختلاق', () async {
        final emptyFinancialRecord = {
          'available_balance': 0,
          'cash_revenue': 0,
          'total_online_revenue': 0,
          'total_completed_bookings': 0,
        };

        final ownerService = VspCopilotService(
          mockOwnerDb: OwnerDatabaseMockData(
            financialSummary: emptyFinancialRecord,
          ),
        );

        final response = await ownerService.sendMessage(
          message: 'فلوسي وأرباحي كمالك كام النهاردة؟',
        );

        expect(response.message, contains('الرصيد الإلكتروني المتاح للسحب: 0 ج.م'));
        expect(response.message, contains('إجمالي الكاش المحصل بالملعب: 0 ج.م'));
        expect(response.message, contains('عدد الحجوزات المكتملة: 0'));
      });
    });

    // =========================================================================
    // 3️⃣ اختبار استرجاع حجوزات ملاعب المالك الحقيقية
    // =========================================================================
    group('📅 3. استرجاع حجوزات الملاعب الحقيقية من جدول bookings', () {
      test('يعرض الحجوزات الفعلية المسجلة لملاعب المالك مع أوقاتها وأسعارها', () async {
        final realBookings = [
          {
            'id': 'booking-101',
            'stadium_name': 'ستاد الأبطال الدولي بالتجمع',
            'start_time': '2026-09-17 20:00',
            'status': 'confirmed',
            'total_price': 450,
          },
          {
            'id': 'booking-102',
            'stadium_name': 'ملعب الفرسان الخماسي بالمهندسين',
            'start_time': '2026-09-17 21:00',
            'status': 'pending',
            'total_price': 380,
          },
        ];

        final ownerService = VspCopilotService(
          mockOwnerDb: OwnerDatabaseMockData(
            bookings: realBookings,
          ),
        );

        final response = await ownerService.sendMessage(
          message: 'مين حاجز في ملاعبي؟ وريني الحجوزات الحالية',
        );

        expect(response.message, contains('ستاد الأبطال الدولي بالتجمع'));
        expect(response.message, contains('20:00'));
        expect(response.message, contains('450 ج.م'));
        expect(response.message, contains('ملعب الفرسان الخماسي بالمهندسين'));
        expect(response.message, contains('380 ج.م'));
        expect(response.action?.route, equals('/bookings'));
      });

      test('عند عدم وجود حجوزات في الداتابيز، يصرح بذلك بوضوح تام دون اختلاق حجز وهمي', () async {
        const emptyBookingsService = VspCopilotService(
          mockOwnerDb: OwnerDatabaseMockData(
            bookings: [],
          ),
        );

        final response = await emptyBookingsService.sendMessage(
          message: 'هل فيه أي حجز معلق في ملعبي؟',
        );

        expect(response.message, contains('لا توجد حجوزات مسجلة لملاعبك حالياً في قاعدة البيانات'));
        expect(response.action?.route, equals('/bookings'));
      });
    });

    // =========================================================================
    // 4️⃣ اختبار باقة الـ 1000 جنيه (الباقة الاحترافية PRO لمالك الملعب)
    // =========================================================================
    group('👑 4. استفسارات باقة 1000 جنيه الاحترافية لمالكي الملاعب', () {
      test('يشرح بدقة مميزات باقة الـ 1000 جنيه التي تتضمن مساعد الذكاء الاصطناعي حصرياً', () async {
        final response = await service.sendMessage(
          message: 'ايه هي مميزات باقة 1000 جنيه لمالك الملعب؟',
        );

        expect(response.message, contains('1000 ج.م'));
        expect(response.message, contains('الباقة الاحترافية (PRO)'));
        expect(response.message, contains('مساعد الذكاء الاصطناعي VSP Copilot'));
        expect(response.message, contains('3 ملاعب'));
        expect(response.message, contains('واتساب'));
        expect(response.message, contains('السجل المالي'));
        expect(response.action?.route, equals('/subscription-plans'));
      });
    });

    // =========================================================================
    // 5️⃣ 🛡️ اختبار القواعد الصارمة لرفض الأسئلة الخارجة عن نطاق تطبيق VSP
    // =========================================================================
    group('🚫 5. القواعد الصارمة: رفض أي أسئلة لا تخص التطبيق وملاعب مصر', () {
      const expectedRefusal =
          'عذراً يا كابتن! أنا "كابتن VSP"، مساعدك الرياضي المتخصص فقط في تطبيق VSP لحجز وإدارة الملاعب والبطولات في مصر ⚽. مقدرش أساعدك غير في اللي يخص ملاعبك وحجوزاتك وخدمات التطبيق يا بطل!';

      test('رفض وصفات الطعام والطبخ (كشري، شاورما، مقادير كيكة، ملوخية)', () async {
        final cookingQuestions = [
          'طريقة عمل الكشري المصري بالصلصة والدقة؟',
          'عايز وصفة شاورما فراخ سريعة',
          'ايه مقادير كيكة الشوكولاتة في البيت؟',
          'علمني طبخ طاجن ملوخية باللحمة',
          'ايه أحسن أكلة سريعة ممكن أعملها؟',
        ];

        for (final q in cookingQuestions) {
          final response = await service.sendMessage(message: q);
          expect(response.message, equals(expectedRefusal), reason: 'فشل في رفض سؤال الطبخ: $q');
          expect(response.stadiums, isEmpty);
        }
      });

      test('رفض كتابة الأكواد والبرمجة العامة غير المرتبطة بالتطبيق (Python, Javascript, إلخ)', () async {
        final codingQuestions = [
          'اكتبلي كود بايثون لحساب الأرقام الأولية',
          'Write Python script to parse website data',
          'علمني لغة برمجة جافاسكريبت',
          'عايز مبرمج شاطر يعملي موقع شخصي',
        ];

        for (final q in codingQuestions) {
          final response = await service.sendMessage(message: q);
          expect(response.message, equals(expectedRefusal), reason: 'فشل في رفض سؤال البرمجة: $q');
        }
      });

      test('رفض السياسة والانتخابات والحروب والأخبار العامة', () async {
        final politicsQuestions = [
          'مين رئيس فرنسا الحالي؟',
          'ايه توقعاتك لانتخابات مجلس الشعب والبرلمان القادمة؟',
          'ما هي أسباب حرب روسيا وأوكرانيا؟',
          'رأيك ايه في قرارات الوزير والحكومة الأخيرة؟',
        ];

        for (final q in politicsQuestions) {
          final response = await service.sendMessage(message: q);
          expect(response.message, equals(expectedRefusal), reason: 'فشل في رفض سؤال السياسة: $q');
        }
      });

      test('رفض العلوم المعقدة والفيزياء والكيمياء والفلسفة والمعادلات', () async {
        final scienceQuestions = [
          'اشرحلي النظرية النسبية لأينشتاين بالتفصيل',
          'حل معادلة تفاضلية وتكامل رياضي',
          'ايه هي قوانين نيوتن للحركة في الفيزياء؟',
          'ما هو مفهوم الفلسفة الوجودية؟',
          'تفاعلات الذرة في الكيمياء العضوية',
        ];

        for (final q in scienceQuestions) {
          final response = await service.sendMessage(message: q);
          expect(response.message, equals(expectedRefusal), reason: 'فشل في رفض سؤال العلوم: $q');
        }
      });

      test('رفض الأفلام والمسلسلات والأغاني والترفيه العام', () async {
        final entertainmentQuestions = [
          'ايه احسن فيلم رعب نزل السنة دي في السينما؟',
          'مين أبطال مسلسل جعفر العمدة؟',
          'كلمات أغنية تملي معاك لعمرو دياب',
          'رشحلي مسلسلات أكشن حلوة اتفرج عليها',
        ];

        for (final q in entertainmentQuestions) {
          final response = await service.sendMessage(message: q);
          expect(response.message, equals(expectedRefusal), reason: 'فشل في رفض سؤال الفن والترفيه: $q');
        }
      });

      test('رفض أسئلة الطقس والسيارات والبورصة والأدوية العامة', () async {
        final generalOffTopicQuestions = [
          'الطقس ودرجة الحرارة في القاهرة بكرة عاملة ايه؟',
          'قولي نكتة مضحكة وفزورة جديدة',
          'عايز اشتري عربية مرسيدس تنصحني بايه؟',
          'سعر عملة بيتكوين crypto والبورصة النهاردة كام؟',
          'ايه أفضل علاج ودواء للصداع المزمن؟',
        ];

        for (final q in generalOffTopicQuestions) {
          final response = await service.sendMessage(message: q);
          expect(response.message, equals(expectedRefusal), reason: 'فشل في رفض سؤال خارج النطاق: $q');
        }
      });
    });

    // =========================================================================
    // 6️⃣ اختبار معالجة وتحويل استجابة Supabase Cloud Edge Function الحقيقية
    // =========================================================================
    group('☁️ 6. اختبار دقة تحويل استجابة Edge Function السحابية', () {
      test('يتعامل مع الاستجابة الصادرة من Edge Function بدقة دون فقدان أي حقل', () async {
        final cloudEdgeResponseData = {
          'message': 'يا كابتن! دي ملاعبك المسجلة رسمياً في قاعدة بيانات VSP:',
          'conversation_id': 'conv_cloud_8899',
          'action': {
            'action_type': 'NAVIGATE',
            'route': '/bookings',
            'label': 'جدول الحجوزات 📅',
          },
          'stadiums': [
            {
              'id': 'std-99',
              'name': 'ملعب الجوهرة الدولية',
              'governorate': 'القاهرة',
              'price_per_hour': 400,
              'surface': 'ترتان',
              'rating': 4.9,
            }
          ],
        };

        // فحص عمل دالة البارسر السحابي
        final message = service.parseCloudResponse(
          cloudEdgeResponseData,
          'conv_cloud_8899',
        );

        expect(message.message, contains('ملاعبك المسجلة'));
        expect(message.conversationId, equals('conv_cloud_8899'));
        expect(message.action?.route, equals('/bookings'));
        expect(message.stadiums.length, equals(1));
        expect(message.stadiums.first.name, equals('ملعب الجوهرة الدولية'));
        expect(message.stadiums.first.pricePerHour, equals(400));
      });
    });
  });
}
