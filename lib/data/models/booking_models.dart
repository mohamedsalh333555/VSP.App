/// Booking Status Enum
enum BookingStatus {
 pending, // Draft state before payment
 confirmed, // After successful payment, before match starts
 upcoming, // Same as confirmed (alias)
 completed, // After match time has passed
 cancelled, // User/owner cancelled
}

enum MatchResultStatus { noResult, waitingOpponent, confirmed, disputed }

enum MatchOutcome { homeWin, draw, awayWin }
enum MatchResultChoice { weWon, draw, weLost }

/// Booking Type Enum
enum BookingType {
  personal, // Solo/Standard booking (حجز عادي)
  openJoin, // Open gathering match (حجز انضمام وتجميع)
  challenge, // Team challenge match (حجز تحدي فرق)
  team, // Legacy alias for challenge
  matchup, // Matchups mode: Duo or Winner Stays (مواجهات)
}

/// Booking Draft - Used for passing data between screens before final save
class BookingDraft {
 final String stadiumId;
 final String stadiumName;
 final String stadiumImageUrl;
 final String ownerId;

 final DateTime startTime;
 final DateTime endTime;

 final BookingType bookingType;
 final String? playerTeamId;
 final String? playerTeamName;
 final String? opponentTeamId;
 final String? opponentTeamName;
 final String? playerTeamLogoUrl;
 final String? opponentTeamLogoUrl;
 final String? hostName;
 final String? hostAvatarUrl;

 final bool isPrivate;
 final bool rentBall;

 final double totalPrice;
 final String currency;

 final String? paymentMethod;
 final String? paymentTransactionId;
 final int currentPlayers;
 final int playersPerTeam;
 final int totalFieldCapacity;
 final String? playerPhone;
 final String? notes;
 final bool isPaid;
 final double depositPaid;
 final bool isDepositPaid;
 final String? paymentStatus;
 final bool needsDeposit;
 final String? instapay;
 final String? vodafoneCash;
 final String? binanceId;

 // Backward compatibility getter
 int get maxPlayers => totalFieldCapacity;

 BookingDraft({
 required this.stadiumId,
 required this.stadiumName,
 this.stadiumImageUrl = '',
 required this.ownerId,
 required this.startTime,
 required this.endTime,
 required this.bookingType,
 this.playerTeamId,
 this.playerTeamName,
 this.playerTeamLogoUrl,
 this.hostName,
 this.hostAvatarUrl,
 this.opponentTeamId,
 this.opponentTeamName,
 this.opponentTeamLogoUrl,
 required this.isPrivate,
 required this.rentBall,
 required this.totalPrice,
 this.currency = 'EGP',
 this.paymentMethod,
 this.paymentTransactionId,
 this.currentPlayers = 1,
 this.playersPerTeam = 5,
 this.totalFieldCapacity = 10,
 this.playerPhone,
 this.notes,
 this.isPaid = false,
 this.depositPaid = 0.0,
 this.isDepositPaid = false,
 this.paymentStatus,
 this.needsDeposit = false,
 this.instapay,
 this.vodafoneCash,
 this.binanceId,
 });

