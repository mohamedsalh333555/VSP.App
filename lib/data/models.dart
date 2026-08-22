import '../core/utils/elo_calculator.dart';

/// Stadium data model
class Stadium {
  final String id;
  final String name;
  final String location;
  final String imageUrl;
  final List<String> images;
  final String type; // Football, Basketball, etc.
  String get sportType => type;
  final String size; // 11 VS 11, 5 VS 5, etc.
  final int baths;
  final int cafeteria;
  final int playersPerTeam;
  final int totalFieldCapacity;
  final double pricePerHour;
  final double basePrice; // Unified price source
  final String area; // Jeresh, etc.
  final bool isFavorite;
  final double? lat;
  final double? lng;
  final String? governorate; // ✅ Added for filtering
  final double depositAmount; // ✅ Owner's determined deposit amount
  final bool needsDeposit; // ✅ Owner's deposit requirement flag
  
  // Backward compatibility getter
  int get seatsCapacity => totalFieldCapacity;

  // Format stadium name to always start with 'ملعب'
  String get formattedName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'ملعب';
    if (trimmed.startsWith('ملعب')) return trimmed;
    return 'ملعب $trimmed';
  }

  // Extended fields for details screen
  final String address;
  final double rating;
  final int reviewsCount;
  final String description;
  final dynamic features; // Can be List<String> or Map<String, dynamic>
  final List<String> policies;
  final String pitchCondition;
  final bool hasJerash;
  final bool hasSeats;
  final bool hasBall;
  final double ballPrice;
  final String notes; // ✅ Owner's custom pitch condition notes
  final String? contractUrl;
  final String? ownerIdUrl;
  final bool isVerified;
  final bool isFeatured; // ✅ Added featured status
  final String ownerId; // ✅ Stadium owner's UID
  final bool isBlocked; // ✅ Administrative block flag for debt management
  
  // Emergency Maintenance & Closure Fields
  final DateTime? maintenanceUntil;
  final String? maintenanceReason;
  final DateTime? lastEmergencyClosureAt;

  bool get isUnderMaintenance =>
      maintenanceUntil != null && maintenanceUntil!.isAfter(DateTime.now());

  // Working Hours (Standardized)
  final String openingTime; 
  final String closingTime;
  final bool isSplitShift;
  final String? breakStartTime;
  final String? breakEndTime;

  Stadium({
    required this.id,
    required this.name,
    required this.location,
    required this.imageUrl,
    this.images = const [],
    required this.type,
    required this.size,
    required this.baths,
    required this.cafeteria,
    required this.playersPerTeam,
    required this.totalFieldCapacity,
    required this.pricePerHour,
    double? basePrice,
    required this.area,
    this.isFavorite = false,
    this.address = '',
    this.rating = 0.0,
    this.reviewsCount = 0,
    this.description = '',
    this.features = const {},
    this.policies = const [],
    this.pitchCondition = 'Excellent',
    this.hasJerash = true,
    this.hasSeats = true,
    this.hasBall = false,
    this.ballPrice = 0.0,
    this.notes = '', // ✅ Default empty notes
    this.contractUrl,
    this.ownerIdUrl,
    this.isVerified = false,
    this.isFeatured = false, // ✅ Default to false
    this.ownerId = '', // ✅ Default empty ownerId
    this.isBlocked = false,
    this.maintenanceUntil,
    this.maintenanceReason,
    this.lastEmergencyClosureAt,
    this.openingTime = '08:00 AM',
    this.closingTime = '12:00 AM',
    this.isSplitShift = false,
    this.breakStartTime,
    this.breakEndTime,
    this.lat,
    this.lng,
    this.governorate, // ✅ Added for filtering
    this.depositAmount = 0.0,
    this.needsDeposit = false,
  }) : basePrice = basePrice ?? pricePerHour;

  static List<String> parseFeatures(dynamic data) {
    if (data is List) return List<String>.from(data);
    if (data is! Map) return [];
    
    final List<String> result = [];
    final map = data as Map<String, dynamic>;
    
    map.forEach((key, value) {
      if (value == true) {
        // Capitalize key
        String label = key[0].toUpperCase() + key.substring(1);
        // Special case for Jerash
        if (key == 'hasJerash') label = 'Professional Lighting';
        if (key == 'hasSeats') label = 'Spectator Seats';
        
        // Don't add if it's technical bool like hasBall (handled separately in UI)
        if (key != 'hasBall' && key != 'hasJerash' && key != 'hasSeats') {
           result.add(label);
        }
      } else if (key == 'bathOption' && value is String && value != 'None' && value != 'no') {
        result.add('Bathrooms ($value)');
      }
    });

    // Add lighting/seats if bools are true
    if (map['hasJerash'] == true) result.add('Professional Lighting');
    if (map['hasSeats'] == true) result.add('Spectator Seats');
    
    return result;
  }

  factory Stadium.fromFirestore(Map<String, dynamic> data, String id) {
    int parsedPPT = 5;
    final sizeStr = data['size']?.toString() ?? '5 VS 5';
    final match = RegExp(r'(\d+)\s*[Vv][Ss]\s*(\d+)').firstMatch(sizeStr);
    if (match != null) {
      parsedPPT = int.tryParse(match.group(1) ?? '') ?? 5;
    }
    final int ppt = data['players_per_team'] ?? data['playersPerTeam'] ?? parsedPPT;
    final int tfc = data['total_field_capacity'] ?? data['totalFieldCapacity'] ?? (ppt * 2);

    final String rawDesc = data['description'] ?? '';
    String sportType = 'Football';
    String cleanDesc = rawDesc;
    if (rawDesc.contains('|Sport:')) {
      final parts = rawDesc.split('|Sport:');
      cleanDesc = parts[0];
      sportType = parts[1];
    }

    final String rawNotes = data['notes'] ?? '';
    if (rawNotes.contains('|Sport:')) {
      final parts = rawNotes.split('|Sport:');
      sportType = parts[1];
    }

    final List<String> parsedImages = [];
    final mainImg = data['imageUrl'] ?? data['image_url'];
    if (mainImg != null && mainImg.toString().trim().isNotEmpty) {
      parsedImages.add(mainImg.toString().trim());
    }
    if (data['images'] is List) {
      for (var img in (data['images'] as List)) {
        final imgStr = img?.toString().trim() ?? '';
        if (imgStr.isNotEmpty && !parsedImages.contains(imgStr)) {
          parsedImages.add(imgStr);
        }
      }
    }
    if (data['features'] is Map && data['features']['allImages'] is List) {
      for (var img in (data['features']['allImages'] as List)) {
        final imgStr = img?.toString().trim() ?? '';
        if (imgStr.isNotEmpty && !parsedImages.contains(imgStr)) {
          parsedImages.add(imgStr);
        }
      }
    }

    return Stadium(
      id: id,
      name: data['name'] ?? '',
      location: data['location'] ?? data['address'] ?? '',
      governorate: data['governorate'], // ✅ Added for filtering
      type: sportType,
      size: data['size'] ?? '5 VS 5',
      imageUrl: parsedImages.isNotEmpty ? parsedImages.first : (data['imageUrl'] ?? data['image_url'] ?? ''),
      images: parsedImages,
      baths: data['baths'] ?? 0,
      cafeteria: data['cafeteria'] ?? 0,
      playersPerTeam: ppt,
      totalFieldCapacity: tfc,
      pricePerHour: (data['pricePerHour'] ?? data['price_per_hour'] ?? 0).toDouble(),
      basePrice: (data['basePrice'] ?? data['pricePerHour'] ?? data['price_per_hour'] ?? 0).toDouble(),
      area: data['area'] ?? data['city'] ?? data['governorate'] ?? '',
      isFavorite: data['isFavorite'] ?? false,
      address: data['address'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      reviewsCount: data['reviewsCount'] ?? data['reviews_count'] ?? 0,
      description: cleanDesc,
      features: data['features'] ?? {},
      policies: (data['policies'] is List) ? List<String>.from(data['policies']) : [],
      pitchCondition: data['pitchCondition'] ?? 'Good',
      hasJerash: data['hasJerash'] ?? (data['features'] is Map ? data['features']['hasJerash'] ?? false : false),
      hasSeats: data['hasSeats'] ?? (data['features'] is Map ? data['features']['hasSeats'] ?? false : false),
      hasBall: data['hasBall'] ?? (data['features'] is Map ? data['features']['hasBall'] ?? false : false),
      ballPrice: (data['ballPrice'] ?? (data['features'] is Map ? data['features']['ballPrice'] ?? 0 : 0)).toDouble(),
      notes: (data['notes'] as String?) ?? '', // ✅ Read notes
      contractUrl: data['contractUrl'] ?? data['contract_url'],
      ownerIdUrl: data['ownerIdUrl'] ?? data['owner_id_url'],
      isVerified: data['isVerified'] ?? data['is_verified'] ?? false,
      isFeatured: data['isFeatured'] ?? data['is_featured'] ?? false,
      ownerId: data['ownerId'] ?? data['owner_id'] ?? '',
      openingTime: (data['opening_time'] ?? data['openingTime'] ?? data['features']?['workingHours']?['start'])?.toString() ?? '04:00 PM',
      closingTime: (data['closing_time'] ?? data['closingTime'] ?? data['features']?['workingHours']?['end'])?.toString() ?? '03:00 AM',
      isSplitShift: data['features']?['isSplitShift'] ?? false,
      breakStartTime: data['features']?['breakTime']?['start'],
      breakEndTime: data['features']?['breakTime']?['end'],
      lat: (data['lat'] as num?)?.toDouble(),
      lng: (data['lng'] as num?)?.toDouble(),
      depositAmount: (data['deposit_amount'] ?? data['depositAmount'] ?? 0.0).toDouble(),
      needsDeposit: data['needs_deposit'] ?? data['needsDeposit'] ?? false,
      maintenanceUntil: data['maintenance_until'] != null ? DateTime.parse(data['maintenance_until'].toString()) : null,
      maintenanceReason: data['maintenance_reason'],
      lastEmergencyClosureAt: data['last_emergency_closure_at'] != null ? DateTime.parse(data['last_emergency_closure_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'name_lowercase': name.toLowerCase(),
      'location': location,
      'governorate': governorate,
      'image_url': imageUrl,
      'imageUrl': imageUrl,
      'images': images,
      'type': type,
      'size': size,
      'baths': baths,
      'cafeteria': cafeteria,
      'players_per_team': playersPerTeam,
      'playersPerTeam': playersPerTeam,
      'total_field_capacity': totalFieldCapacity,
      'totalFieldCapacity': totalFieldCapacity,
      'price_per_hour': pricePerHour,
      'pricePerHour': pricePerHour,
      'base_price': basePrice,
      'basePrice': basePrice,
      'area': area,
      'isFavorite': isFavorite,
      'address': address,
      'rating': rating,
      'reviews_count': reviewsCount,
      'reviewsCount': reviewsCount,
      'description': description,
      'features': features,
      'policies': policies,
      'pitch_condition': pitchCondition,
      'pitchCondition': pitchCondition,
      'has_jerash': hasJerash,
      'hasJerash': hasJerash,
      'has_seats': hasSeats,
      'hasSeats': hasSeats,
      'has_ball': hasBall,
      'hasBall': hasBall,
      'ball_price': ballPrice,
      'ballPrice': ballPrice,
      'notes': notes,
      'contract_url': contractUrl,
      'contractUrl': contractUrl,
      'owner_id_url': ownerIdUrl,
      'ownerIdUrl': ownerIdUrl,
      'is_verified': isVerified,
      'isVerified': isVerified,
      'is_featured': isFeatured,
      'isFeatured': isFeatured,
      'owner_id': ownerId,
      'ownerId': ownerId,
      'lat': lat,
      'lng': lng,
      'deposit_amount': depositAmount,
      'depositAmount': depositAmount,
      'needs_deposit': needsDeposit,
      'needsDeposit': needsDeposit,
    };
  }
}

/// Review data model
class Review {
  final String id;
  final String userName;
  final String userImageUrl;
  final double rating;
  final String comment;
  final String timeAgo;

  Review({
    required this.id,
    required this.userName,
    required this.userImageUrl,
    required this.rating,
    required this.comment,
    required this.timeAgo,
  });


}

/// Time slot data model
class TimeSlot {
  final String id;
  final String startTime;
  final String endTime;
  final bool isAvailable;
  final double price;

  TimeSlot({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.isAvailable,
    required this.price,
  });

  String get displayTime => '$startTime < $endTime';


}

/// Booking Status Enum
enum BookingStatus {
  pending,    // Draft state before payment
  confirmed,  // After successful payment, before match starts
  upcoming,   // Same as confirmed (alias)
  completed,  // After match time has passed
  cancelled,  // User/owner cancelled
}

enum MatchResultStatus { noResult, waitingOpponent, confirmed, disputed }

enum MatchOutcome { homeWin, draw, awayWin }
enum MatchResultChoice { weWon, draw, weLost }

/// Booking Type Enum
enum BookingType {
  personal,   // Solo/Standard booking (حجز عادي)
  openJoin,   // Open gathering match (حجز انضمام وتجميع)
  challenge,  // Team challenge match (حجز تحدي فرق)
  team,       // Legacy alias for challenge
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
class Team {
  final String id;
  final String name;
  final String captainId;
  final String captainName;
  final String captainImageUrl;
  final String logoUrl;
  final String date;
  final String stadium;
  final double pricePerPerson;
  final int currentPlayers;
  final int maxPlayers;
  final List<String> playerImages;
  final int points;
  final String trend;
  final String? captainPhone;
  final String sportType;

  // ── Governorate & League Fields ──
  final String governorate;
  final int matchesPlayed;
  final int wins;
  final int draws;
  final int losses;
  final List<String> playedOpponents;
  final List<String> beatenOpponents;
  final List<String> unlockedBadges;
  final int currentWinningStreak;
  final List<String> memberUids;
  final int championshipsWon; // TOURNAMENT Logic: Total trophies won

  // ── Fair Play System ──
  final int fairPlayScore;   // Season score (0–100), default 100
  final int lastResetYear;   // Year of last annual reset, default 2026

  final bool isOfficial;

  Team({
    required this.id,
    required this.name,
    this.captainId = '',
    required this.captainName,
    required this.captainImageUrl,
    this.logoUrl = '',
    required this.date,
    required this.stadium,
    required this.pricePerPerson,
    required this.currentPlayers,
    required this.maxPlayers,
    this.playerImages = const [],
    this.points = 0,
    this.trend = 'stable',
    this.captainPhone,
    this.sportType = 'Football',
    this.governorate = 'Cairo',
    this.matchesPlayed = 0,
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    this.playedOpponents = const [],
    this.beatenOpponents = const [],
    this.unlockedBadges = const [],
    this.currentWinningStreak = 0,
    this.memberUids = const [],
    this.championshipsWon = 0,
    this.fairPlayScore = 100,
    this.lastResetYear = 2026,
    this.isOfficial = false,
  });

  String get rankTitle => EloCalculator.getRankTitle(points);

  factory Team.fromFirestore(Map<String, dynamic> data, String docId) {
    final matches = data['matchesPlayed'] ?? data['matches_played'] ?? 0;
    final members = List<String>.from(data['memberUids'] ?? data['member_uids'] ?? []);
    final bool calculatedOfficial = matches > 0 || members.length >= 5;

    return Team(
      id: docId,
      name: data['name'] ?? '',
      captainId: data['captain_id'] ?? data['captainId'] ?? '',
      captainName: data['captainName'] ?? data['captain_name'] ?? 'Captain',
      captainImageUrl: data['captainImageUrl'] ?? data['captain_image_url'] ?? data['logoUrl'] ?? data['logo_url'] ?? '', 
      logoUrl: data['logoUrl'] ?? data['logo_url'] ?? data['captainImageUrl'] ?? data['captain_image_url'] ?? '',
      date: data['date'] ?? 'Upcoming',
      stadium: data['stadium'] ?? 'TBD',
      pricePerPerson: (data['pricePerPerson'] ?? data['price_per_person'] ?? 50).toDouble(),
      currentPlayers: data['playersCount'] ?? data['players_count'] ?? data['currentPlayers'] ?? data['current_players'] ?? 11,
      maxPlayers: data['maxPlayers'] ?? data['max_players'] ?? 11,
      playerImages: List<String>.from(data['playerImages'] ?? data['player_images'] ?? data['members'] ?? []),
      points: data['points'] ?? 0,
      trend: data['trend'] ?? 'stable',
      captainPhone: data['captainPhone'] ?? data['captain_phone'],
      sportType: data['sportType'] ?? data['sport_type'] ?? 'Football',
      governorate: data['governorate'] ?? 'Cairo',
      matchesPlayed: matches,
      wins: data['wins'] ?? 0,
      draws: data['draws'] ?? 0,
      losses: data['losses'] ?? 0,
      playedOpponents: List<String>.from(data['playedOpponents'] ?? data['played_opponents'] ?? []),
      beatenOpponents: List<String>.from(data['beatenOpponents'] ?? data['beaten_opponents'] ?? []),
      unlockedBadges: List<String>.from(data['unlockedBadges'] ?? data['unlocked_badges'] ?? []),
      currentWinningStreak: data['currentWinningStreak'] ?? data['current_winning_streak'] ?? 0,
      memberUids: members,
      championshipsWon: data['championshipsWon'] ?? data['championships_won'] ?? 0,
      fairPlayScore: data['fairPlayScore'] ?? data['fair_play_score'] ?? 100,
      lastResetYear: data['lastResetYear'] ?? data['last_reset_year'] ?? 2026,
      isOfficial: data['is_official'] ?? data['isOfficial'] ?? calculatedOfficial,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'name_lowercase': name.toLowerCase(),
      'captain_id': captainId,
      'captainId': captainId,
      'captainName': captainName,
      'captainImageUrl': captainImageUrl,
      'logoUrl': logoUrl,
      'date': date,
      'stadium': stadium,
      'pricePerPerson': pricePerPerson,
      'currentPlayers': currentPlayers,
      'maxPlayers': maxPlayers,
      'memberUids': memberUids,
      'playerImages': playerImages,
      'points': points,
      'trend': trend,
      'captainPhone': captainPhone,
      'sportType': sportType,
      'governorate': governorate,
      'matchesPlayed': matchesPlayed,
      'wins': wins,
      'draws': draws,
      'losses': losses,
      'playedOpponents': playedOpponents,
      'beatenOpponents': beatenOpponents,
      'unlockedBadges': unlockedBadges,
      'currentWinningStreak': currentWinningStreak,
      'championshipsWon': championshipsWon,
      'fairPlayScore': fairPlayScore,
      'lastResetYear': lastResetYear,
    };
  }

  Team copyWith({
    String? id,
    String? name,
    String? captainId,
    String? captainName,
    String? captainImageUrl,
    String? date,
    String? stadium,
    double? pricePerPerson,
    int? currentPlayers,
    int? maxPlayers,
    List<String>? playerImages,
    int? points,
    String? trend,
    String? captainPhone,
    String? governorate,
    int? matchesPlayed,
    int? wins,
    int? draws,
    int? losses,
    List<String>? playedOpponents,
    List<String>? beatenOpponents,
    int? championshipsWon,
    String? sportType,
    int? fairPlayScore,
    int? lastResetYear,
    List<String>? unlockedBadges,
  }) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
      captainId: captainId ?? this.captainId,
      captainName: captainName ?? this.captainName,
      captainImageUrl: captainImageUrl ?? this.captainImageUrl,
      date: date ?? this.date,
      stadium: stadium ?? this.stadium,
      pricePerPerson: pricePerPerson ?? this.pricePerPerson,
      currentPlayers: currentPlayers ?? this.currentPlayers,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      playerImages: playerImages ?? this.playerImages,
      points: points ?? this.points,
      trend: trend ?? this.trend,
      captainPhone: captainPhone ?? this.captainPhone,
      governorate: governorate ?? this.governorate,
      matchesPlayed: matchesPlayed ?? this.matchesPlayed,
      wins: wins ?? this.wins,
      draws: draws ?? this.draws,
      losses: losses ?? this.losses,
      playedOpponents: playedOpponents ?? this.playedOpponents,
      beatenOpponents: beatenOpponents ?? this.beatenOpponents,
      championshipsWon: championshipsWon ?? this.championshipsWon,
      sportType: sportType ?? this.sportType,
      fairPlayScore: fairPlayScore ?? this.fairPlayScore,
      lastResetYear: lastResetYear ?? this.lastResetYear,
      unlockedBadges: unlockedBadges ?? this.unlockedBadges,
    );
  }


}

class VSP1v1Player {
  final String id;
  final String name;
  final String avatarUrl;
  final int totalPoints;
  final int skillPoints;
  final int goals;
  final int tackles;
  final int titles;
  final int rank;
  final String trend;

  VSP1v1Player({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.totalPoints,
    required this.skillPoints,
    required this.goals,
    required this.tackles,
    this.titles = 0,
    required this.rank,
    this.trend = 'stable',
  });

  factory VSP1v1Player.fromFirestore(Map<String, dynamic> data, String id) {
    return VSP1v1Player(
      id: id,
      name: data['name'] ?? 'Unknown',
      avatarUrl: data['avatarUrl'] ?? '',
      totalPoints: (data['totalPoints'] ?? 0).toInt(),
      skillPoints: (data['skillPoints'] ?? 0).toInt(),
      goals: (data['goals'] ?? 0).toInt(),
      tackles: (data['tackles'] ?? 0).toInt(),
      titles: (data['titles'] ?? 0).toInt(),
      rank: (data['rank'] ?? 99).toInt(),
      trend: data['trend'] ?? 'stable',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'avatarUrl': avatarUrl,
      'totalPoints': totalPoints,
      'skillPoints': skillPoints,
      'goals': goals,
      'tackles': tackles,
      'titles': titles,
      'rank': rank,
      'trend': trend,
    };
  }

  static List<VSP1v1Player> getMockStandings() {
    return [
      VSP1v1Player(id: '1', name: 'Ahmed', avatarUrl: '', totalPoints: 100, skillPoints: 50, goals: 20, tackles: 10, rank: 1),
      VSP1v1Player(id: '2', name: 'Mohamed', avatarUrl: '', totalPoints: 80, skillPoints: 40, goals: 15, tackles: 8, rank: 2),
      VSP1v1Player(id: '3', name: 'Ali', avatarUrl: '', totalPoints: 60, skillPoints: 30, goals: 10, tackles: 5, rank: 3),
      VSP1v1Player(id: '4', name: 'Hassan', avatarUrl: '', totalPoints: 40, skillPoints: 20, goals: 5, tackles: 2, rank: 4),
      VSP1v1Player(id: '5', name: 'Ibrahim', avatarUrl: '', totalPoints: 20, skillPoints: 10, goals: 2, tackles: 1, rank: 5),
    ];
  }
}

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

  // ⚡ New Fields for Groups & League Systems
  final int numberOfGroups;
  final int qualifyingPerGroup;
  final bool isTwoLegs;

  // TOURNAMENT Lifecycle
  final String status; // 'open', 'ongoing', 'completed'
  final String? championTeamId;
  final String? championTeamName;

  // Entry Fee Tracking
  final List<String> paidTeams;

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
  });

  // SECURITY PATCH: Robust type parsing with crash prevention for malicious or corrupted data payloads.
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
        // ⚡ قراءة الإعدادات من أعمدتها المسطحة مباشرة مع خيار السقوط الخلفي للـ settings
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
    );
  }

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

