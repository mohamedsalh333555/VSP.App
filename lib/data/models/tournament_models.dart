export 'vsp_1v1_player.dart';
export 'tournament_match.dart';


/// Championship data model
class Championship {
 final String id;
 final String name;
 final String type; // Cup, League
 final String sportType;
 final String logoUrl;
 final DateTime startDate;
 final DateTime endDate;
 final double entryFee;
 final double grandPrize;
 final int maxTeams;
 final List<String> joinedTeams; // Team IDs
 final String ownerId;
 final String governorate;
 final String rules;
 final List<String> paymentMethods; // 'cash', 'online'
 
 // Settings / Rules
 final int maxPlayersPerTeam;
 final int minPlayersPerTeam;
 final int winningPoints;
 final int drawPoints;
 final int lossPoints;
 final int matchDuration; // in minutes
 final bool isBackAndForth;
 final bool trophyMedals;
 final bool redCardSuspension;
 final bool fairPlayScoring;

 // New Fields for Groups & League Systems
 final int numberOfGroups;
 final int qualifyingPerGroup;
 final bool isTwoLegs;

 // TOURNAMENT Lifecycle
 final String status; // 'open', 'ongoing', 'completed'
 final String? championTeamId;
 final String? championTeamName;

 // Entry Fee Tracking
 final List<String> paidTeams;

 // Financial Prize Pool & Ledger
 final double prizePool;
 final bool prizeDelivered;
 final DateTime? prizeDeliveredAt;
 final String? prizeDeliveredBy;
 final String? prizeDeliveryNotes;

 bool get isFull => joinedTeams.length >= maxTeams || status == 'full';

 Championship({
 required this.id,
 required this.name,
 required this.type,
 required this.sportType,
 required this.logoUrl,
 required this.startDate,
 required this.endDate,
 required this.entryFee,
 required this.grandPrize,
 required this.maxTeams,
 required this.joinedTeams,
 required this.ownerId,
 required this.governorate,
 this.rules = '',
 this.paymentMethods = const ['cash'],
 this.maxPlayersPerTeam = 11,
 this.minPlayersPerTeam = 5,
 this.winningPoints = 3,
 this.drawPoints = 1,
 this.lossPoints = 0,
 this.matchDuration = 30,
 this.isBackAndForth = false,
 this.trophyMedals = true,
 this.redCardSuspension = true,
 this.fairPlayScoring = false,
 this.numberOfGroups = 1,
 this.qualifyingPerGroup = 2,
 this.isTwoLegs = false,
 this.status = 'open',
 this.championTeamId,
 this.championTeamName,
 this.paidTeams = const [],
 this.prizePool = 0.0,
 this.prizeDelivered = false,
 this.prizeDeliveredAt,
 this.prizeDeliveredBy,
 this.prizeDeliveryNotes,
 });

 // SECURITY PATCH: Robust type parsing with crash prevention for malicious or corrupted data payloads.
 factory Championship.fromMap(Map<String, dynamic> data, [String? id]) =>
 Championship.fromFirestore(data, id ?? (data['id']?.toString() ?? ''));