 BookingDraft copyWith({
 String? stadiumId,
 String? stadiumName,
 String? stadiumImageUrl,
 String? ownerId,
 DateTime? startTime,
 DateTime? endTime,
 BookingType? bookingType,
 String? playerTeamId,
 String? playerTeamName,
 String? playerTeamLogoUrl,
 String? hostName,
 String? hostAvatarUrl,
 String? opponentTeamId,
 String? opponentTeamName,
 String? opponentTeamLogoUrl,
 bool? isPrivate,
 bool? rentBall,
 double? totalPrice,
 String? currency,
 String? paymentMethod,
 String? paymentTransactionId,
 int? currentPlayers,
 int? playersPerTeam,
 int? totalFieldCapacity,
 String? playerPhone,
 String? notes,
 bool? isPaid,
 double? depositPaid,
 bool? isDepositPaid,
 String? paymentStatus,
 bool? needsDeposit,
 String? instapay,
 String? vodafoneCash,
 String? binanceId,
 }) {
 return BookingDraft(
 stadiumId: stadiumId ?? this.stadiumId,
 stadiumName: stadiumName ?? this.stadiumName,
 stadiumImageUrl: stadiumImageUrl ?? this.stadiumImageUrl,
 ownerId: ownerId ?? this.ownerId,
 startTime: startTime ?? this.startTime,
 endTime: endTime ?? this.endTime,
 bookingType: bookingType ?? this.bookingType,
 playerTeamId: playerTeamId ?? this.playerTeamId,
 playerTeamName: playerTeamName ?? this.playerTeamName,
 playerTeamLogoUrl: playerTeamLogoUrl ?? this.playerTeamLogoUrl,
 hostName: hostName ?? this.hostName,
 hostAvatarUrl: hostAvatarUrl ?? this.hostAvatarUrl,
 opponentTeamId: opponentTeamId ?? this.opponentTeamId,
 opponentTeamName: opponentTeamName ?? this.opponentTeamName,
 opponentTeamLogoUrl: opponentTeamLogoUrl ?? this.opponentTeamLogoUrl,
 isPrivate: isPrivate ?? this.isPrivate,
 rentBall: rentBall ?? this.rentBall,
 totalPrice: totalPrice ?? this.totalPrice,
 currency: currency ?? this.currency,
 paymentMethod: paymentMethod ?? this.paymentMethod,
 paymentTransactionId: paymentTransactionId ?? this.paymentTransactionId,
 currentPlayers: currentPlayers ?? this.currentPlayers,
 playersPerTeam: playersPerTeam ?? this.playersPerTeam,
 totalFieldCapacity: totalFieldCapacity ?? this.totalFieldCapacity,
 playerPhone: playerPhone ?? this.playerPhone,
 notes: notes ?? this.notes,
 isPaid: isPaid ?? this.isPaid,
 depositPaid: depositPaid ?? this.depositPaid,
 isDepositPaid: isDepositPaid ?? this.isDepositPaid,
 paymentStatus: paymentStatus ?? this.paymentStatus,
 needsDeposit: needsDeposit ?? this.needsDeposit,
 instapay: instapay ?? this.instapay,
 vodafoneCash: vodafoneCash ?? this.vodafoneCash,
 binanceId: binanceId ?? this.binanceId,
 );
 }

 Map<String, dynamic> toMap() {
 return {
 'stadiumId': stadiumId,
 'stadiumName': stadiumName,
 'stadiumImageUrl': stadiumImageUrl,
 'ownerId': ownerId,
 'startTime': startTime.toIso8601String(),
 'endTime': endTime.toIso8601String(),
 'bookingType': bookingType.name,
 'playerTeamId': playerTeamId,
 'playerTeamName': playerTeamName,
 'playerTeamLogoUrl': playerTeamLogoUrl,
 'hostName': hostName,
 'hostAvatarUrl': hostAvatarUrl,
 'opponentTeamId': opponentTeamId,
 'opponentTeamName': opponentTeamName,
 'opponentTeamLogoUrl': opponentTeamLogoUrl,
 'isPrivate': isPrivate,
 'rentBall': rentBall,
 'totalPrice': totalPrice,
 'currency': currency,
 'paymentMethod': paymentMethod,
 'paymentTransactionId': paymentTransactionId,
 'currentPlayers': currentPlayers,
 'players_per_team': playersPerTeam,
 'total_field_capacity': totalFieldCapacity,
 'max_players': totalFieldCapacity, // backward compatibility key
 'playerPhone': playerPhone,
 'notes': notes,
 'deposit_paid': depositPaid,
 'is_deposit_paid': isDepositPaid,
 'payment_status': paymentStatus,
 'instapay': instapay,
 'vodafoneCash': vodafoneCash,
 'binanceId': binanceId,
 };
 }

