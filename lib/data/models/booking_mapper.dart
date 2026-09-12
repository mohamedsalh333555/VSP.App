import 'booking_enums.dart';
import 'booking_models.dart';

/// Handles Firestore and Supabase map serialization and deserialization for Booking instances.
class BookingMapper {
  const BookingMapper._();

  /// Deserializes database record map into a strongly typed Booking object.
  static Booking fromFirestore(Map<String, dynamic> data, String id) {
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
      refundAmount: (data['refund_amount'] ?? data['refundAmount'] as num?)?.toDouble(),
      refundTransactionId: (data['refund_transaction_id'] ?? data['refundTransactionId'] ?? data['refund_txn_id'])?.toString(),
      refundedAt: (data['refunded_at'] ?? data['refundedAt']) != null
          ? ((data['refunded_at'] ?? data['refundedAt']) is DateTime
              ? ((data['refunded_at'] ?? data['refundedAt']) as DateTime).toLocal()
              : DateTime.tryParse((data['refunded_at'] ?? data['refundedAt']).toString())?.toLocal())
          : null,
      refundPaymentMethod: (data['refund_payment_method'] ?? data['refundPaymentMethod'])?.toString(),
      refundChannel: (data['refund_channel'] ?? data['refundChannel'])?.toString(),
      refundEta: (data['refund_eta'] ?? data['refundEta'])?.toString(),
      displayRefundRef: (data['display_refund_ref'] ?? data['displayRefundRef'])?.toString(),
    );
  }

  /// Serializes Booking instance into Firestore/Supabase schema map.
  static Map<String, dynamic> toFirestore(Booking booking) {
    return {
      'stadium_id': booking.stadiumId,
      'stadiumId': booking.stadiumId,
      'stadium_name': booking.stadiumName,
      'stadiumName': booking.stadiumName,
      'stadium_image_url': booking.stadiumImageUrl,
      'stadiumImageUrl': booking.stadiumImageUrl,
      'owner_id': booking.ownerId,
      'ownerId': booking.ownerId,
      'start_time': booking.startTime.toIso8601String(),
      'startTime': booking.startTime.toIso8601String(),
      'end_time': booking.endTime.toIso8601String(),
      'endTime': booking.endTime.toIso8601String(),
      'operational_date': booking.operationalDate?.toIso8601String().split('T').first,
      'booking_type': booking.bookingType.name,
      'bookingType': booking.bookingType.name,
      'player_team_id': booking.playerTeamId,
      'playerTeamId': booking.playerTeamId,
      'player_team_name': booking.playerTeamName,
      'playerTeamName': booking.playerTeamName,
      'player_team_logo_url': booking.playerTeamLogoUrl,
      'playerTeamLogoUrl': booking.playerTeamLogoUrl,
      'host_name': booking.hostName,
      'hostName': booking.hostName,
      'host_avatar_url': booking.hostAvatarUrl,
      'hostAvatarUrl': booking.hostAvatarUrl,
      'opponent_team_id': booking.opponentTeamId,
      'opponentTeamId': booking.opponentTeamId,
      'opponent_team_name': booking.opponentTeamName,
      'opponentTeamName': booking.opponentTeamName,
      'opponent_team_logo_url': booking.opponentTeamLogoUrl,
      'opponentTeamLogoUrl': booking.opponentTeamLogoUrl,
      'is_private': booking.isPrivate,
      'isPrivate': booking.isPrivate,
      'rent_ball': booking.rentBall,
      'rentBall': booking.rentBall,
      'total_price': booking.totalPrice,
      'totalPrice': booking.totalPrice,
      'currency': booking.currency,
      'payment_method': booking.paymentMethod,
      'paymentMethod': booking.paymentMethod,
      'payment_transaction_id': booking.paymentTransactionId,
      'paymentTransactionId': booking.paymentTransactionId,
      'status': booking.status.name,
      'created_by_user_id': booking.createdByUserId,
      'createdByUserId': booking.createdByUserId,
      'created_at': booking.createdAt.toIso8601String(),
      'createdAt': booking.createdAt.toIso8601String(),
      'updated_at': booking.updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updatedAt': booking.updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'home_score': booking.homeScore,
      'homeScore': booking.homeScore,
      'away_score': booking.awayScore,
      'awayScore': booking.awayScore,
      'result_submitted_by_team_id': booking.resultSubmittedByTeamId,
      'resultSubmittedByTeamId': booking.resultSubmittedByTeamId,
      'match_result_status': booking.matchResultStatus.name,
      'matchResultStatus': booking.matchResultStatus.name,
      'pending_outcome': booking.pendingOutcome?.name,
      'pendingOutcome': booking.pendingOutcome?.name,
      'final_outcome': booking.finalOutcome?.name,
      'finalOutcome': booking.finalOutcome?.name,
      'requires_admin_intervention': booking.requiresAdminIntervention,
      'requiresAdminIntervention': booking.requiresAdminIntervention,
      'current_players': booking.currentPlayers,
      'players_per_team': booking.playersPerTeam,
      'total_field_capacity': booking.totalFieldCapacity,
      'max_players': booking.totalFieldCapacity,
      'joined_user_ids': booking.joinedUserIds,
      'joinedUserIds': booking.joinedUserIds,
      'pending_user_ids': booking.pendingUserIds,
      'pendingUserIds': booking.pendingUserIds,
      'is_paid': booking.isPaid,
      'isPaid': booking.isPaid,
      'payment_status': booking.paymentStatus,
      'paymentStatus': booking.paymentStatus,
      'player_phone': booking.playerPhone,
      'playerPhone': booking.playerPhone,
      'notes': booking.notes,
      'deposit_paid': booking.depositPaid,
      'is_deposit_paid': booking.isDepositPaid,
      'instapay': booking.instapay,
      'vodafone_cash': booking.vodafoneCash,
      'vodafoneCash': booking.vodafoneCash,
      'binance_id': booking.binanceId,
      'binanceId': booking.binanceId,
      'last_message': booking.lastMessage,
      'last_message_time': booking.lastMessageTime?.toUtc().toIso8601String(),
      if (booking.refundAmount != null) 'refund_amount': booking.refundAmount,
      if (booking.refundTransactionId != null) 'refund_transaction_id': booking.refundTransactionId,
      if (booking.refundedAt != null) 'refunded_at': booking.refundedAt?.toUtc().toIso8601String(),
      if (booking.refundPaymentMethod != null) 'refund_payment_method': booking.refundPaymentMethod,
    };
  }
}
