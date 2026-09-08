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
    final double parsedTotalPrice = (rawTotalPrice is num)
        ? rawTotalPrice.toDouble()
        : (double.tryParse(rawTotalPrice.toString()) ?? 0.0);

    final rawDeposit = map['deposit_paid'] ?? map['depositPaid'] ?? 0.0;
    final double parsedDeposit = (rawDeposit is num)
        ? rawDeposit.toDouble()
        : (double.tryParse(rawDeposit.toString()) ?? 0.0);

    final int ppt = map['players_per_team'] ?? map['playersPerTeam'] ?? 5;
    final int tfc = map['total_field_capacity'] ??
        map['totalFieldCapacity'] ??
        map['max_players'] ??
        (ppt * 2);

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
      currentPlayers: map['currentPlayers'] is int
          ? map['currentPlayers']
          : (int.tryParse(map['currentPlayers']?.toString() ?? '') ?? 1),
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