 factory BookingDraft.fromMap(Map<String, dynamic> map) {
 BookingType parsedType = BookingType.personal;
 final rawType = map['bookingType']?.toString();
 if (rawType != null) {
 for (final val in BookingType.values) {
 if (val.name == rawType || val.toString() == rawType) {
 parsedType = val;
 break;
 }
 }
 }

 DateTime parsedStart = DateTime.now();
 if (map['startTime'] != null) {
 parsedStart = DateTime.tryParse(map['startTime'].toString()) ?? DateTime.now();
 }

 DateTime parsedEnd = parsedStart.add(const Duration(hours: 1));
 if (map['endTime'] != null) {
 parsedEnd = DateTime.tryParse(map['endTime'].toString()) ?? parsedEnd;
 }

 final rawTotalPrice = map['totalPrice'] ?? 0.0;
 final double parsedTotalPrice = (rawTotalPrice is num) ? rawTotalPrice.toDouble() : (double.tryParse(rawTotalPrice.toString()) ?? 0.0);

 final rawDeposit = map['deposit_paid'] ?? map['depositPaid'] ?? 0.0;
 final double parsedDeposit = (rawDeposit is num) ? rawDeposit.toDouble() : (double.tryParse(rawDeposit.toString()) ?? 0.0);

 final int ppt = map['players_per_team'] ?? map['playersPerTeam'] ?? 5;
 final int tfc = map['total_field_capacity'] ?? map['totalFieldCapacity'] ?? map['max_players'] ?? (ppt * 2);

 return BookingDraft(
 stadiumId: map['stadiumId']?.toString() ?? '',
 stadiumName: map['stadiumName']?.toString() ?? '',
 stadiumImageUrl: map['stadiumImageUrl']?.toString() ?? '',
 ownerId: map['ownerId']?.toString() ?? '',
 startTime: parsedStart,
 endTime: parsedEnd,
 bookingType: parsedType,
 playerTeamId: map['playerTeamId']?.toString(),
 playerTeamName: map['playerTeamName']?.toString(),
 playerTeamLogoUrl: map['playerTeamLogoUrl']?.toString(),
 hostName: map['hostName']?.toString(),
 hostAvatarUrl: map['hostAvatarUrl']?.toString(),
 opponentTeamId: map['opponentTeamId']?.toString(),
 opponentTeamName: map['opponentTeamName']?.toString(),
 opponentTeamLogoUrl: map['opponentTeamLogoUrl']?.toString(),
 isPrivate: map['isPrivate'] == true,
 rentBall: map['rentBall'] == true,
 totalPrice: parsedTotalPrice,
 currency: map['currency']?.toString() ?? 'EGP',
 paymentMethod: map['paymentMethod']?.toString(),
 paymentTransactionId: map['paymentTransactionId']?.toString(),
 currentPlayers: map['currentPlayers'] is int ? map['currentPlayers'] : (int.tryParse(map['currentPlayers']?.toString() ?? '') ?? 1),
 playersPerTeam: ppt,
 totalFieldCapacity: tfc,
 playerPhone: map['playerPhone']?.toString(),
 notes: map['notes']?.toString(),
 isPaid: map['isPaid'] == true,
 depositPaid: parsedDeposit,
 isDepositPaid: map['is_deposit_paid'] == true || map['isDepositPaid'] == true,
 paymentStatus: map['payment_status']?.toString() ?? map['paymentStatus']?.toString(),
 needsDeposit: map['needs_deposit'] == true || map['needsDeposit'] == true,
 instapay: map['instapay']?.toString(),
 vodafoneCash: map['vodafoneCash']?.toString(),
 binanceId: map['binanceId']?.toString(),
 );
 }
}

/// Booking data model - Full booking record stored in DB
class Booking {
 final String id;
 
 // Stadium info
 final String stadiumId;
 final String stadiumName;
 final String stadiumImageUrl;
 final String ownerId;

 // Timing
 final DateTime startTime;
 final DateTime endTime;
 final DateTime? operationalDate;

 // Booking type
 final BookingType bookingType;
 final String? playerTeamId;
 final String? playerTeamName;
 final String? playerTeamLogoUrl;
 final String? hostName;
 final String? hostAvatarUrl;
 final String? opponentTeamId;
 final String? opponentTeamName;
 final String? opponentTeamLogoUrl;

 // Options
 final bool isPrivate;
 final bool rentBall;

 // Payment
 final double totalPrice;
 final String currency;
 final String paymentMethod;
 final String? paymentTransactionId;

 // Status & Metadata
 final BookingStatus status;
 final String createdByUserId;
 final DateTime createdAt;
 final DateTime? updatedAt;
 final String? playerPhone;
 final String? notes;

 // Match Result (for Challenge bookings)
 final int? homeScore;
 final int? awayScore;
 final String? resultSubmittedByTeamId;
 final MatchResultStatus matchResultStatus;
 final MatchOutcome? pendingOutcome;
 final MatchOutcome? finalOutcome;
 final bool requiresAdminIntervention;

 // Public Match Fields
 final int currentPlayers;
 final int playersPerTeam;
 final int totalFieldCapacity;
 final List<String> joinedUserIds;
 final List<String> pendingUserIds;

