export 'booking_enums.dart';
export 'booking_draft.dart';
export 'booking_mapper.dart';

import 'booking_enums.dart';
import 'booking_draft.dart';
import 'booking_mapper.dart';

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

  factory Booking.fromFirestore(Map<String, dynamic> data, String id) =>
      BookingMapper.fromFirestore(data, id);

  Map<String, dynamic> toMap() => toFirestore();

  /// Convert Booking to Firestore map
  Map<String, dynamic> toFirestore() => BookingMapper.toFirestore(this);

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
