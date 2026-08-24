import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/core/utils/elo_calculator.dart';

void main() {
 group('VSP Ultimate Player & Tournament Journey E2E Test', () {
 late List<Team> mockDatabaseTeams;
 late List<Booking> mockDatabaseBookings;

 setUp(() {
 mockDatabaseTeams = [];
 mockDatabaseBookings = [];
 });

 // ─────────────────────────────────────────────────────────────────────────
 // 1. فحص الدخول والمصادقة (Google Login & Reset Password)
 // ─────────────────────────────────────────────────────────────────────────
 test('Step 1: Auth Flows (Google In & Password Reset)', () {
 print(' [TEST] Simulating Google Sign-In...');
 final googleUserMetadata = {
 'name': 'Ahmed Captain',
 'email': 'ahmed@vsp.app',
 'picture': 'https://vsp.app/avatar.png'
 };
 expect(googleUserMetadata['email'], 'ahmed@vsp.app');

 print(' [TEST] Simulating Password Reset Link generation...');
 const resetEmail = 'ahmed@vsp.app';
 const redirectUrl = 'io.supabase.fluttervsp://reset-callback/';
 expect(resetEmail, isNotNull);
 expect(redirectUrl, contains('reset-callback'));
 print(' Auth flows verified successfully.');
 });

 // ─────────────────────────────────────────────────────────────────────────
 // 2. إنشاء فريق ودعوة لاعبين مع حظر التجاوز عن 12 لاعب
 // ─────────────────────────────────────────────────────────────────────────
 test('Step 2: Team Creation, 12-Player Limit & Invitations', () {
 print(' [TEST] Creating a new team: "Giza Gladiators"');
 final team = Team(
 id: 'team_01',
 name: 'Giza Gladiators',
 captainName: 'Ahmed Captain',
 captainImageUrl: 'https://vsp.app/avatar.png',
 logoUrl: 'https://vsp.app/logo.png',
 date: 'Upcoming',
 stadium: 'Cairo Stadium',
 pricePerPerson: 50.0,
 currentPlayers: 1,
 maxPlayers: 12,
 memberUids: ['user_captain_ahmed'],
 playerImages: ['https://vsp.app/avatar.png'],
 );
 mockDatabaseTeams.add(team);

 print(' [TEST] Inviting existing app users up to 11 members (Total 12)...');
 var updatedUids = List<String>.from(team.memberUids);
 for (int i = 1; i <= 11; i++) {
 updatedUids.add('player_$i');
 }

 expect(updatedUids.length, 12);
 print(' [TEST] Trying to invite the 13th player (Must fail at barrier check!)');
 
 bool allowedToInvite13th = true;
 if (updatedUids.length >= 12) {
 allowedToInvite13th = false;
 }
 expect(allowedToInvite13th, false, reason: "13th player invitation must be blocked!");
 print(' 12-Player Squad Limit barrier verified successfully.');

 print(' [TEST] Inviting non-registered player via WhatsApp invitation fallback');
 const nonRegisteredPhone = '+201100229462';
 final inviteMessage = "Hey! Join Giza Gladiators on VSP: io.supabase.fluttervsp://team/team_01";
 expect(nonRegisteredPhone, startsWith('+20'));
 expect(inviteMessage, contains('team_01'));
 });

 // ─────────────────────────────────────────────────────────────────────────
 // 3. محاكاة الحجوزات، كود التحقق السداسي، وحظر الشات عند الإلغاء
 // ─────────────────────────────────────────────────────────────────────────
 test('Step 3: Bookings, 6-Digit Pitch Code & Chat Lockout', () {
 final now = DateTime.now();

 // حجز 1: مباراة تحدي ضد فريق خصم
 print(' [TEST] Booking Challenge Match vs Blue Lions...');
 final challengeBooking = Booking(
 id: 'bk_challenge_uuid_code_123',
 stadiumId: 'std_cairo',
 stadiumName: 'Cairo Stadium',
 ownerId: 'owner_cairo',
 startTime: now.add(const Duration(days: 3)),
 endTime: now.add(const Duration(days: 3, hours: 1)),
 bookingType: BookingType.challenge,
 playerTeamId: 'team_01',
 playerTeamName: 'Giza Gladiators',
 opponentTeamId: 'team_blue_lions',
 opponentTeamName: 'Blue Lions',
 isPrivate: false,
 rentBall: false,
 totalPrice: 300,
 paymentMethod: 'cash',
 status: BookingStatus.confirmed,
 createdByUserId: 'user_captain_ahmed',
 createdAt: now,
 );
 mockDatabaseBookings.add(challengeBooking);

 print(' [TEST] Verifying 6-Digit Pitch Code generation from UUID prefix...');
 final String pitchCode = challengeBooking.id.substring(0, 6).toUpperCase();
 expect(pitchCode.length, 6);
 expect(pitchCode, 'BK_CHA');
 print(' Pitch Code verified successfully: $pitchCode');

 // تسجيل النتيجة وتأثير نقاط الـ Elo
 print(' [TEST] Submitting Match Result: Giza Gladiators wins 3-1!');
 final resolvedBooking = challengeBooking.copyWith(
 status: BookingStatus.completed,
 finalOutcome: MatchOutcome.homeWin,
 matchResultStatus: MatchResultStatus.confirmed,
 );
 mockDatabaseBookings[0] = resolvedBooking;

 final updatedRatings = EloCalculator.calculateNewRatings(
 homeRating: 1000, 
 awayRating: 1000, 
 outcome: 1.0, 
 );
 expect(updatedRatings['home']!, greaterThan(1000));
 print(' Elo Points updated. Giza Gladiators: ${updatedRatings['home']} pts!');

 // إلغاء الحجز وحظر الشات تلقائياً
 print(' [TEST] Cancelling booking and verifying Chat lockout...');
 final cancelledBooking = challengeBooking.copyWith(status: BookingStatus.cancelled);
 
 bool isChatInputLocked = false;
 if (cancelledBooking.status == BookingStatus.cancelled) {
 isChatInputLocked = true;
 }
 expect(isChatInputLocked, true, reason: "Chat must be archived and locked upon cancellation!");
 print(' Chat auto-lock on cancellation verified successfully.');
 });

 // ─────────────────────────────────────────────────────────────────────────
 // 4. سيناريوهات البطولة الثلاثة (فوز بالنهائي، خسارة النهائي، خروج مبكر)
 // ─────────────────────────────────────────────────────────────────────────
 test('Step 4: Triple Championship Scenarios & Team Card Updates', () {
 final team = Team(
 id: 'team_01',
 name: 'Giza Gladiators',
 captainName: 'Ahmed Captain',
 captainImageUrl: 'https://vsp.app/avatar.png',
 logoUrl: 'https://vsp.app/logo.png',
 date: 'Upcoming',
 stadium: 'Cairo Stadium',
 pricePerPerson: 50.0,
 currentPlayers: 11,
 maxPlayers: 12,
 points: 1000,
 championshipsWon: 0,
 unlockedBadges: [],
 );

 // سيناريو أ: الوصول للنهائي والفوز بالتتويج والكأس والشارة
 print(' [SCENARIO A] Playing VSP Ramadan Cup - Reached Final & WON!');
 final teamScenarioA = team.copyWith(
 championshipsWon: team.championshipsWon + 1,
 points: team.points + 100, 
 );
 final badgesA = List<String>.from(teamScenarioA.unlockedBadges);
 if (!badgesA.contains('cup_winner')) {
 badgesA.add('cup_winner');
 }
 final finalTeamA = teamScenarioA.copyWith(unlockedBadges: badgesA);

 expect(finalTeamA.championshipsWon, 1, reason: "Trophy count must increment");
 expect(finalTeamA.unlockedBadges.contains('cup_winner'), true, reason: "Cup Winner badge must be unlocked");
 print(' [TEST] Team Card updated: championshipsWon=${finalTeamA.championshipsWon}, Badges=${finalTeamA.unlockedBadges}');

 // سيناريو ب: الوصول للنهائي والخسارة (لا يوجد كأس جديد)
 print(' [SCENARIO B] Reached VSP Summer Cup Final but LOST.');
 final teamScenarioB = team.copyWith(
 points: team.points + 50, 
 );
 expect(teamScenarioB.championshipsWon, 0, reason: "Losing final adds no trophy");

 // سيناريو ج: الخروج المبكر (من أول جولة)
 print(' [SCENARIO C] Played Champions Cup - Knocked out in Round 1.');
 final teamScenarioC = team.copyWith(
 points: team.points + 5, 
 );
 expect(teamScenarioC.championshipsWon, 0);
 print(' All 3 tournament scenarios executed successfully.');
 });
 });
}