 // Financial Detail (Debt Management)
 final bool isPaid;
 final String paymentStatus; // 'pending', 'paid', 'refunded'
 final double depositPaid;
 final bool isDepositPaid;
 final String? instapay;
 final String? vodafoneCash;
 final String? binanceId;
 final String? lastMessage;
 final DateTime? lastMessageTime;

 // Emergency Cancellation & Rescheduling Fields
 final String rescheduleStatus; // 'none', 'pending', 'accepted', 'rejected'
 final DateTime? proposedStartTime;
 final DateTime? proposedEndTime;
 final String emergencyCancelStatus; // 'none', 'pending_admin_approval', 'approved', 'rejected'
 final String? emergencyReason;
 final int? emergencyDowntimeHours;

 // Backward compatibility getters
 int get maxPlayers => totalFieldCapacity;
 String get userId => createdByUserId;

 Booking({
 required this.id,
 required this.stadiumId,
 required this.stadiumName,
 this.stadiumImageUrl = '',
 required this.ownerId,
 required this.startTime,
 required this.endTime,
 this.operationalDate,
 required this.bookingType,
 this.playerTeamId,
 this.playerTeamName,
 this.playerTeamLogoUrl,
 this.hostName,
 this.hostAvatarUrl,
 this.opponentTeamId,
 this.opponentTeamName,
 this.opponentTeamLogoUrl,
 required this.isPrivate,
 required this.rentBall,
 required this.totalPrice,
 this.currency = 'EGP',
 required this.paymentMethod,
 this.paymentTransactionId,
 required this.status,
 required this.createdByUserId,
 required this.createdAt,
 this.updatedAt,
 this.homeScore,
 this.awayScore,
 this.resultSubmittedByTeamId,
 this.matchResultStatus = MatchResultStatus.noResult,
 this.pendingOutcome,
 this.finalOutcome,
 this.requiresAdminIntervention = false,
 this.currentPlayers = 1,
 this.playersPerTeam = 5,
 this.totalFieldCapacity = 10,
 this.joinedUserIds = const [],
 this.pendingUserIds = const [],
 this.isPaid = false,
 this.paymentStatus = 'pending',
 this.playerPhone,
 this.notes,
 this.depositPaid = 0.0,
 this.isDepositPaid = false,
 this.instapay,
 this.vodafoneCash,
 this.binanceId,
 this.lastMessage,
 this.lastMessageTime,
 this.rescheduleStatus = 'none',
 this.proposedStartTime,
 this.proposedEndTime,
 this.emergencyCancelStatus = 'none',
 this.emergencyReason,
 this.emergencyDowntimeHours,
 });

 /// Create Booking from Firestore/Supabase document
 factory Booking.fromMap(Map<String, dynamic> data, [String? id]) =>
 Booking.fromFirestore(data, id ?? (data['id']?.toString() ?? ''));