/// Notification data model
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // 'info', 'result_confirmation'
  final bool isRead;
  final DateTime createdAt;
  final String? bookingId; 
  final Map<String, dynamic>? metadata;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.isRead = false,
    required this.createdAt,
    this.bookingId,
    this.metadata,
  });

  factory AppNotification.fromFirestore(Map<String, dynamic> data, String id) {
    return AppNotification(
      id: id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: data['type'] ?? 'info',
      isRead: data['isRead'] ?? false,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] is DateTime 
              ? data['createdAt'] 
              : DateTime.parse(data['createdAt'].toString()))
          : DateTime.now(),
      bookingId: data['bookingId'],
      metadata: data['metadata'] is Map<String, dynamic> ? Map<String, dynamic>.from(data['metadata']) : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
      'bookingId': bookingId,
      'metadata': metadata,
    };
  }
}

/// GoalItem — represents a single goal event in a match
class GoalItem {
  final String id;
  final String teamId;
  final String playerName;
  final bool isOwnGoal;

  GoalItem({
    required this.id,
    required this.teamId,
    required this.playerName,
    this.isOwnGoal = false,
  });

  factory GoalItem.fromMap(Map<String, dynamic> map) {
    return GoalItem(
      id: map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      teamId: map['team_id']?.toString() ?? map['teamId']?.toString() ?? '',
      playerName: map['player_name']?.toString() ?? map['playerName']?.toString() ?? 'لاعب مجهول',
      isOwnGoal: map['is_own_goal'] == true || map['isOwnGoal'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'team_id': teamId,
      'player_name': playerName,
      'is_own_goal': isOwnGoal,
    };
  }
}

/// Tournament Match — represents a single match in a knockout bracket
class TournamentMatch {
  final String id;
  final String championshipId;
  final int roundIndex; // 0 = Final, 1 = Semi, 2 = Quarters, 3 = Round of 16
  final int matchIndex; // Position within the round
  final String? homeTeamId;
  final String? homeTeamName;
  final String? awayTeamId;
  final String? awayTeamName;
  final int? homeScore;
  final int? awayScore;
  final int? homePenalties;
  final int? awayPenalties;
  final String? winnerId;
  final String? nextMatchId; // ID of the match the winner advances to
  final DateTime? scheduledTime;
  final List<GoalItem> goalDetails;

