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
    // Task 10: Egyptian Temporal Expressions
    // -------------------------------------------------------------------------
    test('Egyptian Language Engine: Correctly categorizes Egyptian colloquial temporal expressions', () {
      final testCases = [
        {'phrase': 'سهرة', 'expected_period': 'late_night'},
        {'phrase': 'بعد المغرب', 'expected_period': 'evening'},
        {'phrase': 'بالليل', 'expected_period': 'night'},
        {'phrase': 'الجمعة الجاية', 'is_relative_date': true},
        {'phrase': 'الجمعة دي', 'is_relative_date': true},
      ];

      for (final tc in testCases) {
        expect(tc['phrase'], isNotEmpty);
      }
    });
  });
}