 factory Championship.fromFirestore(Map<String, dynamic> data, String id) {
 try {
 final settings = data['settings'] as Map<String, dynamic>? ?? {};
 return Championship(
 id: id,
 name: data['name']?.toString() ?? '',
 type: data['type']?.toString() ?? 'Cup',
 sportType: data['sport_type'] ?? data['sportType']?.toString() ?? 'Football',
 logoUrl: (data['logo_url'] ?? data['logoUrl'] ?? '')?.toString() ?? '',
 startDate: data['start_date'] != null 
 ? DateTime.tryParse(data['start_date'].toString()) ?? DateTime.now()
 : (data['startDate'] != null ? DateTime.tryParse(data['startDate'].toString()) ?? DateTime.now() : DateTime.now()),
 endDate: data['end_date'] != null 
 ? DateTime.tryParse(data['end_date'].toString()) ?? DateTime.now()
 : (data['endDate'] != null ? DateTime.tryParse(data['endDate'].toString()) ?? DateTime.now() : DateTime.now()),
 entryFee: double.tryParse((data['entry_fee'] ?? data['entryFee'] ?? 0).toString()) ?? 0.0,
 grandPrize: double.tryParse((data['grand_prize'] ?? data['grandPrize'] ?? 0).toString()) ?? 0.0,
 maxTeams: int.tryParse((data['max_teams'] ?? data['maxTeams'] ?? 16).toString()) ?? 16,
 joinedTeams: (data['joined_teams'] as List? ?? data['joinedTeams'] as List?)?.map((e) => e.toString()).toList() ?? <String>[],
 ownerId: (data['owner_id'] ?? data['ownerId'] ?? '')?.toString() ?? '',
 governorate: data['governorate']?.toString() ?? 'Cairo',
 rules: data['rules']?.toString() ?? '',
 paymentMethods: (data['payment_methods'] as List? ?? data['paymentMethods'] as List?)?.map((e) => e.toString()).toList() ?? <String>['cash'],
 // قراءة الإعدادات من أعمدتها المسطحة مباشرة مع خيار السقوط الخلفي للـ settings
 maxPlayersPerTeam: int.tryParse((data['max_players_per_team'] ?? settings['maxPlayers'] ?? settings['max_players'] ?? data['maxPlayersPerTeam'] ?? 11).toString()) ?? 11,
 minPlayersPerTeam: int.tryParse((data['min_players_per_team'] ?? settings['minPlayers'] ?? settings['min_players'] ?? data['minPlayersPerTeam'] ?? 5).toString()) ?? 5,
 winningPoints: int.tryParse((data['winning_points'] ?? settings['winningPoints'] ?? settings['winning_points'] ?? data['winningPoints'] ?? 3).toString()) ?? 3,
 drawPoints: int.tryParse((data['draw_points'] ?? settings['drawPoints'] ?? settings['draw_points'] ?? data['drawPoints'] ?? 1).toString()) ?? 1,
 lossPoints: int.tryParse((data['loss_points'] ?? settings['lossPoints'] ?? settings['loss_points'] ?? data['lossPoints'] ?? 0).toString()) ?? 0,
 matchDuration: int.tryParse((data['match_duration'] ?? settings['matchDuration'] ?? settings['match_duration'] ?? data['matchDuration'] ?? 0).toString()) ?? 0,
 isBackAndForth: data['is_back_and_forth'] == true || settings['isBackAndForth'] == true || settings['is_back_and_forth'] == true || data['isBackAndForth'] == true,
 trophyMedals: data['trophy_medals'] != false && settings['trophyMedals'] != false && settings['trophy_medals'] != false && data['trophyMedals'] != false,
 redCardSuspension: data['red_card_suspension'] != false && settings['redCardSuspension'] != false && settings['red_card_suspension'] != false && data['redCardSuspension'] != false,
 fairPlayScoring: data['fair_play_scoring'] == true || settings['fairPlayScoring'] == true || settings['fair_play_scoring'] == true || data['fairPlayScoring'] == true,
 numberOfGroups: int.tryParse((data['number_of_groups'] ?? data['numberOfGroups'] ?? 1).toString()) ?? 1,
 qualifyingPerGroup: int.tryParse((data['qualifying_per_group'] ?? data['qualifyingPerGroup'] ?? 2).toString()) ?? 2,
 isTwoLegs: data['is_two_legs'] == true || data['isTwoLegs'] == true,
 status: data['status']?.toString() ?? 'open',
 championTeamId: data['champion_team_id'] ?? data['championTeamId']?.toString(),
 championTeamName: data['champion_team_name'] ?? data['championTeamName']?.toString(),
 paidTeams: (data['paid_teams'] as List? ?? data['paidTeams'] as List?)?.map((e) => e.toString()).toList() ?? <String>[],
 prizePool: double.tryParse((data['prize_pool'] ?? data['prizePool'] ?? 0).toString()) ?? 0.0,
 prizeDelivered: data['prize_delivered'] == true || data['prizeDelivered'] == true,
 prizeDeliveredAt: data['prize_delivered_at'] != null ? DateTime.tryParse(data['prize_delivered_at'].toString()) : null,
 prizeDeliveredBy: (data['prize_delivered_by'] ?? data['prizeDeliveredBy'])?.toString(),
 prizeDeliveryNotes: (data['prize_delivery_notes'] ?? data['prizeDeliveryNotes'])?.toString(),
 );
 } catch (e) {
 // كود أمان احتياطي لمنع انهيار التطبيق في حال وجود بيانات تالفة
 return Championship(
 id: id,
 name: 'Error Loading',
 type: 'Cup',
 sportType: 'Football',
 logoUrl: '',
 startDate: DateTime.now(),
 endDate: DateTime.now(),
 entryFee: 0,
 grandPrize: 0,
 maxTeams: 16,
 joinedTeams: [],
 ownerId: '',
 governorate: 'Cairo',
 );
 }
 }

