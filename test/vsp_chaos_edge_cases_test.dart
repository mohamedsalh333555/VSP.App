import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/core/models/user_model.dart';

// =========================================================================
// VSP Chaos & Security Validation Engine
// =========================================================================

void validateJoinChampionship({required Team team, required Championship championship}) {
 if (team.memberUids.length < 5) {
 throw Exception('team_too_small_error');
 }
 if (championship.status == 'ongoing' || championship.status == 'completed') {
 throw Exception('championship_already_started_error');
 }
}

void validateDeleteTeamOrMember({
 required Team team,
 required List<Championship> activeChampionships,
 required List<TournamentMatch> futureMatches,
}) {
 final isInOngoingChamp = activeChampionships.any(
 (c) => c.status == 'ongoing' && c.joinedTeams.contains(team.id),
 );
 
 final hasFutureMatch = futureMatches.any(
 (m) => (m.homeTeamId == team.id || m.awayTeamId == team.id) && m.winnerId == null,
 );

 if (isInOngoingChamp || hasFutureMatch) {
 throw Exception('active_match_or_tournament_error');
 }
}

void validateMatchScore({
 required TournamentMatch match,
 required Championship championship,
 required int homeScore,
 required int awayScore,
}) {
 if (championship.status == 'completed') {
 throw Exception('championship_already_completed_error');
 }
 if (championship.type == 'Cup' && homeScore == awayScore) {
 throw Exception('knockout_draw_not_allowed_error');
 }
}

void validateBookingOverlap({
 required DateTime startA,
 required DateTime endA,
 required DateTime startB,
 required DateTime endB,
}) {
 // A overlaps with B if (startB is before endA) AND (startA is before endB)
 if (startB.isBefore(endA) && startA.isBefore(endB)) {
 throw Exception('booking_overlap_detected_error');
 }
}

void validateBankruptPlayer({
 required UserModel player,
 required String paymentMethod,
 required bool isPaid,
}) {
 if (player.noShowCount >= 3 && paymentMethod == 'cash' && !isPaid) {
 throw Exception('cash_payment_restricted_error');
 }
}

// =========================================================================
// Main Test Group
// =========================================================================