 factory Booking.fromFirestore(Map<String, dynamic> data, String id) {
 final startTimeVal = data['startTime'] ?? data['start_time'];
 final endTimeVal = data['endTime'] ?? data['end_time'];
 final opDateVal = data['operationalDate'] ?? data['operational_date'];
 final createdAtVal = data['createdAt'] ?? data['created_at'];
 final updatedAtVal = data['updatedAt'] ?? data['updated_at'];
 final bookingTypeVal = data['bookingType'] ?? data['booking_type'];
 final statusVal = data['status'];
 final matchResultStatusVal = data['matchResultStatus'] ?? data['match_result_status'];
 final pendingOutcomeVal = data['pendingOutcome'] ?? data['pending_outcome'];
 final finalOutcomeVal = data['finalOutcome'] ?? data['final_outcome'];

 final int ppt = data['players_per_team'] ?? data['playersPerTeam'] ?? 5;
 final int tfc = data['total_field_capacity'] ?? data['totalFieldCapacity'] ?? data['maxPlayers'] ?? data['max_players'] ?? (ppt * 2);

 return Booking(
 id: id,
 stadiumId: data['stadiumId'] ?? data['stadium_id'] ?? '',
 stadiumName: data['stadiumName'] ?? data['stadium_name'] ?? '',
 stadiumImageUrl: data['stadiumImageUrl'] ?? data['stadium_image_url'] ?? '',
 ownerId: data['ownerId'] ?? data['owner_id'] ?? '',
 startTime: startTimeVal != null 
 ? (startTimeVal is DateTime 
 ? startTimeVal.toLocal() 
 : DateTime.parse(startTimeVal.toString()).toLocal())
 : DateTime.now(),
 endTime: endTimeVal != null 
 ? (endTimeVal is DateTime 
 ? endTimeVal.toLocal() 
 : DateTime.parse(endTimeVal.toString()).toLocal())
 : DateTime.now(),
 operationalDate: opDateVal != null
 ? (opDateVal is DateTime
 ? opDateVal
 : DateTime.tryParse(opDateVal.toString()))
 : null,
 bookingType: () {
 final val = bookingTypeVal?.toString().toLowerCase().replaceAll('_', '').replaceAll(' ', '') ?? '';
 if (val == 'openjoin' || val == 'openjoinmatch') return BookingType.openJoin;
 if (val == 'challenge' || val == 'challengematch') return BookingType.challenge;
 if (val == 'team') return BookingType.team;
 if (val == 'matchup' || val == 'matchups') return BookingType.matchup;
 return BookingType.personal;
 }(),
 playerTeamId: data['playerTeamId'] ?? data['player_team_id'],
 playerTeamName: data['playerTeamName'] ?? data['player_team_name'],
 playerTeamLogoUrl: data['playerTeamLogoUrl'] ?? data['player_team_logo_url'],
 hostName: data['hostName'] ?? data['host_name'],
 hostAvatarUrl: data['hostAvatarUrl'] ?? data['host_avatar_url'],
 opponentTeamId: (bookingTypeVal == 'challenge') ? (data['opponentTeamId'] ?? data['opponent_team_id']) : null,
 opponentTeamName: (bookingTypeVal == 'challenge') ? (data['opponentTeamName'] ?? data['opponent_team_name']) : null,
 opponentTeamLogoUrl: data['opponentTeamLogoUrl'] ?? data['opponent_team_logo_url'],
 isPrivate: data['isPrivate'] ?? data['is_private'] ?? false,
 rentBall: data['rentBall'] ?? data['rent_ball'] ?? false,
 totalPrice: (data['totalPrice'] ?? data['total_price'] ?? 0).toDouble(),
 currency: data['currency'] ?? 'EGP',
 paymentMethod: data['paymentMethod'] ?? data['payment_method'] ?? 'card',
 paymentTransactionId: data['paymentTransactionId'] ?? data['payment_transaction_id'],
 status: BookingStatus.values.firstWhere(
 (e) => e.name == statusVal,
 orElse: () => BookingStatus.pending,
 ),
 createdByUserId: data['createdByUserId'] ?? data['created_by_user_id'] ?? data['user_id'] ?? '',
 createdAt: createdAtVal != null 
 ? (createdAtVal is DateTime 
 ? createdAtVal.toLocal() 
 : DateTime.parse(createdAtVal.toString()).toLocal())
 : DateTime.now(),
 updatedAt: updatedAtVal != null 
 ? (updatedAtVal is DateTime 
 ? updatedAtVal.toLocal() 
 : DateTime.parse(updatedAtVal.toString()).toLocal())
 : null,
 homeScore: data['homeScore'] ?? data['home_score'],
 awayScore: data['awayScore'] ?? data['away_score'],
 resultSubmittedByTeamId: data['resultSubmittedByTeamId'] ?? data['result_submitted_by_team_id'],
 matchResultStatus: MatchResultStatus.values.firstWhere(
 (e) => e.name == matchResultStatusVal,
 orElse: () => MatchResultStatus.noResult,
 ),
 pendingOutcome: pendingOutcomeVal != null 
 ? MatchOutcome.values.firstWhere((e) => e.name == pendingOutcomeVal) 
 : null,
 finalOutcome: finalOutcomeVal != null 
 ? MatchOutcome.values.firstWhere((e) => e.name == finalOutcomeVal) 
 : null,
 requiresAdminIntervention: data['requiresAdminIntervention'] ?? data['requires_admin_intervention'] ?? false,
 currentPlayers: data['currentPlayers'] ?? data['current_players'] ?? 1,
 playersPerTeam: ppt,
 totalFieldCapacity: tfc,
 pendingUserIds: (data['pendingUserIds'] ?? data['pending_user_ids']) is List ? ((data['pendingUserIds'] ?? data['pending_user_ids']) as List).map((e) => e.toString()).toList() : [],
 joinedUserIds: (data['joinedUserIds'] ?? data['joined_user_ids']) is List
 ? ((data['joinedUserIds'] ?? data['joined_user_ids']) as List)
 .map((e) => e.toString())
 .toList()
 : [],
 isPaid: data['isPaid'] ?? data['is_paid'] ?? false,
 paymentStatus: data['paymentStatus'] ?? data['payment_status'] ?? ((data['isPaid'] ?? data['is_paid']) == true ? 'paid' : 'pending'),
 playerPhone: data['playerPhone'] ?? data['player_phone'],
 notes: data['notes'],
 depositPaid: (data['deposit_paid'] ?? data['depositPaid'] ?? 0.0).toDouble(),
 isDepositPaid: data['is_deposit_paid'] ?? data['isDepositPaid'] ?? false,
 instapay: data['instapay'] ?? data['insta_pay'],
 vodafoneCash: data['vodafoneCash'] ?? data['vodafone_cash'],
 binanceId: data['binanceId'] ?? data['binance_id'],
 lastMessage: data['last_message'] ?? data['lastMessage'],
 lastMessageTime: (data['last_message_time'] ?? data['lastMessageTime']) != null 
 ? DateTime.parse((data['last_message_time'] ?? data['lastMessageTime']).toString())
 : null,
 rescheduleStatus: data['reschedule_status'] ?? data['rescheduleStatus'] ?? 'none',
 proposedStartTime: (data['proposed_start_time'] ?? data['proposedStartTime']) != null
 ? DateTime.parse((data['proposed_start_time'] ?? data['proposedStartTime']).toString())
 : null,
 proposedEndTime: (data['proposed_end_time'] ?? data['proposedEndTime']) != null
 ? DateTime.parse((data['proposed_end_time'] ?? data['proposedEndTime']).toString())
 : null,
 emergencyCancelStatus: data['emergency_cancel_status'] ?? data['emergencyCancelStatus'] ?? 'none',
 emergencyReason: data['emergency_reason'] ?? data['emergencyReason'],
 emergencyDowntimeHours: data['emergency_downtime_hours'] ?? data['emergencyDowntimeHours'],
 );
 }

