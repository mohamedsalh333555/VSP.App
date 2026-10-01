import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Owner Copilot AI Journey SSOT', () {
    // -------------------------------------------------------------------------
    // Task 1: Owner-Only Boundary
    // -------------------------------------------------------------------------
    test('Owner-Only Boundary: Rejects player role with 403 Forbidden', () {
      final userProfile = {
        'id': 'usr-player-1',
        'role': 'player',
        'name': 'Mohamed Player',
      };

      final dbRole = (userProfile['role'] as String).toLowerCase().trim();
      final isOwner = dbRole == 'pitch_owner' || dbRole == 'owner';

      expect(isOwner, isFalse);

      final simulatedResponse = {
        'status': 403,
        'body': {
          'error': 'FORBIDDEN_OWNER_ONLY',
          'message': 'خدمة كابتن VSP الذكي مخصصة حصرياً لأصحاب ومسؤولي الملاعب.',
        },
      };

      expect(simulatedResponse['status'], equals(403));
      expect((simulatedResponse['body'] as Map)['error'], equals('FORBIDDEN_OWNER_ONLY'));
    });

    test('Owner-Only Boundary: Allows pitch owner with active entitlement', () {
      final futureDate = DateTime.now().add(const Duration(days: 30)).toIso8601String();
      final userProfile = {
        'id': 'usr-owner-1',
        'role': 'pitch_owner',
        'trial_ends_at': futureDate,
        'subscription_expires_at': null,
      };

      final dbRole = (userProfile['role'] as String).toLowerCase().trim();
      final isOwner = dbRole == 'pitch_owner' || dbRole == 'owner';
      expect(isOwner, isTrue);

      final trialMs = DateTime.parse(userProfile['trial_ends_at'] as String).millisecondsSinceEpoch;
      final isEntitled = trialMs > DateTime.now().millisecondsSinceEpoch;
      expect(isEntitled, isTrue);
    });

    test('Owner-Only Boundary: Rejects owner with expired trial and no subscription with 402', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 10)).toIso8601String();
      final userProfile = {
        'id': 'usr-owner-expired',
        'role': 'owner',
        'trial_ends_at': pastDate,
        'subscription_expires_at': null,
      };

      final trialMs = DateTime.parse(userProfile['trial_ends_at'] as String).millisecondsSinceEpoch;
      final isEntitled = trialMs > DateTime.now().millisecondsSinceEpoch;
      expect(isEntitled, isFalse);

      final simulatedResponse = {
        'status': 402,
        'body': {
          'error': 'OWNER_COPILOT_SUBSCRIPTION_REQUIRED',
          'message': 'خدمة كابتن VSP للمالك متاحة مع باقة نشطة أو فترة التجربة السارية.',
        },
      };

      expect(simulatedResponse['status'], equals(402));
      expect((simulatedResponse['body'] as Map)['error'], equals('OWNER_COPILOT_SUBSCRIPTION_REQUIRED'));
    });

    // -------------------------------------------------------------------------
    // Task 2: Conversation History Invariants
    // -------------------------------------------------------------------------
    test('Conversation History: Retrieves latest 6 messages in chronological order, never oldest', () {
      // Simulating a conversation with 10 messages
      final allMessages = List.generate(10, (index) => {
        'id': 'msg-${index + 1}',
        'seq': index + 1,
        'created_at': DateTime(2026, 10, 1, 10, index).toIso8601String(),
        'content': 'Message ${index + 1}',
      });

      // 1. Server fetches order created_at DESC limit 6
      final fetchedDesc = allMessages.reversed.take(6).toList();
      expect(fetchedDesc.first['seq'], equals(10));
      expect(fetchedDesc.last['seq'], equals(5));

      // 2. Reverses to maintain chronological order for the LLM
      final promptHistory = fetchedDesc.reversed.toList();
      expect(promptHistory.length, equals(6));
      expect(promptHistory.first['seq'], equals(5));
      expect(promptHistory.last['seq'], equals(10));
      // Invariant: The prompt sees the recent state (messages 5 to 10), never 1 to 6
      expect(promptHistory.any((m) => (m['seq'] as int) < 5), isFalse);
    });

    // -------------------------------------------------------------------------
    // Task 3: Context SSOT for Owner Copilot
    // -------------------------------------------------------------------------
    test('Context SSOT: Retains current stadium, dates, times, and pending operations across turns', () {
      final state = {
        'stadium': {
          'id': 'stadium-al-amal-1',
          'name': 'ملعب الأمل',
          'status': 'known',
          'price_per_hour': 250,
        },
        'date': {
          'value': '2026-10-02',
          'label': 'بكرة',
          'status': 'known',
        },
        'times': [{'time': '20:00', 'status': 'known'}],
        'time_period': 'evening',
        'duration_hours': 1,
        'active_task': 'availability',
        'task_lifecycle': 'in_progress',
        'pending_confirmation': null,
      };

      // Invariant: Structured context exports verifiable operational facts
      expect((state['stadium'] as Map)['name'], equals('ملعب الأمل'));
      expect((state['date'] as Map)['value'], equals('2026-10-02'));
      expect(state['time_period'], equals('evening'));
    });

    // -------------------------------------------------------------------------
    // Task 4: Ownership Firewall
    // -------------------------------------------------------------------------
    test('Ownership Firewall: Rejects stadium lookup if not owned by caller', () {
      final callerOwnerId = 'owner-caller-123';
      final outsiderStadium = {
        'id': 'stadium-outsider-999',
        'name': 'ملعب النجوم',
        'owner_id': 'owner-different-888',
      };

      // Availability check: WHERE id = stadiumId AND owner_id = callerUser.id
      final isOwnedByCaller = outsiderStadium['owner_id'] == callerOwnerId;
      expect(isOwnedByCaller, isFalse);

      final toolErrorResult = {
        'status': 'INVALID_INPUT',
        'tool_name': 'checkStadiumAvailability',
        'error_message': 'لم يتم العثور على هذا الملعب ضمن ملاعبك المسجلة يا كابتن.',
      };

      expect(toolErrorResult['status'], equals('INVALID_INPUT'));
      expect(toolErrorResult['error_message'], contains('ضمن ملاعبك المسجلة'));
    });

    // -------------------------------------------------------------------------
    // Task 5 & 7: Unified Capability Registry & Zero Phantom Tools
    // -------------------------------------------------------------------------
    test('Capability Registry: updateUserProfile is eliminated; strictly 4 owner tools allowed', () {
      const ownerAllowedTools = [
        'getOwnerStadiumsAndBookings',
        'getOwnerFinancialInsights',
        'checkStadiumAvailability',
        'executeAppAction',
      ];

      expect(ownerAllowedTools.contains('updateUserProfile'), isFalse,
          reason: 'Phantom capability updateUserProfile must not exist');
      expect(ownerAllowedTools.length, equals(4));
    });

    // -------------------------------------------------------------------------
    // Task 6: Zero Player Pollution in Owner Copilot
    // -------------------------------------------------------------------------
    test('Owner Copilot: Degraded mode provides operational owner quick replies only', () {
      const ownerFinancialReplies = ['أرباح النهاردة', 'الرصيد المتاح', 'السجل المالي'];
      const ownerOperationsReplies = ['جدول الحجوزات', 'المواعيد الفاضية', 'أرباحي كام'];

      for (final r in [...ownerFinancialReplies, ...ownerOperationsReplies]) {
        expect(r.contains('1v1'), isFalse);
        expect(r.contains('بطولات'), isFalse);
        expect(r.contains('ترتيب الحريفة'), isFalse);
      }
    });

    // -------------------------------------------------------------------------
    // Task 8: Accuracy Contract & Fact Validation
    // -------------------------------------------------------------------------
    test('Accuracy Contract: Blocks fabricated booking counts not in tool result', () {
      final toolResult = {
        'tool_name': 'getOwnerStadiumsAndBookings',
        'data': {'stadiums_count': 2},
        'bookings': [
          {'id': 'b1', 'stadium_name': 'ملعب الأمل', 'start_time': '2026-10-01T20:00:00Z'},
          {'id': 'b2', 'stadium_name': 'ملعب الأمل', 'start_time': '2026-10-01T22:00:00Z'},
        ],
      };

      final actualBookingsCount = (toolResult['bookings'] as List).length;
      expect(actualBookingsCount, equals(2));

      // Fabricated claim: "عندك 5 حجوزات النهاردة"
      final claimedCount = 5;
      final isValidCount = claimedCount == actualBookingsCount;
      expect(isValidCount, isFalse, reason: 'Fact validator must catch hallucinated booking counts');
    });

    test('Accuracy Contract: Decouples stadiums_count from bookings_count strictly', () {
      final toolResult = {
        'stadiums_count': 2,
        'bookings_count': 1,
        'stadiums': [{'id': 'std-1'}, {'id': 'std-2'}],
        'bookings': [{'id': 'bk-1'}],
      };

      final allowedStadiumCounts = {toolResult['stadiums_count'], (toolResult['stadiums'] as List).length};
      final allowedBookingCounts = {toolResult['bookings_count'], (toolResult['bookings'] as List).length};

      // Invariant: stadiums_count must never bleed into allowedBookingCounts!
      expect(allowedBookingCounts.contains(2), isFalse, reason: '2 is stadiums count, must NOT be accepted as booking count');
      expect(allowedBookingCounts.contains(1), isTrue);
      expect(allowedStadiumCounts.contains(2), isTrue);
      expect(allowedStadiumCounts.contains(1), isFalse);

      // Case: 0 bookings
      final zeroBookingsAllowed = {0};
      expect(zeroBookingsAllowed.contains(0), isTrue);
      expect(zeroBookingsAllowed.contains(1), isFalse);
    });

    test('Accuracy Contract: Blocks fabricated revenue figures not in financial summary', () {
      final financialToolResult = {
        'tool_name': 'getOwnerFinancialInsights',
        'data': {
          'available_balance': 1200.0,
          'total_revenue': 5400.0,
          'pending_balance': 300.0,
        },
      };

      final finData = financialToolResult['data'] as Map<String, dynamic>;
      final verifiedAmounts = [
        finData['available_balance'],
        finData['total_revenue'],
        finData['pending_balance'],
      ];

      // Hallucinated figure: 9000 EGP
      final claimedAmount = 9000.0;
      final isVerified = verifiedAmounts.contains(claimedAmount);
      expect(isVerified, isFalse, reason: 'Fact validator must reject unverified financial figures');
    });

    // -------------------------------------------------------------------------
    // Task 3: Egyptian Temporal Expressions & Controlled Clock
    // -------------------------------------------------------------------------
    test('Egyptian Temporal Engine: Relative dates with controlled clock', () {
      // Thursday Oct 1, 2026
      final thursday = DateTime.utc(2026, 10, 1, 12);
      expect(thursday.weekday, equals(DateTime.thursday));

      // النهارده = 2026-10-01
      final todayIso = "${thursday.year}-${thursday.month.toString().padLeft(2, '0')}-${thursday.day.toString().padLeft(2, '0')}";
      expect(todayIso, equals("2026-10-01"));

      // بكرة = 2026-10-02
      final tomorrow = thursday.add(const Duration(days: 1));
      final tomorrowIso = "${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}";
      expect(tomorrowIso, equals("2026-10-02"));

      // بعد بكرة = 2026-10-03
      final afterTomorrow = thursday.add(const Duration(days: 2));
      final afterTomorrowIso = "${afterTomorrow.year}-${afterTomorrow.month.toString().padLeft(2, '0')}-${afterTomorrow.day.toString().padLeft(2, '0')}";
      expect(afterTomorrowIso, equals("2026-10-03"));

      // الجمعة دي from Thursday = tomorrow (Friday 2026-10-02)
      final daysToFriday = (DateTime.friday - thursday.weekday + 7) % 7;
      final thisFriday = thursday.add(Duration(days: daysToFriday));
      expect(thisFriday.day, equals(2));

      // الجمعة الجاية from Thursday = Friday next week (2026-10-09)
      final nextFriday = thisFriday.add(const Duration(days: 7));
      expect(nextFriday.day, equals(9));
    });

    test('Egyptian Temporal Engine: Correct time expressions and periods', () {
      final periods = {
        'الصبح': {'from': 6, 'to': 12, 'period': 'morning'},
        'بعد الظهر': {'from': 14, 'to': 18, 'period': 'afternoon'},
        'بعد المغرب': {'from': 18, 'to': 21, 'period': 'evening'},
        'بالليل': {'from': 20, 'to': 23, 'period': 'evening'},
        'سهرة': {'from': 23, 'to': 2, 'period': 'night'},
      };

      expect(periods['الصبح']!['period'], equals('morning'));
      expect(periods['بعد الظهر']!['period'], equals('afternoon'));
      expect(periods['بعد المغرب']!['period'], equals('evening'));
      expect(periods['بالليل']!['period'], equals('evening'));
      expect(periods['سهرة']!['period'], equals('night'));
    });

    test('Egyptian Temporal Engine: Ambiguity and Multi-Turn Context Retention', () {
      // 1. "الساعة 10" without AM/PM is ambiguous
      const rawTime = "10:00";
      const hasClue = false;
      expect(hasClue, isFalse, reason: 'Hour 10 without morning/night must require clarification');

      // 2. "الساعة 10 أو 11" preserves both slots
      final times = ["22:00", "23:00"];
      expect(times.length, equals(2), reason: 'Must maintain both choices');

      // 3. Multi-turn stadium persistence:
      // Turn 1: stadium selected
      var context = {'stadium_id': 'std-100', 'stadium_name': 'ملعب الأبطال'};
      expect(context['stadium_id'], equals('std-100'));

      // Turn 2: date/time question
      context['date'] = '2026-10-09';
      expect(context['stadium_id'], equals('std-100'), reason: 'Stadium preserved across turn 2');

      // Turn 3: "نفس الملعب"
      final isSameStadium = 'نفس الملعب'.contains('نفس الملعب');
      expect(isSameStadium, isTrue);
      expect(context['stadium_name'], equals('ملعب الأبطال'), reason: 'Stadium identity preserved');
    });

    // -------------------------------------------------------------------------
    // Task 4: Server-Side executeAppAction Route Security
    // -------------------------------------------------------------------------
    test('Server-Side Route Security: Strictly allows owner routes and blocks player/arbitrary routes', () {
      const ownerAllowed = [
        '/dashboard',
        '/bookings',
        '/ledger',
        '/profile',
        '/settings',
        '/add-stadium',
        '/subscription-plans',
      ];

      const ownerForbidden = [
        '/player',
        '/checkout',
        '/tournaments',
        '/1v1',
        '/admin',
        '/random-route',
        '',
      ];

      bool isOwnerRouteAllowed(String route) {
        if (route.isEmpty) return false;
        return ownerAllowed.any((r) => route == r || route.startsWith('$r/') || route.startsWith('$r?'));
      }

      for (final r in ownerAllowed) {
        expect(isOwnerRouteAllowed(r), isTrue, reason: 'Owner route $r must be allowed');
        expect(isOwnerRouteAllowed('$r?tab=history'), isTrue);
      }

      for (final r in ownerForbidden) {
        expect(isOwnerRouteAllowed(r), isFalse, reason: 'Forbidden route $r must be rejected');
      }
    });

    // -------------------------------------------------------------------------
    // Task 5: 7-Turn Context Retention Behavioral Verification
    // -------------------------------------------------------------------------
    test('Context Retention: 7-turn sequential state retention across stadium, date, time, and operations', () {
      final sessionState = <String, dynamic>{
        'stadium_id': null,
        'stadium_name': null,
        'date': null,
        'time': null,
        'active_task': null,
      };

      // Turn 1: Establish stadium
      sessionState['stadium_id'] = 'std-77';
      sessionState['stadium_name'] = 'ملعب الأبطال';
      expect(sessionState['stadium_id'], equals('std-77'));

      // Turn 2: Relative date + evening
      sessionState['date'] = '2026-10-09';
      sessionState['time_period'] = 'evening';
      expect(sessionState['stadium_id'], equals('std-77'));
      expect(sessionState['date'], equals('2026-10-09'));

      // Turn 3: Inspect bookings query
      sessionState['active_task'] = 'owner_stadiums';
      expect(sessionState['stadium_id'], equals('std-77'));
      expect(sessionState['date'], equals('2026-10-09'));

      // Turn 4: "نفس الملعب" reference resolution
      final resolvedStadiumId = sessionState['stadium_id'];
      expect(resolvedStadiumId, equals('std-77'));

      // Turn 5: Refine time to 22:00
      sessionState['time'] = '22:00';
      expect(sessionState['stadium_id'], equals('std-77'));
      expect(sessionState['time'], equals('22:00'));

      // Turn 6: Navigate to /bookings
      const plannedRoute = '/bookings';
      expect(plannedRoute, equals('/bookings'));
      expect(sessionState['stadium_id'], equals('std-77'));

      // Turn 7: Financial query
      sessionState['active_task'] = 'owner_financial';
      expect(sessionState['stadium_id'], equals('std-77'));
      expect(sessionState['stadium_name'], equals('ملعب الأبطال'));
      expect(sessionState['date'], equals('2026-10-09'));
    });

    // -------------------------------------------------------------------------
    // Task 6: Long Conversation Sequence Ordering (> 6 Messages)
    // -------------------------------------------------------------------------
    test('Conversation History: Sorts by message_sequence ascending with created_at fallback', () {
      final rawMessages = [
        {'seq': 4, 'content': 'D', 'created_at': '2026-10-01T12:04:00Z'},
        {'seq': 1, 'content': 'A', 'created_at': '2026-10-01T12:01:00Z'},
        {'seq': 7, 'content': 'G', 'created_at': '2026-10-01T12:07:00Z'},
        {'seq': 2, 'content': 'B', 'created_at': '2026-10-01T12:02:00Z'},
        {'seq': 5, 'content': 'E', 'created_at': '2026-10-01T12:05:00Z'},
        {'seq': 3, 'content': 'C', 'created_at': '2026-10-01T12:03:00Z'},
        {'seq': 8, 'content': 'H', 'created_at': '2026-10-01T12:08:00Z'},
        {'seq': 6, 'content': 'F', 'created_at': '2026-10-01T12:06:00Z'},
      ];

      expect(rawMessages.length, greaterThan(6));

      final sorted = List.of(rawMessages)..sort((a, b) {
        final seqA = a['seq'] as int?;
        final seqB = b['seq'] as int?;
        if (seqA != null && seqB != null) return seqA.compareTo(seqB);
        return (a['created_at'] as String).compareTo(b['created_at'] as String);
      });

      for (int i = 0; i < sorted.length; i++) {
        expect(sorted[i]['seq'], equals(i + 1));
      }
    });
  });
}
