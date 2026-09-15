import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/repositories/tournament/tournament_bracket_engine.dart';
import 'package:vsp_application/core/repositories/tournament/tournament_payload_builder.dart';
import 'package:vsp_application/data/models.dart';

void main() {
  group('🏆 VSP Owner Tournament & Financial End-to-End Journey Simulation', () {
    late Championship championship;
    late List<Team> registeredTeams;
    late List<Map<String, dynamic>> financialLedger;
    late List<TournamentMatch> matchTree;

    setUp(() {
      registeredTeams = [];
      financialLedger = [];
      matchTree = [];
    });

    test(
        'E2E Journey: Creation -> Teams Joining (Online + Manual) -> Fees Paid -> Owner Payout -> Draw -> Match Results -> Champion Crowned -> Prize Delivered',
        () async {
      print('\n' + '=' * 75);
      print('🚀 بدء محاكاة رحلة المالك الكاملة: إنشاء البطولة، التحصيل المالي، القرعة وتتويج البطل');
      print('=' * 75);

      // ─────────────────────────────────────────────────────────────────────────
      // المرحلة 1: إنشاء البطولة من قبل مالك الملعب (Tournament Creation)
      // ─────────────────────────────────────────────────────────────────────────
      print('\n📍 [المرحلة 1]: إنشاء البطولة بواسطة مالك الملعب...');

      final rawWizardData = {
        'name': 'كأس أبطال القاهرة الكبرى 2026',
        'type': 'Cup', // من واجهة المعالج
        'sportType': 'Football',
        'entryFee': 500.0,
        'grandPrize': 2500.0,
        'maxTeams': 8,
        'governorate': 'Cairo',
        'ownerId': 'owner_cairo_stadium_01',
        'rules': 'قوانين كرة القدم الخماسية، خروج المغلوب من مباراة واحدة.',
        'matchDuration': 30,
        // تأكيد أن التواريخ غير مفروضة مسبقاً ويختارها المستخدم
        'startDate': DateTime(2026, 10, 1, 18, 0).toIso8601String(),
        'endDate': DateTime(2026, 10, 15, 22, 0).toIso8601String(),
      };

      // تحويل البيانات عبر TournamentPayloadBuilder للتوافق مع PostgreSQL
      final createPayload = TournamentPayloadBuilder.buildCreatePayload(
        rawWizardData,
        isAdminApproved: true,
        fallbackOwnerId: 'owner_cairo_stadium_01',
      );

      // التحقق الصارم من التوافق مع قيد قاعدة البيانات championships_type_check
      expect(createPayload['type'], 'cup',
          reason: 'يجب أن يكون النوع بحروف صغيرة lowercase ليتوافق مع قيد Supabase');
      expect(createPayload['status'], 'open');
      expect(createPayload['max_teams'], 8);
      expect(createPayload['entry_fee'], 500.0);
      expect(createPayload['grand_prize'], 2500.0);

      // نمذجة البطولة في بيئة التطبيق
      championship = Championship.fromFirestore(createPayload, 'champ_cairo_001');

      // التحقق من أن الموديل يحول النوع داخلياً إلى 'Cup' لتوافق الشاشات والواجهات
      expect(championship.type, 'Cup');
      expect(championship.isFull, isFalse);

      print('  ✅ تم إنشاء البطولة بنجاح!');
      print('     - الاسم: ${championship.name}');
      print('     - النظام: ${championship.type} (مخزن في قاعدة البيانات كـ ${createPayload['type']})');
      print('     - السعة: ${championship.maxTeams} فرق');
      print('     - رسوم الاشتراك: ${championship.entryFee} ج.م | الجائزة الكبرى: ${championship.grandPrize} ج.م');

      // ─────────────────────────────────────────────────────────────────────────
      // المرحلة 2: انضمام الفرق (4 فرق أونلاين + 4 فرق يدوي عند المالك)
      // ─────────────────────────────────────────────────────────────────────────
      print('\n📍 [المرحلة 2]: انضمام وتأكيد الفرق في البطولة (8 فرق)...');

      // 1. أربعة فرق تشترك عبر التطبيق (Online Player Teams)
      final onlineTeamNames = [
        'نجوم المعادي',
        'ذئاب التجمع',
        'صقور الزمالك',
        'أساطير نصر سيتي',
      ];

      for (int i = 0; i < 4; i++) {
        final team = Team(
          id: 'team_online_${i + 1}',
          name: onlineTeamNames[i],
          captainName: 'كابتن ${onlineTeamNames[i]}',
          captainImageUrl: 'https://vsp.app/avatars/captain_$i.png',
          date: 'Upcoming',
          stadium: 'Cairo Arena',
          pricePerPerson: 50.0,
          currentPlayers: 7,
          maxPlayers: 10,
          points: 1200 + (i * 50),
          championshipsWon: i,
          unlockedBadges: ['active_squad'],
          memberUids: List.generate(7, (idx) => 'player_on_${i}_$idx'),
        );
        registeredTeams.add(team);
        championship = championship.copyWith(
          joinedTeams: [...championship.joinedTeams, team.id],
        );
        print('  📲 انضمام فريق إلكتروني: ${team.name} (تشكيلة من ${team.currentPlayers} لاعبين)');
      }

      // 2. أربعة فرق تسجل يدوياً في كشك الملعب (Offline Walk-in Teams)
      final manualTeamNames = [
        'فريق الأصدقاء بالملعب',
        'أبطال شباب المعادي',
        'فريق أكاديمية الفرسان',
        'نمور الحريفة',
      ];

      for (int i = 0; i < 4; i++) {
        final team = Team(
          id: 'team_manual_${i + 1}',
          name: manualTeamNames[i],
          captainName: 'كابتن ${manualTeamNames[i]}',
          captainImageUrl: 'https://vsp.app/avatars/manual_$i.png',
          date: 'Upcoming',
          stadium: 'Cairo Arena',
          pricePerPerson: 50.0,
          currentPlayers: 6,
          maxPlayers: 10,
          points: 1000,
          championshipsWon: 0,
          unlockedBadges: [],
          memberUids: List.generate(6, (idx) => 'player_man_${i}_$idx'),
        );
        registeredTeams.add(team);
        championship = championship.copyWith(
          joinedTeams: [...championship.joinedTeams, team.id],
        );
        print('  🏟️ تسجيل فريق يدوي بالملعب: ${team.name} (سجله المالك في النظام)');
      }

      expect(championship.joinedTeams.length, 8);
      expect(championship.isFull, isTrue);
      print('  ✅ اكتملت سعة البطولة: 8/8 فرق مسجلة وجاهزة.');

      // ─────────────────────────────────────────────────────────────────────────
      // المرحلة 3: سداد رسوم الاشتراك وتحصيل المالك للأموال (Financial Settlement)
      // ─────────────────────────────────────────────────────────────────────────
      print('\n📍 [المرحلة 3]: دورة المدفوعات والتحصيل المالي لمالك الملعب...');

      double totalCollectedFees = 0.0;
      final List<String> updatedPaidTeams = [];

      // سداد الفرق الـ 4 الأونلاين (Paymob / Wallet Payment Order Confirmation)
      for (int i = 0; i < 4; i++) {
        final team = registeredTeams[i];
        final orderAmount = championship.entryFee;
        final orderRef = 'ORDER_CHAMP_001_TEAM_${team.id}';
        final txId = 'PAYMOB_TX_98745$i';

        // محاكاة تأكيد أمر الدفع الإلكتروني
        financialLedger.add({
          'reference': orderRef,
          'type': 'tournament_entry_fee',
          'team_id': team.id,
          'team_name': team.name,
          'amount': orderAmount,
          'payment_method': 'credit_card_paymob',
          'transaction_id': txId,
          'status': 'confirmed',
          'created_at': DateTime.now().toIso8601String(),
        });
        updatedPaidTeams.add(team.id);
        totalCollectedFees += orderAmount;
        print('  💳 دفع إلكتروني ناجح: ${team.name} دفع $orderAmount ج.م (مرجع: $orderRef)');
      }

      // سداد الفرق الـ 4 النقدية وتأكيد المالك لاستلامها بالملعب (toggleTeamPayment)
      for (int i = 4; i < 8; i++) {
        final team = registeredTeams[i];
        final orderAmount = championship.entryFee;
        final cashReceiptRef = 'CASH_RECEIPT_STADIUM_${team.id}';

        financialLedger.add({
          'reference': cashReceiptRef,
          'type': 'tournament_entry_fee_cash',
          'team_id': team.id,
          'team_name': team.name,
          'amount': orderAmount,
          'payment_method': 'cash_on_arrival',
          'collected_by_owner': 'owner_cairo_stadium_01',
          'status': 'confirmed',
          'created_at': DateTime.now().toIso8601String(),
        });
        updatedPaidTeams.add(team.id);
        totalCollectedFees += orderAmount;
        print('  💵 دفع نقدي بالملعب: استلم المالك $orderAmount ج.م نقداً من ${team.name}');
      }

      championship = championship.copyWith(paidTeams: updatedPaidTeams);

      expect(championship.paidTeams.length, 8);
      expect(totalCollectedFees, 4000.0,
          reason: '8 فرق × 500 ج.م = 4000 ج.م إجمالي رسوم البطولة المحصلة');

      print('  💰 إجمالي المبالغ المحصلة للبطولة: $totalCollectedFees ج.م');

      // محاكاة تحصيل مالك الملعب لعوائد البطولة وطلب التسوية المالية
      print('  🏦 يقوم المالك بطلب تسوية وصرف مستحقات البطولة إلكترونياً (Payout Settlement)...');
      final payoutRequest = {
        'owner_id': championship.ownerId,
        'amount': totalCollectedFees,
        'method': 'InstaPay',
        'destination': 'cairo_stadium@instapay',
        'status': 'approved_and_transferred',
        'notes': 'تسوية عوائد اشتراكات بطولة كأس أبطال القاهرة 2026',
      };
      expect(payoutRequest['amount'], 4000.0);
      print('  ✅ تم تحويل مستحقات المالك بنجاح بقيمة ${payoutRequest['amount']} ج.م إلى حساب ${payoutRequest['destination']}');

      // ─────────────────────────────────────────────────────────────────────────
      // المرحلة 4: إجراء القرعة وتوليد الشجرة الإقصائية (Fixtures & Bracket Draw)
      // ─────────────────────────────────────────────────────────────────────────
      print('\n📍 [المرحلة 4]: إجراء القرعة وتوليد شجرة المباريات (Knockout Brackets)...');

      final teamMap = {for (var t in registeredTeams) t.id: t.name};
      final teamIds = championship.paidTeams;

      final capacity = TournamentBracketEngine.computeBracketCapacity(
        teamIds.length,
        championship.maxTeams,
      );
      expect(capacity, 8);

      final totalRounds = TournamentBracketEngine.computeTotalRounds(capacity);
      expect(totalRounds, 3); // ربع النهائي (2) -> نصف النهائي (1) -> النهائي (0)

      // توليد مباريات البطولة عبر محرك القواعد الرياضية النقي
      final generatedFixtures = TournamentBracketEngine.buildKnockoutMatchList(
        championshipId: championship.id,
        bracketCapacity: capacity,
        slots: teamIds,
        teamMap: teamMap,
      );

      expect(generatedFixtures.length, 7,
          reason: 'بطولة 8 فرق تتطلب 7 مباريات (4 ربع نهائي + 2 نصف نهائي + 1 نهائي)');

      // تحويل الخرائط إلى كائنات TournamentMatch
      for (final rawMatch in generatedFixtures) {
        matchTree.add(TournamentMatch(
          id: rawMatch['id'].toString(),
          championshipId: championship.id,
          roundIndex: rawMatch['round_index'] as int,
          matchIndex: rawMatch['match_index'] as int,
          homeTeamId: rawMatch['home_team_id']?.toString(),
          homeTeamName: rawMatch['home_team_name']?.toString(),
          awayTeamId: rawMatch['away_team_id']?.toString(),
          awayTeamName: rawMatch['away_team_name']?.toString(),
          nextMatchId: rawMatch['next_match_id']?.toString(),
          scheduledTime: DateTime.now().add(const Duration(days: 1)),
        ));
      }

      championship = championship.copyWith(status: 'ongoing');
      expect(championship.status, 'ongoing');

      print('  ✅ تم إجراء القرعة وتوليد 7 مباريات إقصائية:');
      for (final m in matchTree.where((m) => m.roundIndex == 2)) {
        print('     [ربع النهائي M${m.matchIndex}]: ${m.homeTeamName} 🆚 ${m.awayTeamName}');
      }

      // ─────────────────────────────────────────────────────────────────────────
      // المرحلة 5: خوض المباريات وتسجيل النتائج وتصعيد الفائزين
      // ─────────────────────────────────────────────────────────────────────────
      print('\n📍 [المرحلة 5]: انطلاق المباريات، تسجيل الأهداف وتصعيد الفرق...');

      // دالة لتسجيل نتيجة المباراة وتصعيد الفائز تلقائياً للشجرة التالية
      void simulateMatchResult(String matchId, int homeGoals, int awayGoals) {
        final matchIdx = matchTree.indexWhere((m) => m.id == matchId);
        final match = matchTree[matchIdx];

        final winnerId = homeGoals > awayGoals ? match.homeTeamId : match.awayTeamId;
        final winnerName = homeGoals > awayGoals ? match.homeTeamName : match.awayTeamName;

        matchTree[matchIdx] = TournamentMatch(
          id: match.id,
          championshipId: match.championshipId,
          roundIndex: match.roundIndex,
          matchIndex: match.matchIndex,
          homeTeamId: match.homeTeamId,
          homeTeamName: match.homeTeamName,
          awayTeamId: match.awayTeamId,
          awayTeamName: match.awayTeamName,
          homeScore: homeGoals,
          awayScore: awayGoals,
          winnerId: winnerId,
          scheduledTime: match.scheduledTime,
          nextMatchId: match.nextMatchId,
        );

        // تصعيد الفائز للجولة القادمة
        if (match.nextMatchId != null) {
          final nextIdx = matchTree.indexWhere((m) => m.id == match.nextMatchId);
          final nextMatch = matchTree[nextIdx];
          final isHomeSlot = match.matchIndex % 2 == 0;

          matchTree[nextIdx] = TournamentMatch(
            id: nextMatch.id,
            championshipId: nextMatch.championshipId,
            roundIndex: nextMatch.roundIndex,
            matchIndex: nextMatch.matchIndex,
            homeTeamId: isHomeSlot ? winnerId : nextMatch.homeTeamId,
            homeTeamName: isHomeSlot ? winnerName : nextMatch.homeTeamName,
            awayTeamId: !isHomeSlot ? winnerId : nextMatch.awayTeamId,
            awayTeamName: !isHomeSlot ? winnerName : nextMatch.awayTeamName,
            scheduledTime: nextMatch.scheduledTime,
            nextMatchId: nextMatch.nextMatchId,
          );
        }

        print('  ⚽ مباراة انتهت: ${match.homeTeamName} ($homeGoals) - ($awayGoals) ${match.awayTeamName} 👈 الفائز: $winnerName');
      }

      // لعب مباريات ربع النهائي (Round 2)
      print('  --- مباريات الدور ربع النهائي ---');
      final qfMatches = matchTree.where((m) => m.roundIndex == 2).toList();
      simulateMatchResult(qfMatches[0].id, 3, 1); // فوز فريق 1
      simulateMatchResult(qfMatches[1].id, 2, 0); // فوز فريق 3
      simulateMatchResult(qfMatches[2].id, 4, 2); // فوز فريق 5
      simulateMatchResult(qfMatches[3].id, 1, 0); // فوز فريق 7

      // لعب مباريات نصف النهائي (Round 1)
      print('\n  --- مباريات الدور نصف النهائي ---');
      final sfMatches = matchTree.where((m) => m.roundIndex == 1).toList();
      expect(sfMatches[0].homeTeamId, isNotNull);
      expect(sfMatches[0].awayTeamId, isNotNull);
      expect(sfMatches[1].homeTeamId, isNotNull);
      expect(sfMatches[1].awayTeamId, isNotNull);

      simulateMatchResult(sfMatches[0].id, 2, 1); // تأهل فريق 1 للنهائي
      simulateMatchResult(sfMatches[1].id, 3, 2); // تأهل فريق 5 للنهائي

      // ─────────────────────────────────────────────────────────────────────────
      // المرحلة 6: النهائي الكبير، تتويج البطل وتسليم الجائزة
      // ─────────────────────────────────────────────────────────────────────────
      print('\n📍 [المرحلة 6]: النهائي الكبير وتتويج البطل...');

      final finalMatch = matchTree.firstWhere((m) => m.roundIndex == 0);
      expect(finalMatch.homeTeamId, isNotNull);
      expect(finalMatch.awayTeamId, isNotNull);
      print('  🔥 مباراة النهائي: ${finalMatch.homeTeamName} 🆚 ${finalMatch.awayTeamName}');

      // حسم النهائي بنتيجة 3 - 2
      simulateMatchResult(finalMatch.id, 3, 2);

      final championId = finalMatch.homeTeamId!;
      final championName = finalMatch.homeTeamName!;
      var championTeam = registeredTeams.firstWhere((t) => t.id == championId);

      // تتويج البطل وإضافة الكأس للشارة الرسمية
      final updatedBadges = List<String>.from(championTeam.unlockedBadges);
      if (!updatedBadges.contains('cup_winner')) {
        updatedBadges.add('cup_winner');
      }
      championTeam = championTeam.copyWith(
        championshipsWon: championTeam.championshipsWon + 1,
        unlockedBadges: updatedBadges,
      );

      // تسليم الجائزة الكبرى وتسجيلها في السجل المالي
      final prizeReceipt = {
        'championship_id': championship.id,
        'champion_team_id': championId,
        'grand_prize_amount': championship.grandPrize,
        'delivered_by': championship.ownerId,
        'notes': 'تم تسليم شيك الجائزة الكبرى بقيمة 2500 ج.م لكابتن $championName',
        'delivered_at': DateTime.now().toIso8601String(),
      };

      championship = championship.copyWith(
        status: 'completed',
        championTeamId: championId,
        championTeamName: championName,
        prizeDelivered: true,
      );

      expect(championship.status, 'completed');
      expect(championship.championTeamId, championId);
      expect(championTeam.unlockedBadges, contains('cup_winner'));
      expect(prizeReceipt['grand_prize_amount'], 2500.0);

      print('\n' + '=' * 75);
      print('🎉 احتفالية تتويج بطل كأس أبطال القاهرة 2026 🎉');
      print('  🥇 البطل المتوج: $championName');
      print('  🏆 عدد بطولات الفريق أصبحت: ${championTeam.championshipsWon} كؤوس');
      print('  🎖️ الشارة المكتسبة: ${championTeam.unlockedBadges.last}');
      print('  💵 الجائزة الكبرى المسلمة: ${prizeReceipt['grand_prize_amount']} ج.م');
      print('  📜 الملاحظة المالية: ${prizeReceipt['notes']}');
      print('  🏁 حالة البطولة النهائية: ${championship.status}');
      print('=' * 75);
      print('✨ اكتملت المحاكاة الشاملة بنجاح 100% بدون أي خطأ!\n');
    });
  });
}