 Map<String, dynamic> toMap() => toFirestore();

 /// Convert Booking to Firestore map
 Map<String, dynamic> toFirestore() {
 return {
 'stadium_id': stadiumId,
 'stadiumId': stadiumId,
 'stadium_name': stadiumName,
 'stadiumName': stadiumName,
 'stadium_image_url': stadiumImageUrl,
 'stadiumImageUrl': stadiumImageUrl,
 'owner_id': ownerId,
 'ownerId': ownerId,
 'start_time': startTime.toIso8601String(),
 'startTime': startTime.toIso8601String(),
 'end_time': endTime.toIso8601String(),
 'endTime': endTime.toIso8601String(),
 'operational_date': operationalDate?.toIso8601String().split('T').first,
 'booking_type': bookingType.name,
 'bookingType': bookingType.name,
 'player_team_id': playerTeamId,
 'playerTeamId': playerTeamId,
 'player_team_name': playerTeamName,
 'playerTeamName': playerTeamName,
 'player_team_logo_url': playerTeamLogoUrl,
 'playerTeamLogoUrl': playerTeamLogoUrl,
 'host_name': hostName,
 'hostName': hostName,
 'host_avatar_url': hostAvatarUrl,
 'hostAvatarUrl': hostAvatarUrl,
 'opponent_team_id': opponentTeamId,
 'opponentTeamId': opponentTeamId,
 'opponent_team_name': opponentTeamName,
 'opponentTeamName': opponentTeamName,
 'opponent_team_logo_url': opponentTeamLogoUrl,
 'opponentTeamLogoUrl': opponentTeamLogoUrl,
 'is_private': isPrivate,
 'isPrivate': isPrivate,
 'rent_ball': rentBall,
 'rentBall': rentBall,
 'total_price': totalPrice,
 'totalPrice': totalPrice,
 'currency': currency,
 'payment_method': paymentMethod,
 'paymentMethod': paymentMethod,
 'payment_transaction_id': paymentTransactionId,
 'paymentTransactionId': paymentTransactionId,
 'status': status.name,
 'created_by_user_id': createdByUserId,
 'createdByUserId': createdByUserId,
 'created_at': createdAt.toIso8601String(),
 'createdAt': createdAt.toIso8601String(),
 'updated_at': updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
 'updatedAt': updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
 'home_score': homeScore,
 'homeScore': homeScore,
 'away_score': awayScore,
 'awayScore': awayScore,
 'result_submitted_by_team_id': resultSubmittedByTeamId,
 'resultSubmittedByTeamId': resultSubmittedByTeamId,
 'match_result_status': matchResultStatus.name,
 'matchResultStatus': matchResultStatus.name,
 'pending_outcome': pendingOutcome?.name,
 'pendingOutcome': pendingOutcome?.name,
 'final_outcome': finalOutcome?.name,
 'finalOutcome': finalOutcome?.name,
 'requires_admin_intervention': requiresAdminIntervention,
 'requiresAdminIntervention': requiresAdminIntervention,
 'current_players': currentPlayers,
 'players_per_team': playersPerTeam,
 'total_field_capacity': totalFieldCapacity,
 'max_players': totalFieldCapacity, // backward compatibility
 'joined_user_ids': joinedUserIds,
 'joinedUserIds': joinedUserIds,
 'pending_user_ids': pendingUserIds,
 'pendingUserIds': pendingUserIds,
 'is_paid': isPaid,
 'isPaid': isPaid,
 'payment_status': paymentStatus,
 'paymentStatus': paymentStatus,
 'player_phone': playerPhone,
 'playerPhone': playerPhone,
 'notes': notes,
 'deposit_paid': depositPaid,
 'is_deposit_paid': isDepositPaid,
 'instapay': instapay,
 'vodafone_cash': vodafoneCash,
 'vodafoneCash': vodafoneCash,
 'binance_id': binanceId,
 'binanceId': binanceId,
 'last_message': lastMessage,
 'last_message_time': lastMessageTime?.toUtc().toIso8601String(),
 };
 }

