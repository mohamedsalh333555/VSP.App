import 'booking_enums.dart';

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
  final String? challengeCode;
  final String? idempotencyKey;

  /// Local draft validation. Server must independently validate prices,
  /// availability, identity and booking permissions before persisting.
  List<String> validate() {
    final errors = <String>[];
    if (stadiumId.trim().isEmpty) errors.add('stadiumId');
    if (ownerId.trim().isEmpty) errors.add('ownerId');
    if (!endTime.isAfter(startTime)) errors.add('timeRange');
    if (!totalPrice.isFinite || totalPrice < 0) errors.add('totalPrice');
    if (!depositPaid.isFinite || depositPaid < 0) errors.add('depositPaid');
    if (depositPaid > totalPrice) errors.add('depositExceedsTotal');
    if (playersPerTeam <= 0) errors.add('playersPerTeam');
    if (totalFieldCapacity <= 0) errors.add('totalFieldCapacity');
    if (currentPlayers < 0 || currentPlayers > totalFieldCapacity) {
      errors.add('currentPlayers');
    }
    return errors;
  }

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
    this.challengeCode,
    this.idempotencyKey,
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
    String? challengeCode,
    String? idempotencyKey,
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
      challengeCode: challengeCode ?? this.challengeCode,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    );
  }

  /// Use this at submission boundaries to reject invalid drafts before
  /// serialization. The server must still enforce its own invariants.
  Map<String, dynamic> toValidatedMap() {
    final errors = validate();
    if (errors.isNotEmpty) {
      throw FormatException('Invalid booking draft: ${errors.join(', ')}');
    }
    return toMap();
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
      'isPaid': isPaid,
      'deposit_paid': depositPaid,
      'is_deposit_paid': isDepositPaid,
      'payment_status': paymentStatus,
      'needs_deposit': needsDeposit,
      'instapay': instapay,
      'vodafoneCash': vodafoneCash,
      'binanceId': binanceId,
      'challengeCode': challengeCode,
      'idempotencyKey': idempotencyKey,
    };
  }

  factory BookingDraft.fromMap(Map<String, dynamic> map) {
    BookingType parsedType = BookingType.personal;
    final rawType = map['bookingType'] ?? map['booking_type'];
    if (rawType != null) {
      final normalized = rawType.toString().toLowerCase()
          .replaceAll('bookingtype.', '')
          .replaceAll('_', '')
          .replaceAll('-', '')
          .replaceAll(' ', '');
      final matches = BookingType.values.where(
        (value) => value.name.toLowerCase() == normalized,
      );
      if (matches.isNotEmpty) {
        parsedType = matches.first;
      } else if (normalized == 'openjoinmatch') {
        parsedType = BookingType.openJoin;
      } else if (normalized == 'challengematch') {
        parsedType = BookingType.challenge;
      } else {
        // Never turn an unrecognized challenge/team booking into a personal
        // booking when restoring a saved draft.
        throw FormatException('Unknown booking type: $rawType');
      }
    }

    // A restored draft must never silently become a booking for "now".
    // Missing or malformed timestamps require the user to select a slot again.
    DateTime parseRequiredTime(String key) {
      final value = map[key];
      if (value is DateTime) return value;
      if (value == null) {
        throw FormatException('Booking draft is missing $key');
      }
      final parsed = DateTime.tryParse(value.toString());
      if (parsed == null) {
        throw FormatException('Booking draft has invalid $key');
      }
      return parsed;
    }

    final parsedStart = parseRequiredTime('startTime');
    final parsedEnd = parseRequiredTime('endTime');
    if (!parsedEnd.isAfter(parsedStart)) {
      throw const FormatException('Booking draft has an invalid time range');
    }

    double parseAmount(dynamic value, double fallback, String field) {
      if (value == null) return fallback;
      final amount = value is num
          ? value.toDouble()
          : double.tryParse(value.toString().trim());
      if (amount == null || !amount.isFinite || amount < 0) {
        throw FormatException('Booking draft has invalid $field');
      }
      return amount;
    }

    final parsedTotalPrice = parseAmount(
      map['totalPrice'], 0, 'totalPrice',
    );
    final parsedDeposit = parseAmount(
      map['deposit_paid'] ?? map['depositPaid'], 0, 'depositPaid',
    );

    int parseCount(dynamic value, int fallback) {
      if (value is int) return value;
      if (value is num) {
        final number = value.toDouble();
        return number.isFinite ? number.toInt() : fallback;
      }
      return int.tryParse(value?.toString().trim() ?? '') ?? fallback;
    }

    final int ppt = parseCount(
      map['players_per_team'] ?? map['playersPerTeam'], 5,
    );
    final int tfc = parseCount(
      map['total_field_capacity'] ??
          map['totalFieldCapacity'] ??
          map['max_players'],
      ppt * 2,
    );

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
      currentPlayers: parseCount(map['currentPlayers'], 1),
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
      challengeCode: map['challengeCode']?.toString(),
      idempotencyKey: map['idempotencyKey']?.toString(),
    );
  }
}