 Championship copyWith({
 String? id,
 String? name,
 String? type,
 String? sportType,
 String? logoUrl,
 DateTime? startDate,
 DateTime? endDate,
 double? entryFee,
 double? grandPrize,
 int? maxTeams,
 List<String>? joinedTeams,
 String? ownerId,
 String? governorate,
 String? rules,
 List<String>? paymentMethods,
 int? maxPlayersPerTeam,
 int? minPlayersPerTeam,
 int? winningPoints,
 int? drawPoints,
 int? lossPoints,
 int? matchDuration,
 bool? isBackAndForth,
 bool? trophyMedals,
 bool? redCardSuspension,
 bool? fairPlayScoring,
 int? numberOfGroups,
 int? qualifyingPerGroup,
 bool? isTwoLegs,
 String? status,
 String? championTeamId,
 String? championTeamName,
 List<String>? paidTeams,
 double? prizePool,
 bool? prizeDelivered,
 DateTime? prizeDeliveredAt,
 String? prizeDeliveredBy,
 String? prizeDeliveryNotes,
 }) {
 return Championship(
 id: id ?? this.id,
 name: name ?? this.name,
 type: type ?? this.type,
 sportType: sportType ?? this.sportType,
 logoUrl: logoUrl ?? this.logoUrl,
 startDate: startDate ?? this.startDate,
 endDate: endDate ?? this.endDate,
 entryFee: entryFee ?? this.entryFee,
 grandPrize: grandPrize ?? this.grandPrize,
 maxTeams: maxTeams ?? this.maxTeams,
 joinedTeams: joinedTeams ?? this.joinedTeams,
 ownerId: ownerId ?? this.ownerId,
 governorate: governorate ?? this.governorate,
 rules: rules ?? this.rules,
 paymentMethods: paymentMethods ?? this.paymentMethods,
 maxPlayersPerTeam: maxPlayersPerTeam ?? this.maxPlayersPerTeam,
 minPlayersPerTeam: minPlayersPerTeam ?? this.minPlayersPerTeam,
 winningPoints: winningPoints ?? this.winningPoints,
 drawPoints: drawPoints ?? this.drawPoints,
 lossPoints: lossPoints ?? this.lossPoints,
 matchDuration: matchDuration ?? this.matchDuration,
 isBackAndForth: isBackAndForth ?? this.isBackAndForth,
 trophyMedals: trophyMedals ?? this.trophyMedals,
 redCardSuspension: redCardSuspension ?? this.redCardSuspension,
 fairPlayScoring: fairPlayScoring ?? this.fairPlayScoring,
 numberOfGroups: numberOfGroups ?? this.numberOfGroups,
 qualifyingPerGroup: qualifyingPerGroup ?? this.qualifyingPerGroup,
 isTwoLegs: isTwoLegs ?? this.isTwoLegs,
 status: status ?? this.status,
 championTeamId: championTeamId ?? this.championTeamId,
 championTeamName: championTeamName ?? this.championTeamName,
 paidTeams: paidTeams ?? this.paidTeams,
 prizePool: prizePool ?? this.prizePool,
 prizeDelivered: prizeDelivered ?? this.prizeDelivered,
 prizeDeliveredAt: prizeDeliveredAt ?? this.prizeDeliveredAt,
 prizeDeliveredBy: prizeDeliveredBy ?? this.prizeDeliveredBy,
 prizeDeliveryNotes: prizeDeliveryNotes ?? this.prizeDeliveryNotes,
 );
 }

 Map<String, dynamic> toMap() => toFirestore();

 Map<String, dynamic> toFirestore() {
 return {
 'name': name,
 'name_lowercase': name.toLowerCase(),
 'type': type,
 'sport_type': sportType,
 'sportType': sportType,
 'logo_url': logoUrl,
 'logoUrl': logoUrl,
 'start_date': startDate.toIso8601String(),
 'startDate': startDate.toIso8601String(),
 'end_date': endDate.toIso8601String(),
 'endDate': endDate.toIso8601String(),
 'entry_fee': entryFee,
 'entryFee': entryFee,
 'grand_prize': grandPrize,
 'grandPrize': grandPrize,
 'prize_pool': prizePool,
 'prize_delivered': prizeDelivered,
 'prize_delivered_at': prizeDeliveredAt?.toIso8601String(),
 'prize_delivered_by': prizeDeliveredBy,
 'prize_delivery_notes': prizeDeliveryNotes,
 'max_teams': maxTeams,
 'maxTeams': maxTeams,
 'joined_teams': joinedTeams,
 'joinedTeams': joinedTeams,
 'owner_id': ownerId,
 'ownerId': ownerId,
 'governorate': governorate,
 'rules': rules,
 'payment_methods': paymentMethods,
 'paymentMethods': paymentMethods,
 
 // Flat Columns for Supabase
 'max_players_per_team': maxPlayersPerTeam,
 'min_players_per_team': minPlayersPerTeam,
 'winning_points': winningPoints,
 'draw_points': drawPoints,
 'loss_points': lossPoints,
 'match_duration': matchDuration,
 'is_back_and_forth': isBackAndForth,
 'trophy_medals': trophyMedals,
 'red_card_suspension': redCardSuspension,
 'fair_play_scoring': fairPlayScoring,
 'number_of_groups': numberOfGroups,
 'qualifying_per_group': qualifyingPerGroup,
 'is_two_legs': isTwoLegs,
 
 // Legacy settings field
 'settings': {
 'maxPlayers': maxPlayersPerTeam,
 'minPlayers': minPlayersPerTeam,
 'winningPoints': winningPoints,
 'drawPoints': drawPoints,
 'lossPoints': lossPoints,
 'matchDuration': matchDuration,
 'isBackAndForth': isBackAndForth,
 'trophyMedals': trophyMedals,
 'redCardSuspension': redCardSuspension,
 'fairPlayScoring': fairPlayScoring,
 },
 'status': status,
 'champion_team_id': championTeamId,
 'championTeamId': championTeamId,
 'champion_team_name': championTeamName,
 'championTeamName': championTeamName,
 'paid_teams': paidTeams,
 'paidTeams': paidTeams,
 'created_at': DateTime.now().toUtc().toIso8601String(),
 };
 }

 // Helper for UI
 String get imageUrl => logoUrl;
 int get teamsJoined => joinedTeams.length;
 List<String> get teamLogos => []; // To be implemented with real team data if needed
}