 /// Create Booking from BookingDraft (after payment success)
 factory Booking.fromDraft({
 required String id,
 required BookingDraft draft,
 required String userId,
 required BookingStatus status,
 }) {
 return Booking(
 id: id,
 stadiumId: draft.stadiumId,
 stadiumName: draft.stadiumName,
 stadiumImageUrl: draft.stadiumImageUrl,
 ownerId: draft.ownerId,
 startTime: draft.startTime,
 endTime: draft.endTime,
 bookingType: draft.bookingType,
 playerTeamId: draft.playerTeamId,
 playerTeamName: draft.playerTeamName,
 playerTeamLogoUrl: draft.playerTeamLogoUrl,
 hostName: draft.hostName,
 hostAvatarUrl: draft.hostAvatarUrl,
 opponentTeamId: draft.opponentTeamId,
 opponentTeamName: draft.opponentTeamName,
 opponentTeamLogoUrl: draft.opponentTeamLogoUrl,
 isPrivate: draft.isPrivate,
 rentBall: draft.rentBall,
 totalPrice: draft.totalPrice,
 currency: draft.currency,
 paymentMethod: draft.paymentMethod ?? 'cash', // Cash-only MVP default
 paymentTransactionId: draft.paymentTransactionId,
 status: status,
 createdByUserId: userId,
 createdAt: DateTime.now(),
 currentPlayers: draft.currentPlayers,
 playersPerTeam: draft.playersPerTeam,
 totalFieldCapacity: draft.totalFieldCapacity,
 joinedUserIds: [userId],
 playerPhone: draft.playerPhone,
 notes: draft.notes,
 isPaid: draft.isPaid,
 depositPaid: draft.depositPaid,
 isDepositPaid: draft.isDepositPaid,
 paymentStatus: draft.paymentStatus ?? (draft.isPaid ? 'paid' : (draft.isDepositPaid ? 'partially_paid' : 'pending')),
 instapay: draft.instapay,
 vodafoneCash: draft.vodafoneCash,
 binanceId: draft.binanceId,
 );
 }