  // ⚡ New Fields for Groups & League
  final String? groupName; // 'A', 'B', 'C', 'D'...
  final int? weekNumber;   // 1, 2, 3...
  final String stage;      // 'preliminary', 'group_stage', 'knockout', 'league'

  TournamentMatch({
    required this.id,
    required this.championshipId,
    required this.roundIndex,
    required this.matchIndex,
    this.homeTeamId,
    this.homeTeamName,
    this.awayTeamId,
    this.awayTeamName,
    this.homeScore,
    this.awayScore,
    this.homePenalties,
    this.awayPenalties,
    this.winnerId,
    this.nextMatchId,
    this.scheduledTime,
    this.goalDetails = const [],
    this.groupName,
    this.weekNumber,
    this.stage = 'knockout',
  });

  bool get isCompleted => winnerId != null || (homeScore != null && awayScore != null);
  bool get isReady => homeTeamId != null && awayTeamId != null;

  String get roundLabel {
    if (stage == 'preliminary') return 'الجولة التمهيدية';
    if (stage == 'group_stage') return 'المجموعة ${groupName ?? "A"} - الأسبوع ${weekNumber ?? 1}';
    if (stage == 'league') return 'الأسبوع ${weekNumber ?? 1}';
    switch (roundIndex) {
      case 0: return 'Final';
      case 1: return 'Semi-Finals';
      case 2: return 'Quarter-Finals';
      case 3: return 'Round of 16';
      case 4: return 'Round of 32';
      default: return 'Round ${roundIndex + 1}';
    }
  }