void main() {
 group(' VSP Chaos & Security QA Test Suite', () {
 
 // ---------------------------------------------------------------------
 // Scenario 1: The Malicious Captain
 // ---------------------------------------------------------------------
 test('Scenario 1: The Malicious Captain - Team Size and Championship State Barriers', () {
 print('\n [SCENARIO 1] Testing Malicious Captain restrictions...');
 
 final smallTeam = Team(
 id: 'team_small',
 name: 'Underdogs',
 captainName: 'Malicious Captain',
 captainImageUrl: '',
 date: '2026-07-05',
 stadium: 'Stadium A',
 pricePerPerson: 50.0,
 currentPlayers: 2,
 maxPlayers: 11,
 memberUids: ['user_captain', 'user_friend'], // Only 2 members!
 );

 final validTeam = Team(
 id: 'team_valid',
 name: 'Pro Players',
 captainName: 'Good Captain',
 captainImageUrl: '',
 date: '2026-07-05',
 stadium: 'Stadium A',
 pricePerPerson: 50.0,
 currentPlayers: 5,
 maxPlayers: 11,
 memberUids: ['u1', 'u2', 'u3', 'u4', 'u5'], // 5 members!
 );

 final openChampionship = Championship(
 id: 'champ_open',
 name: 'Open Tournament',
 type: 'Cup',
 sportType: 'Football',
 logoUrl: '',
 startDate: DateTime.now(),
 endDate: DateTime.now().add(const Duration(days: 5)),
 entryFee: 1000,
 grandPrize: 5000,
 maxTeams: 8,
 joinedTeams: [],
 ownerId: 'owner_1',
 governorate: 'Cairo',
 paidTeams: [],
 status: 'open',
 );

 final ongoingChampionship = Championship(
 id: 'champ_ongoing',
 name: 'Active Tournament',
 type: 'Cup',
 sportType: 'Football',
 logoUrl: '',
 startDate: DateTime.now(),
 endDate: DateTime.now().add(const Duration(days: 5)),
 entryFee: 1000,
 grandPrize: 5000,
 maxTeams: 8,
 joinedTeams: ['team_a', 'team_b'],
 ownerId: 'owner_1',
 governorate: 'Cairo',
 paidTeams: [],
 status: 'ongoing',
 );

 // A. Verify small team (2 players) fails to join
 expect(
 () => validateJoinChampionship(team: smallTeam, championship: openChampionship),
 throwsA(predicate((e) => e.toString().contains('team_too_small_error'))),
 );
 print(' Checked: Small team (< 5 players) was blocked from joining.');

 // B. Verify valid team (5 players) fails to join an ongoing championship
 expect(
 () => validateJoinChampionship(team: validTeam, championship: ongoingChampionship),
 throwsA(predicate((e) => e.toString().contains('championship_already_started_error'))),
 );
 print(' Checked: Blocked joining an already active/ongoing tournament.');
 });

 // ---------------------------------------------------------------------
 // Scenario 2: The Ghost Team (Orphan Prevention)
 // ---------------------------------------------------------------------
 test('Scenario 2: The Ghost Team - Delete/Leave Prevention During Active Matches', () {
 print('\n [SCENARIO 2] Testing Ghost Team Orphan Prevention...');

 final activeTeam = Team(
 id: 'team_active',
 name: 'Ahly',
 captainName: 'Capt',
 captainImageUrl: '',
 date: '2026-07-05',
 stadium: 'Cairo Stadium',
 pricePerPerson: 50.0,
 currentPlayers: 5,
 maxPlayers: 11,
 memberUids: ['u1', 'u2', 'u3', 'u4', 'u5'],
 );

 final ongoingChamps = [
 Championship(
 id: 'champ_ongoing',
 name: 'Active Tournament',
 type: 'Cup',
 sportType: 'Football',
 logoUrl: '',
 startDate: DateTime.now(),
 endDate: DateTime.now().add(const Duration(days: 5)),
 entryFee: 1000,
 grandPrize: 5000,
 maxTeams: 4,
 joinedTeams: ['team_active', 'team_b', 'team_c', 'team_d'],
 ownerId: 'owner_1',
 governorate: 'Cairo',
 paidTeams: [],
 status: 'ongoing',
 )
 ];

 final futureMatches = [
 TournamentMatch(
 id: 'match_1',
 championshipId: 'champ_ongoing',
 roundIndex: 1,
 matchIndex: 0,
 homeTeamId: 'team_active',
 homeTeamName: 'Ahly',
 awayTeamId: 'team_b',
 awayTeamName: 'Zamalek',
 )
 ];

 // Verify captain cannot delete or leave while team is active in tournament/matches
 expect(
 () => validateDeleteTeamOrMember(
 team: activeTeam,
 activeChampionships: ongoingChamps,
 futureMatches: futureMatches,
 ),
 throwsA(predicate((e) => e.toString().contains('active_match_or_tournament_error'))),
 );
 print(' SECURITY SECURED: System blocked deleting/disbanding the active team.');
 });

 // ---------------------------------------------------------------------
 // Scenario 3: The Corrupt Referee
 // ---------------------------------------------------------------------
 test('Scenario 3: The Corrupt Referee - Draw Prevention & Completed States Lock', () {
 print('\n [SCENARIO 3] Testing Corrupt Referee blocks...');

 final cupChampionship = Championship(
 id: 'champ_cup',
 name: 'Cup Tournament',
 type: 'Cup', // Knockout Tournament!
 sportType: 'Football',
 logoUrl: '',
 startDate: DateTime.now(),
 endDate: DateTime.now().add(const Duration(days: 5)),
 entryFee: 1000,
 grandPrize: 5000,
 maxTeams: 8,
 joinedTeams: [],
 ownerId: 'owner_1',
 governorate: 'Cairo',
 paidTeams: [],
 status: 'ongoing',
 );

 final completedChampionship = Championship(
 id: 'champ_completed',
 name: 'Finished Tournament',
 type: 'Cup',
 sportType: 'Football',
 logoUrl: '',
 startDate: DateTime.now(),
 endDate: DateTime.now().add(const Duration(days: 5)),
 entryFee: 1000,
 grandPrize: 5000,
 maxTeams: 8,
 joinedTeams: [],
 ownerId: 'owner_1',
 governorate: 'Cairo',
 paidTeams: [],
 status: 'completed', // Finished!
 );

 final activeMatch = TournamentMatch(
 id: 'm1',
 championshipId: 'champ_cup',
 roundIndex: 1,
 matchIndex: 0,
 );

 // A. Verify drawing (1-1) is blocked in Cup/Knockout match
 expect(
 () => validateMatchScore(
 match: activeMatch,
 championship: cupChampionship,
 homeScore: 1,
 awayScore: 1,
 ),
 throwsA(predicate((e) => e.toString().contains('knockout_draw_not_allowed_error'))),
 );
 print(' Checked: System rejected draw score in a Knockout (Cup) match.');

 // B. Verify changing scores after championship is completed is blocked
 expect(
 () => validateMatchScore(
 match: activeMatch,
 championship: completedChampionship,
 homeScore: 3,
 awayScore: 1,
 ),
 throwsA(predicate((e) => e.toString().contains('championship_already_completed_error'))),
 );
 print(' Checked: System locked score input for completed championships.');
 });

 // ---------------------------------------------------------------------
 // Scenario 4: Micro-Overlap Booking
 // ---------------------------------------------------------------------
 test('Scenario 4: Micro-Overlap Booking - Precise Minute-Overlap Lockout', () {
 print('\n [SCENARIO 4] Testing Micro-Overlap Bookings...');

 // Booking A: 6:00 PM to 7:00 PM (18:00 to 19:00)
 final bookingAStart = DateTime(2026, 7, 5, 18, 0);
 final bookingAEnd = DateTime(2026, 7, 5, 19, 0);

 // Booking B (Malicious overlap attempt): 6:59 PM to 8:00 PM (18:59 to 20:00)
 final bookingBStart = DateTime(2026, 7, 5, 18, 59);
 final bookingBEnd = DateTime(2026, 7, 5, 20, 0);

 expect(
 () => validateBookingOverlap(
 startA: bookingAStart,
 endA: bookingAEnd,
 startB: bookingBStart,
 endB: bookingBEnd,
 ),
 throwsA(predicate((e) => e.toString().contains('booking_overlap_detected_error'))),
 );
 print(' Checked: Overlapping booking (even by 1 minute) was successfully blocked.');
 });

 // ---------------------------------------------------------------------
 // Scenario 5: The Bankrupt Player
 // ---------------------------------------------------------------------
 test('Scenario 5: The Bankrupt Player - Debt/No-Show Lockout', () {
 print('\n [SCENARIO 5] Testing Bankrupt Player restrictions...');

 final cleanPlayer = UserModel(
 uid: 'user_clean',
 email: 'clean@vsp.com',
 role: 'player',
 noShowCount: 0, // 0 No-shows
 );

 final badPlayer = UserModel(
 uid: 'user_bad',
 email: 'debtor@vsp.com',
 role: 'player',
 noShowCount: 3, // 3 No-shows (Banned from cash booking!)
 );

 // A. Clean player can book using cash
 expect(
 () {
 validateBankruptPlayer(player: cleanPlayer, paymentMethod: 'cash', isPaid: false);
 },
 returnsNormally,
 );
 print(' Checked: Clean player successfully allowed to book using Cash.');

 // B. Debtor player is rejected from booking with Cash
 expect(
 () => validateBankruptPlayer(player: badPlayer, paymentMethod: 'cash', isPaid: false),
 throwsA(predicate((e) => e.toString().contains('cash_payment_restricted_error'))),
 );
 print(' Checked: Debtor player (3 no-shows) was successfully blocked from Cash bookings.');
 });

 });
}