 Booking copyWith({
 String? id,
 String? stadiumId,
 String? stadiumName,
 String? stadiumImageUrl,
 String? ownerId,
 DateTime? startTime,
 DateTime? endTime,
 BookingType? bookingType,
 String? playerTeamId,
 String? playerTeamName,
 String? playerTeamLogoUrl,
 String? opponentTeamId,
 String? opponentTeamName,
 String? opponentTeamLogoUrl,
 bool? isPrivate,
 bool? rentBall,
 double? totalPrice,
 String? currency,
 String? paymentMethod,
 String? paymentTransactionId,
 BookingStatus? status,
 String? createdByUserId,
 DateTime? createdAt,
 DateTime? updatedAt,
 int? homeScore,
 int? awayScore,
 String? resultSubmittedByTeamId,
 MatchResultStatus? matchResultStatus,
 MatchOutcome? pendingOutcome,
 MatchOutcome? finalOutcome,
 bool? requiresAdminIntervention,
 int? currentPlayers,
 int? playersPerTeam,
 int? totalFieldCapacity,
 List<String>? joinedUserIds,
 bool? isPaid,
 String? paymentStatus,
 double? depositPaid,
 bool? isDepositPaid,
 String? instapay,
 String? vodafoneCash,
 String? binanceId,
 }) {
 return Booking(
 id: id ?? this.id,
 stadiumId: stadiumId ?? this.stadiumId,
 stadiumName: stadiumName ?? this.stadiumName,
 stadiumImageUrl: stadiumImageUrl ?? this.stadiumImageUrl,
 ownerId: ownerId ?? this.ownerId,
 startTime: startTime ?? this.startTime,
 endTime: endTime ?? this.endTime,
 bookingType: bookingType ?? this.bookingType,
 playerTeamId: playerTeamId ?? this.playerTeamId,
 playerTeamName: playerTeamName ?? this.playerTeamName,
 playerTeamLogoUrl: playerTeamLogoUrl ?? this.playerTeamLogoUrl,
 opponentTeamId: opponentTeamId ?? this.opponentTeamId,
 opponentTeamName: opponentTeamName ?? this.opponentTeamName,
 opponentTeamLogoUrl: opponentTeamLogoUrl ?? this.opponentTeamLogoUrl,
 isPrivate: isPrivate ?? this.isPrivate,
 rentBall: rentBall ?? this.rentBall,
 totalPrice: totalPrice ?? this.totalPrice,
 currency: currency ?? this.currency,
 paymentMethod: paymentMethod ?? this.paymentMethod,
 paymentTransactionId: paymentTransactionId ?? this.paymentTransactionId,
 status: status ?? this.status,
 createdByUserId: createdByUserId ?? this.createdByUserId,
 createdAt: createdAt ?? this.createdAt,
 updatedAt: updatedAt ?? this.updatedAt,
 homeScore: homeScore ?? this.homeScore,
 awayScore: awayScore ?? this.awayScore,
 resultSubmittedByTeamId: resultSubmittedByTeamId ?? this.resultSubmittedByTeamId,
 matchResultStatus: matchResultStatus ?? this.matchResultStatus,
 pendingOutcome: pendingOutcome ?? this.pendingOutcome,
 finalOutcome: finalOutcome ?? this.finalOutcome,
 requiresAdminIntervention: requiresAdminIntervention ?? this.requiresAdminIntervention,
 currentPlayers: currentPlayers ?? this.currentPlayers,
 playersPerTeam: playersPerTeam ?? this.playersPerTeam,
 totalFieldCapacity: totalFieldCapacity ?? this.totalFieldCapacity,
 joinedUserIds: joinedUserIds ?? this.joinedUserIds,
 isPaid: isPaid ?? this.isPaid,
 paymentStatus: paymentStatus ?? this.paymentStatus,
 depositPaid: depositPaid ?? this.depositPaid,
 isDepositPaid: isDepositPaid ?? this.isDepositPaid,
 instapay: instapay ?? this.instapay,
 vodafoneCash: vodafoneCash ?? this.vodafoneCash,
 binanceId: binanceId ?? this.binanceId,
 );
 }

 /// Check if booking is upcoming
 bool get isUpcoming => 
 status == BookingStatus.confirmed && 
 startTime.isAfter(DateTime.now());

 /// Check if booking is completed
 bool get isCompleted => 
 status == BookingStatus.completed || 
 endTime.isBefore(DateTime.now());

 /// Get formatted date string
 String get formattedDate {
 final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
 return '${months[startTime.month - 1]} ${startTime.day}';
 }

 /// Get formatted time range (12-hour format with AM/PM)
 String get formattedTimeRange {
 String formatTime(DateTime dt) {
 final int rawHour = dt.hour;
 final int hour = rawHour == 0 ? 12 : (rawHour > 12 ? rawHour - 12 : rawHour);
 final String period = rawHour >= 12 ? 'PM' : 'AM';
 return '$hour:${dt.minute.toString().padLeft(2, '0')} $period';
 }
 return '${formatTime(startTime)} - ${formatTime(endTime)}';
 }
}


/// Team data model