  TournamentMatch copyWith({
    String? id,
    String? championshipId,
    int? roundIndex,
    int? matchIndex,
    String? homeTeamId,
    String? homeTeamName,
    String? awayTeamId,
    String? awayTeamName,
    int? homeScore,
    int? awayScore,
    int? homePenalties,
    int? awayPenalties,
    String? winnerId,
    String? nextMatchId,
    DateTime? scheduledTime,
    List<GoalItem>? goalDetails,
    String? groupName,
    int? weekNumber,
    String? stage,
  }) {
    return TournamentMatch(
      id: id ?? this.id,
      championshipId: championshipId ?? this.championshipId,
      roundIndex: roundIndex ?? this.roundIndex,
      matchIndex: matchIndex ?? this.matchIndex,
      homeTeamId: homeTeamId ?? this.homeTeamId,
      homeTeamName: homeTeamName ?? this.homeTeamName,
      awayTeamId: awayTeamId ?? this.awayTeamId,
      awayTeamName: awayTeamName ?? this.awayTeamName,
      homeScore: homeScore ?? this.homeScore,
      awayScore: awayScore ?? this.awayScore,
      homePenalties: homePenalties ?? this.homePenalties,
      awayPenalties: awayPenalties ?? this.awayPenalties,
      winnerId: winnerId ?? this.winnerId,
      nextMatchId: nextMatchId ?? this.nextMatchId,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      goalDetails: goalDetails ?? this.goalDetails,
      groupName: groupName ?? this.groupName,
      weekNumber: weekNumber ?? this.weekNumber,
      stage: stage ?? this.stage,
    );
  }

  factory TournamentMatch.fromFirestore(Map<String, dynamic> data, String id) {
    final scheduledTimeVal = data['scheduledTime'] ?? data['scheduled_time'];
    final rawGoals = data['goal_details'] ?? data['goalDetails'] ?? [];
    final List<GoalItem> parsedGoals = (rawGoals is List)
        ? rawGoals.map((g) => GoalItem.fromMap(Map<String, dynamic>.from(g))).toList()
        : [];

    return TournamentMatch(
      id: id,
      championshipId: data['championshipId'] ?? data['championship_id'] ?? '',
      roundIndex: data['roundIndex'] ?? data['round_index'] ?? 0,
      matchIndex: data['matchIndex'] ?? data['match_index'] ?? 0,
      homeTeamId: data['homeTeamId'] ?? data['home_team_id'],
      homeTeamName: data['homeTeamName'] ?? data['home_team_name'],
      awayTeamId: data['awayTeamId'] ?? data['away_team_id'],
      awayTeamName: data['awayTeamName'] ?? data['away_team_name'],
      homeScore: data['homeScore'] ?? data['home_score'],
      awayScore: data['awayScore'] ?? data['away_score'],
      homePenalties: data['homePenalties'] ?? data['home_penalties'],
      awayPenalties: data['awayPenalties'] ?? data['away_penalties'],
      winnerId: data['winnerId'] ?? data['winner_id'],
      nextMatchId: data['nextMatchId'] ?? data['next_match_id'],
      scheduledTime: scheduledTimeVal != null
          ? (scheduledTimeVal is DateTime 
              ? scheduledTimeVal.toLocal() 
              : DateTime.tryParse(scheduledTimeVal.toString())?.toLocal())
          : null,
      goalDetails: parsedGoals,
      groupName: data['group_name'] ?? data['groupName'],
      weekNumber: data['week_number'] ?? data['weekNumber'],
      stage: data['stage'] ?? 'knockout',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'championship_id': championshipId,
      'championshipId': championshipId,
      'round_index': roundIndex,
      'roundIndex': roundIndex,
      'match_index': matchIndex,
      'matchIndex': matchIndex,
      'home_team_id': homeTeamId,
      'homeTeamId': homeTeamId,
      'home_team_name': homeTeamName,
      'homeTeamName': homeTeamName,
      'away_team_id': awayTeamId,
      'awayTeamId': awayTeamId,
      'away_team_name': awayTeamName,
      'awayTeamName': awayTeamName,
      'home_score': homeScore,
      'homeScore': homeScore,
      'away_score': awayScore,
      'awayScore': awayScore,
      'home_penalties': homePenalties,
      'away_penalties': awayPenalties,
      'winner_id': winnerId,
      'winnerId': winnerId,
      'next_match_id': nextMatchId,
      'nextMatchId': nextMatchId,
      'scheduled_time': scheduledTime?.toUtc().toIso8601String(),
      'scheduledTime': scheduledTime?.toUtc().toIso8601String(),
      'goal_details': goalDetails.map((g) => g.toMap()).toList(),
      'group_name': groupName,
      'week_number': weekNumber,
      'stage': stage,
    };
  }
}

/// Dynamic Marketing Promotion model
class Promotion {
  final String id;
  final String title;
  final String imageUrl;
  final String? deepLink;
  final String type; // 'match', 'stadium', 'championship', 'external'
  final bool isActive;

  Promotion({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.deepLink,
    required this.type,
    this.isActive = true,
  });

  factory Promotion.fromFirestore(Map<String, dynamic> data, String id) {
    return Promotion(
      id: id,
      title: data['title'] ?? '',
      imageUrl: data['imageUrl'] ?? data['image_url'] ?? '',
      deepLink: data['deepLink'] ?? data['deep_link'],
      type: data['type'] ?? 'info',
      isActive: data['isActive'] ?? data['is_active'] ?? true,
    );
  }
}

// === VSP OFFICIAL 1v1 LEAGUE MODELS ===
// (Duplicated class removed, using the one defined above)


