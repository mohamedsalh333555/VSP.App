import 'package:cloud_firestore/cloud_firestore.dart';

/// Stadium data model
class Stadium {
  final String id;
  final String name;
  final String location;
  final String imageUrl;
  final List<String> images;
  final String type; // Football, Basketball, etc.
  final String size; // 11 VS 11, 5 VS 5, etc.
  final int baths;
  final int cafeteria;
  final int seatsCapacity;
  final double pricePerHour;
  final double basePrice; // Unified price source
  final String area; // Jeresh, etc.
  final bool isFavorite;
  
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
  final String ownerId; // ✅ Stadium owner's UID

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
    required this.seatsCapacity,
    required this.pricePerHour,
    double? basePrice,
    required this.area,
    this.isFavorite = false,
    this.address = '',
    this.rating = 4.5,
    this.reviewsCount = 52,
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
    this.ownerId = '', // ✅ Default empty ownerId
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

  // Mock data
  static List<Stadium> getMockStadiums() {
    return [
      Stadium(
        id: '1',
        name: 'Santiago Bernabéu',
        location: 'Madrid',
        imageUrl: 'https://images.unsplash.com/photo-1556056504-5c7696c4c28d?w=800&h=600&fit=crop&q=80', // Real high-res stadium pitch
        type: 'Football',
        size: '11 VS 11',
        baths: 5,
        cafeteria: 2,
        seatsCapacity: 490,
        pricePerHour: 120,
        area: 'Jeresh',
        isFavorite: true,
        address: 'Av. De Concha Espina, 1, Chamartín, 28036 Madrid',
        rating: 4.5,
        reviewsCount: 52,
        description: 'The Santiago Bernabéu Stadium Is A Modern, Multi-Use Stadium Featuring A Retractable Roof, A Contemporary Facade, A Retractable Pitch, And Significant Improvements In Safety, Comfort, And Accessibility. It Also Includes Multifunctional Spaces Such As Restaurants, Museums, And Commercial Areas, As Well As A 360-Degree Giant Screen, With A Focus On Sustainability.',
        features: ['Baths', '11 VS 11', 'Cafeteria', 'Jerash', 'Seats'],
        policies: [
          'Punctuality:\nCustomers Must Arrive On Time For Their Reservation. Any Delay May Result In Forfeiting Part Of Their Playing Time Without Compensation.',
          'Reservation Duration:\nThe Playing Time Cannot Be Extended After The Booked Time Has Expired. If Additional Time Is Required, A New Reservation Must Be Made (Subject To Availability).',
          'Cancellation And Refund Policy:\nNo Refund Will Be Given If The Reservation Is Cancelled Less Than 24 Hours Before The Scheduled Time.',
          'If The Cancellation Is Made More Than 24 Hours Before The Scheduled Time, A Full Refund Will Be Issued.',
        ],
        pitchCondition: 'Excellent - Well maintained grass with proper drainage',
        hasJerash: true,
        hasSeats: true,
        hasBall: true,
        ballPrice: 20,
        isVerified: true,
        images: [
          'https://images.unsplash.com/photo-1556056504-5c7696c4c28d?w=800&h=600&fit=crop&q=80',
          'https://images.unsplash.com/photo-1522778119026-d647f0596c20?w=800&h=600&fit=crop&q=80',
          'https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=800&h=600&fit=crop&q=80',
        ],
      ),
      Stadium(
        id: '2',
        name: 'Camp Nou',
        location: 'Barcelona',
        imageUrl: 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=800&h=600&fit=crop&q=80', // High-quality football field
        type: 'Football',
        size: '11 VS 11',
        baths: 4,
        cafeteria: 3,
        seatsCapacity: 600,
        pricePerHour: 150,
        area: 'Barcelona',
        isFavorite: false,
        address: 'C. d\'Aristides Maillol, 12, Les Corts, 08028 Barcelona',
        rating: 4.8,
        reviewsCount: 89,
        description: 'Camp Nou is one of the most iconic football stadiums in the world, home to FC Barcelona.',
        features: ['Baths', '11 VS 11', 'Cafeteria', 'Seats'],
        policies: [
          'Punctuality: Arrive on time',
          'No outside food or drinks',
          'Proper football attire required',
        ],
        pitchCondition: 'Excellent',
        hasJerash: false,
        hasSeats: true,
        hasBall: true,
        ballPrice: 25,
        isVerified: true,
        images: [
          'https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=800&h=600&fit=crop&q=80',
          'https://images.unsplash.com/photo-1431324155629-1a6deb1dec8d?w=800&h=600&fit=crop&q=80',
        ],
      ),
      Stadium(
        id: '3',
        name: 'Allianz Arena',
        location: 'Munich',
        imageUrl: 'https://images.unsplash.com/photo-1522778119026-d647f0596c20?w=800&h=600&fit=crop&q=80', // Stadium panorama
        type: 'Football',
        size: '11 VS 11',
        baths: 6,
        cafeteria: 4,
        seatsCapacity: 750,
        pricePerHour: 180,
        area: 'Munich',
        isFavorite: false,
        address: 'Werner-Heisenberg-Allee 25, 80939 München, Germany',
        rating: 4.9,
        reviewsCount: 128,
        description: 'The Allianz Arena is a football stadium with a striking exterior of inflated ETFE plastic panels.',
        features: ['Baths', '11 VS 11', 'Cafeteria', 'Jerash', 'Seats', 'Parking'],
        policies: ['Punctuality required', 'No smoking'],
        pitchCondition: 'Perfect',
        hasJerash: true,
        hasSeats: true,
        hasBall: true,
        ballPrice: 20,
        isVerified: true,
      ),
      Stadium(
        id: '4',
        name: 'Old Trafford',
        location: 'Manchester',
        imageUrl: 'https://images.unsplash.com/photo-1431324155629-1a6deb1dec8d?w=800&h=600&fit=crop&q=80', // Night match atmosphere
        type: 'Football',
        size: '11 VS 11',
        baths: 5,
        cafeteria: 3,
        seatsCapacity: 680,
        pricePerHour: 160,
        area: 'Manchester',
        isFavorite: true,
        address: 'Sir Matt Busby Way, Old Trafford, Stretford, Manchester',
        rating: 4.7,
        reviewsCount: 95,
        description: 'Known as the Theatre of Dreams, one of the most famous football stadiums.',
        features: ['Baths', '11 VS 11', 'Cafeteria', 'Seats'],
        policies: ['Arrive 15 mins early', 'ID required'],
        pitchCondition: 'Excellent',
        hasJerash: true,
        hasSeats: true,
        hasBall: true,
        ballPrice: 25,
      ),
      Stadium(
        id: '5',
        name: 'Wembley Stadium',
        location: 'London',
        imageUrl: 'https://images.unsplash.com/photo-1489944440615-453fc2b6a9a9?w=800&h=600&fit=crop&q=80', // Green pitch view
        type: 'Football',
        size: '11 VS 11',
        baths: 8,
        cafeteria: 5,
        seatsCapacity: 900,
        pricePerHour: 200,
        area: 'London',
        isFavorite: false,
        address: 'Wembley, London HA9 0WS, United Kingdom',
        rating: 4.6,
        reviewsCount: 156,
        description: 'The iconic national stadium of England with its famous arch.',
        features: ['Baths', '11 VS 11', 'Cafeteria', 'Jerash', 'Seats', 'VIP Lounge'],
        policies: ['Online booking only', 'No refunds within 48hrs'],
        pitchCondition: 'World Class',
        hasJerash: true,
        hasSeats: true,
        hasBall: true,
        ballPrice: 20,
      ),
    ];
  }
  
  static Stadium getById(String id) {
    return getMockStadiums().firstWhere((s) => s.id == id);
  }
  factory Stadium.fromFirestore(Map<String, dynamic> data, String id) {
    return Stadium(
      id: id,
      name: data['name'] ?? '',
      location: data['location'] ?? '',
      type: data['type'] ?? 'Football',
      size: data['size'] ?? '5 VS 5',
      imageUrl: data['imageUrl'] ?? '',
      images: (data['features'] is Map && data['features']['allImages'] is List && (data['features']['allImages'] as List).isNotEmpty)
          ? List<String>.from(data['features']['allImages'])
          : (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty ? [data['imageUrl']] : []),
      baths: data['baths'] ?? 0,
      cafeteria: data['cafeteria'] ?? 0,
      seatsCapacity: data['seatsCapacity'] ?? 0,
      pricePerHour: (data['pricePerHour'] ?? 0).toDouble(),
      basePrice: (data['basePrice'] ?? data['pricePerHour'] ?? 0).toDouble(),
      area: data['area'] ?? '',
      isFavorite: data['isFavorite'] ?? false,
      address: data['address'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      reviewsCount: data['reviewsCount'] ?? 0,
      description: data['description'] ?? '',
      features: data['features'] ?? {},
      policies: (data['policies'] is List) ? List<String>.from(data['policies']) : [],
      pitchCondition: data['pitchCondition'] ?? 'Good',
      hasJerash: data['hasJerash'] ?? (data['features'] is Map ? data['features']['hasJerash'] ?? false : false),
      hasSeats: data['hasSeats'] ?? (data['features'] is Map ? data['features']['hasSeats'] ?? false : false),
      hasBall: data['hasBall'] ?? (data['features'] is Map ? data['features']['hasBall'] ?? false : false),
      ballPrice: (data['ballPrice'] ?? (data['features'] is Map ? data['features']['ballPrice'] ?? 0 : 0)).toDouble(),
      notes: (data['notes'] as String?) ?? '', // ✅ Read notes from Firestore
      contractUrl: data['contractUrl'],
      ownerIdUrl: data['ownerIdUrl'],
      isVerified: data['isVerified'] ?? false,
      ownerId: data['ownerId'] ?? '', // ✅ Read ownerId from Firestore
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'location': location,
      'imageUrl': imageUrl,
      'images': images,
      'type': type,
      'size': size,
      'baths': baths,
      'cafeteria': cafeteria,
      'seatsCapacity': seatsCapacity,
      'pricePerHour': pricePerHour,
      'basePrice': basePrice,
      'area': area,
      'isFavorite': isFavorite,
      'address': address,
      'rating': rating,
      'reviewsCount': reviewsCount,
      'description': description,
      'features': features,
      'policies': policies,
      'pitchCondition': pitchCondition,
      'hasJerash': hasJerash,
      'hasSeats': hasSeats,
      'hasBall': hasBall,
      'ballPrice': ballPrice,
      'notes': notes, // ✅ Save notes to Firestore
      'contractUrl': contractUrl,
      'ownerIdUrl': ownerIdUrl,
      'isVerified': isVerified,
      'ownerId': ownerId, // ✅ Save ownerId to Firestore
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

  static List<Review> getMockReviews() {
    return [
      Review(
        id: '1',
        userName: 'Mohamed Salah',
        userImageUrl: 'https://images.unsplash.com/photo-1543351611-58f69d7c1781?w=150&h=150&fit=crop&q=80',
        rating: 5.0,
        comment: 'The atmosphere at Santiago Bernabéu is absolutely electric. Best pitch I have played on!',
        timeAgo: '2 Mins Ago',
      ),
      Review(
        id: '2',
        userName: 'Kylian Mbappé',
        userImageUrl: 'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?w=150&h=150&fit=crop&q=80',
        rating: 5.0,
        comment: 'Great stadium with top-tier facilities for professionals. The pitch condition is perfect.',
        timeAgo: '1 Hour Ago',
      ),
    ];
  }
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

  static List<TimeSlot> getMockTimeSlots() {
    return [
      TimeSlot(
        id: '1',
        startTime: '06:30 Pm',
        endTime: '08:00 Pm',
        isAvailable: true,
        price: 120,
      ),
      TimeSlot(
        id: '2',
        startTime: '07:00 Pm',
        endTime: '08:30 Pm',
        isAvailable: true,
        price: 120,
      ),
      TimeSlot(
        id: '3',
        startTime: '07:30 Pm',
        endTime: '09:00 Pm',
        isAvailable: false,
        price: 120,
      ),
      TimeSlot(
        id: '4',
        startTime: '08:00 Pm',
        endTime: '09:30 Pm',
        isAvailable: false,
        price: 120,
      ),
      TimeSlot(
        id: '5',
        startTime: '08:30 Pm',
        endTime: '10:00 Pm',
        isAvailable: false,
        price: 120,
      ),
    ];
  }
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
  personal,   // Solo booking
  team,       // Booking with team
  challenge,  // Challenge another team
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

  final bool isPrivate;
  final bool rentBall;

  final double totalPrice;
  final String currency;

  final String? paymentMethod;
  final String? paymentTransactionId;
  final int currentPlayers;
  final int maxPlayers;

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
    this.opponentTeamId,
    this.opponentTeamName,
    required this.isPrivate,
    required this.rentBall,
    required this.totalPrice,
    this.currency = 'EGP',
    this.paymentMethod,
    this.paymentTransactionId,
    this.currentPlayers = 1,
    this.maxPlayers = 10,
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
    String? opponentTeamId,
    String? opponentTeamName,
    bool? isPrivate,
    bool? rentBall,
    double? totalPrice,
    String? currency,
    String? paymentMethod,
    String? paymentTransactionId,
    int? currentPlayers,
    int? maxPlayers,
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
      opponentTeamId: opponentTeamId ?? this.opponentTeamId,
      opponentTeamName: opponentTeamName ?? this.opponentTeamName,
      isPrivate: isPrivate ?? this.isPrivate,
      rentBall: rentBall ?? this.rentBall,
      totalPrice: totalPrice ?? this.totalPrice,
      currency: currency ?? this.currency,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentTransactionId: paymentTransactionId ?? this.paymentTransactionId,
      currentPlayers: currentPlayers ?? this.currentPlayers,
      maxPlayers: maxPlayers ?? this.maxPlayers,
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
      'opponentTeamId': opponentTeamId,
      'opponentTeamName': opponentTeamName,
      'isPrivate': isPrivate,
      'rentBall': rentBall,
      'totalPrice': totalPrice,
      'currency': currency,
      'paymentMethod': paymentMethod,
      'paymentTransactionId': paymentTransactionId,
      'currentPlayers': currentPlayers,
      'maxPlayers': maxPlayers,
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

  // Booking type
  final BookingType bookingType;
  final String? playerTeamId;
  final String? playerTeamName;
  final String? opponentTeamId;
  final String? opponentTeamName;

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

  // Match Result (for Challenge bookings)
  final int? homeScore;
  final int? awayScore;
  final String? resultSubmittedByTeamId;
  final MatchResultStatus matchResultStatus;
  final MatchOutcome? pendingOutcome;
  final MatchOutcome? finalOutcome;

  // Public Match Fields
  final int currentPlayers;
  final int maxPlayers;
  final List<String> joinedUserIds;

  Booking({
    required this.id,
    required this.stadiumId,
    required this.stadiumName,
    this.stadiumImageUrl = '',
    required this.ownerId,
    required this.startTime,
    required this.endTime,
    required this.bookingType,
    this.playerTeamId,
    this.playerTeamName,
    this.opponentTeamId,
    this.opponentTeamName,
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
    this.currentPlayers = 1,
    this.maxPlayers = 10,
    this.joinedUserIds = const [],
  });

  /// Create Booking from Firestore document
  factory Booking.fromFirestore(Map<String, dynamic> data, String id) {
    return Booking(
      id: id,
      stadiumId: data['stadiumId'] ?? '',
      stadiumName: data['stadiumName'] ?? '',
      stadiumImageUrl: data['stadiumImageUrl'] ?? '',
      ownerId: data['ownerId'] ?? '',
      startTime: data['startTime'] != null 
          ? (data['startTime'] is Timestamp 
              ? (data['startTime'] as Timestamp).toDate()
              : (data['startTime'] is DateTime 
                  ? data['startTime'] 
                  : DateTime.parse(data['startTime'])))
          : DateTime.now(),
      endTime: data['endTime'] != null 
          ? (data['endTime'] is Timestamp 
              ? (data['endTime'] as Timestamp).toDate()
              : (data['endTime'] is DateTime 
                  ? data['endTime'] 
                  : DateTime.parse(data['endTime'])))
          : DateTime.now(),
      bookingType: BookingType.values.firstWhere(
        (e) => e.name == data['bookingType'],
        orElse: () => BookingType.personal,
      ),
      playerTeamId: data['playerTeamId'],
      playerTeamName: data['playerTeamName'],
      opponentTeamId: data['opponentTeamId'],
      opponentTeamName: data['opponentTeamName'],
      isPrivate: data['isPrivate'] ?? false,
      rentBall: data['rentBall'] ?? false,
      totalPrice: (data['totalPrice'] ?? 0).toDouble(),
      currency: data['currency'] ?? 'EGP',
      paymentMethod: data['paymentMethod'] ?? 'card',
      paymentTransactionId: data['paymentTransactionId'],
      status: BookingStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => BookingStatus.pending,
      ),
      createdByUserId: data['createdByUserId'] ?? '',
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] is Timestamp 
              ? (data['createdAt'] as Timestamp).toDate()
              : (data['createdAt'] is DateTime 
                  ? data['createdAt'] 
                  : DateTime.parse(data['createdAt'])))
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] is Timestamp 
              ? (data['updatedAt'] as Timestamp).toDate()
              : (data['updatedAt'] is DateTime 
                  ? data['updatedAt'] 
                  : DateTime.parse(data['updatedAt'])))
          : null,
      homeScore: data['homeScore'],
      awayScore: data['awayScore'],
      resultSubmittedByTeamId: data['resultSubmittedByTeamId'],
      matchResultStatus: MatchResultStatus.values.firstWhere(
        (e) => e.name == data['matchResultStatus'],
        orElse: () => MatchResultStatus.noResult,
      ),
      pendingOutcome: data['pendingOutcome'] != null 
          ? MatchOutcome.values.firstWhere((e) => e.name == data['pendingOutcome']) 
          : null,
      finalOutcome: data['finalOutcome'] != null 
          ? MatchOutcome.values.firstWhere((e) => e.name == data['finalOutcome']) 
          : null,
      currentPlayers: data['currentPlayers'] ?? 1,
      maxPlayers: data['maxPlayers'] ?? 10,
      joinedUserIds: List<String>.from(data['joinedUserIds'] ?? []),
    );
  }

  /// Convert Booking to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'stadiumId': stadiumId,
      'stadiumName': stadiumName,
      'stadiumImageUrl': stadiumImageUrl,
      'ownerId': ownerId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'bookingType': bookingType.name,
      'playerTeamId': playerTeamId,
      'playerTeamName': playerTeamName,
      'opponentTeamId': opponentTeamId,
      'opponentTeamName': opponentTeamName,
      'isPrivate': isPrivate,
      'rentBall': rentBall,
      'totalPrice': totalPrice,
      'currency': currency,
      'paymentMethod': paymentMethod,
      'paymentTransactionId': paymentTransactionId,
      'status': status.name,
      'createdByUserId': createdByUserId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'homeScore': homeScore,
      'awayScore': awayScore,
      'resultSubmittedByTeamId': resultSubmittedByTeamId,
      'matchResultStatus': matchResultStatus.name,
      'pendingOutcome': pendingOutcome?.name,
      'finalOutcome': finalOutcome?.name,
      'currentPlayers': currentPlayers,
      'maxPlayers': maxPlayers,
      'joinedUserIds': joinedUserIds,
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
      opponentTeamId: draft.opponentTeamId,
      opponentTeamName: draft.opponentTeamName,
      isPrivate: draft.isPrivate,
      rentBall: draft.rentBall,
      totalPrice: draft.totalPrice,
      currency: draft.currency,
      paymentMethod: draft.paymentMethod ?? 'card',
      paymentTransactionId: draft.paymentTransactionId,
      status: status,
      createdByUserId: userId,
      createdAt: DateTime.now(),
      currentPlayers: draft.currentPlayers,
      maxPlayers: draft.maxPlayers,
      joinedUserIds: [userId],
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
    String? opponentTeamId,
    String? opponentTeamName,
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
    int? currentPlayers,
    int? maxPlayers,
    List<String>? joinedUserIds,
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
      opponentTeamId: opponentTeamId ?? this.opponentTeamId,
      opponentTeamName: opponentTeamName ?? this.opponentTeamName,
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
      currentPlayers: currentPlayers ?? this.currentPlayers,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      joinedUserIds: joinedUserIds ?? this.joinedUserIds,
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

  /// Get formatted time range
  String get formattedTimeRange {
    String formatTime(DateTime dt) {
      final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:${dt.minute.toString().padLeft(2, '0')} $period';
    }
    return '${formatTime(startTime)} - ${formatTime(endTime)}';
  }
}


/// Team data model
class Team {
  final String id;
  final String name;
  final String captainName;
  final String captainImageUrl;
  final String date;
  final String stadium;
  final double pricePerPerson;
  final int currentPlayers;
  final int maxPlayers;
  final List<String> playerImages;
  final int points;
  final String trend;
  final String? captainPhone;

  // ── Governorate & League Fields ──
  final String governorate;
  final int matchesPlayed;
  final int wins;
  final int draws;
  final int losses;
  final List<String> playedOpponents;
  final List<String> unlockedBadges;
  final int currentWinningStreak;
  final List<String> memberUids;

  Team({
    required this.id,
    required this.name,
    required this.captainName,
    required this.captainImageUrl,
    required this.date,
    required this.stadium,
    required this.pricePerPerson,
    required this.currentPlayers,
    required this.maxPlayers,
    this.playerImages = const [],
    this.points = 0,
    this.trend = 'stable',
    this.captainPhone,
    this.governorate = 'Cairo',
    this.matchesPlayed = 0,
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    this.playedOpponents = const [],
    this.unlockedBadges = const [],
    this.currentWinningStreak = 0,
    this.memberUids = const [],
  });

  factory Team.fromFirestore(Map<String, dynamic> data, String docId) {
    return Team(
      id: docId,
      name: data['name'] ?? '',
      captainName: data['captainName'] ?? 'Captain',
      captainImageUrl: data['logoUrl'] ?? data['captainImageUrl'] ?? '',
      date: data['date'] ?? 'Upcoming',
      stadium: data['stadium'] ?? 'TBD',
      pricePerPerson: (data['pricePerPerson'] ?? 50).toDouble(),
      currentPlayers: data['playersCount'] ?? data['currentPlayers'] ?? 11,
      maxPlayers: data['maxPlayers'] ?? 11,
      playerImages: List<String>.from(data['members'] ?? []),
      points: data['points'] ?? 0,
      trend: data['trend'] ?? 'stable',
      captainPhone: data['captainPhone'],
      governorate: data['governorate'] ?? 'Cairo',
      matchesPlayed: data['matchesPlayed'] ?? 0,
      wins: data['wins'] ?? 0,
      draws: data['draws'] ?? 0,
      losses: data['losses'] ?? 0,
      playedOpponents: List<String>.from(data['playedOpponents'] ?? []),
      unlockedBadges: List<String>.from(data['unlockedBadges'] ?? []),
      currentWinningStreak: data['currentWinningStreak'] ?? 0,
      memberUids: List<String>.from(data['memberUids'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'captainName': captainName,
      'captainImageUrl': captainImageUrl,
      'date': date,
      'stadium': stadium,
      'pricePerPerson': pricePerPerson,
      'currentPlayers': currentPlayers,
      'maxPlayers': maxPlayers,
      'members': playerImages,
      'points': points,
      'trend': trend,
      'captainPhone': captainPhone,
      'governorate': governorate,
      'matchesPlayed': matchesPlayed,
      'wins': wins,
      'draws': draws,
      'losses': losses,
      'playedOpponents': playedOpponents,
      'unlockedBadges': unlockedBadges,
      'currentWinningStreak': currentWinningStreak,
      'memberUids': memberUids,
    };
  }

  Team copyWith({
    String? id,
    String? name,
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
  }) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
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
    );
  }

  // Mock data
  static List<Team> getMockTeams() {
    return [
      Team(
        id: '1',
        name: 'Real Madrid CF',
        captainName: 'Mohamed Salah',
        captainImageUrl: 'https://upload.wikimedia.org/wikipedia/en/5/56/Real_Madrid_CF.svg',
        date: 'August 6th / 7pm',
        stadium: 'Santiago Bernabéu',
        pricePerPerson: 100,
        currentPlayers: 8,
        maxPlayers: 12,
        points: 34,
        trend: 'up',
        governorate: 'Cairo',
        matchesPlayed: 14,
        wins: 10,
        draws: 4,
        losses: 0,
        playedOpponents: ['2', '3', '4', '5', '6', '7', '8'],
        playerImages: [
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&q=80',
        ],
      ),
      Team(
        id: '2',
        name: 'FC Barcelona',
        captainName: 'Robert Lewandowski',
        captainImageUrl: 'https://upload.wikimedia.org/wikipedia/en/4/47/FC_Barcelona_%28crest%29.svg',
        date: 'August 7th / 8pm',
        stadium: 'Camp Nou',
        pricePerPerson: 120,
        currentPlayers: 10,
        maxPlayers: 14,
        points: 30,
        trend: 'up',
        governorate: 'Cairo',
        matchesPlayed: 14,
        wins: 9,
        draws: 3,
        losses: 2,
        playedOpponents: ['1', '3', '4', '5', '6', '7', '9'],
        playerImages: [
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=150&h=150&fit=crop&q=80',
        ],
      ),
      Team(
        id: '3',
        name: 'Manchester City',
        captainName: 'Kevin De Bruyne',
        captainImageUrl: 'https://upload.wikimedia.org/wikipedia/en/e/eb/Manchester_City_FC_badge.svg',
        date: 'August 8th / 9pm',
        stadium: 'Etihad Stadium',
        pricePerPerson: 110,
        currentPlayers: 5,
        maxPlayers: 10,
        points: 28,
        trend: 'up',
        governorate: 'Cairo',
        matchesPlayed: 14,
        wins: 8,
        draws: 4,
        losses: 2,
        playedOpponents: ['1', '2', '4', '5', '6'],
        playerImages: [
          'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1544723795-3fb6469f5b39?w=150&h=150&fit=crop&q=80',
        ],
      ),
      Team(
        id: '4',
        name: 'Liverpool FC',
        captainName: 'Virgil van Dijk',
        captainImageUrl: 'https://upload.wikimedia.org/wikipedia/en/0/0c/Liverpool_FC.svg',
        date: 'August 9th / 7pm',
        stadium: 'Anfield',
        pricePerPerson: 115,
        currentPlayers: 9,
        maxPlayers: 12,
        points: 25,
        trend: 'stable',
        governorate: 'Alexandria',
        matchesPlayed: 14,
        wins: 7,
        draws: 4,
        losses: 3,
        playedOpponents: ['1', '2', '3', '5', '7', '8'],
        playerImages: [
          'https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1463453091185-61582044d556?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150&h=150&fit=crop&q=80',
        ],
      ),
      Team(
        id: '5',
        name: 'Bayern Munich',
        captainName: 'Thomas Müller',
        captainImageUrl: 'https://upload.wikimedia.org/wikipedia/commons/1/1b/FC_Bayern_M%C3%BCnchen_logo_%282017%29.svg',
        date: 'August 10th / 8pm',
        stadium: 'Allianz Arena',
        pricePerPerson: 125,
        currentPlayers: 11,
        maxPlayers: 14,
        points: 22,
        trend: 'down',
        governorate: 'Cairo',
        matchesPlayed: 14,
        wins: 6,
        draws: 4,
        losses: 4,
        playedOpponents: ['1', '2', '3', '4', '6'],
        playerImages: [
          'https://images.unsplash.com/photo-1566492031773-4f4e44671857?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1557862921-37829c790f19?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1504257432389-52343af06ae3?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1499996860823-5214fcc65f8f?w=150&h=150&fit=crop&q=80',
        ],
      ),
      Team(
        id: '6',
        name: 'Paris Saint-Germain',
        captainName: 'Marquinhos',
        captainImageUrl: 'https://upload.wikimedia.org/wikipedia/en/a/a7/Paris_Saint-Germain_F.C..svg',
        date: 'August 11th / 9pm',
        stadium: 'Parc des Princes',
        pricePerPerson: 130,
        currentPlayers: 7,
        maxPlayers: 11,
        points: 19,
        trend: 'down',
        governorate: 'Cairo',
        matchesPlayed: 14,
        wins: 5,
        draws: 4,
        losses: 5,
        playedOpponents: ['1', '2', '3', '5'],
        playerImages: [
          'https://images.unsplash.com/photo-1552058544-f2b08422138a?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1547425260-76bcadfb4f2c?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150&h=150&fit=crop&q=80',
        ],
      ),
      Team(
        id: '7',
        name: 'Chelsea FC',
        captainName: 'Reece James',
        captainImageUrl: 'https://upload.wikimedia.org/wikipedia/en/c/cc/Chelsea_FC.svg',
        date: 'August 12th / 7pm',
        stadium: 'Stamford Bridge',
        pricePerPerson: 105,
        currentPlayers: 6,
        maxPlayers: 11,
        points: 16,
        trend: 'up',
        governorate: 'Cairo',
        matchesPlayed: 14,
        wins: 4,
        draws: 4,
        losses: 6,
        playedOpponents: ['1', '2', '4'],
        playerImages: [
          'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&q=80',
        ],
      ),
      Team(
        id: '8',
        name: 'Juventus FC',
        captainName: 'Leonardo Bonucci',
        captainImageUrl: 'https://upload.wikimedia.org/wikipedia/commons/1/15/Juventus_FC_2017_logo.svg',
        date: 'August 13th / 8pm',
        stadium: 'Allianz Stadium',
        pricePerPerson: 95,
        currentPlayers: 8,
        maxPlayers: 12,
        points: 12,
        trend: 'down',
        governorate: 'Cairo',
        matchesPlayed: 14,
        wins: 3,
        draws: 3,
        losses: 8,
        playedOpponents: ['1', '4'],
        playerImages: [
          'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150&h=150&fit=crop&q=80',
        ],
      ),
      Team(
        id: '9',
        name: 'AC Milan',
        captainName: 'Davide Calabria',
        captainImageUrl: 'https://upload.wikimedia.org/wikipedia/commons/d/d0/Logo_of_AC_Milan.svg',
        date: 'August 14th / 9pm',
        stadium: 'San Siro',
        pricePerPerson: 90,
        currentPlayers: 5,
        maxPlayers: 10,
        points: 9,
        trend: 'down',
        governorate: 'Cairo',
        matchesPlayed: 14,
        wins: 2,
        draws: 3,
        losses: 9,
        playedOpponents: ['2'],
        playerImages: [
          'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1544723795-3fb6469f5b39?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=150&h=150&fit=crop&q=80',
        ],
      ),
      Team(
        id: '10',
        name: 'Atlético Madrid',
        captainName: 'Koke Resurrección',
        captainImageUrl: 'https://upload.wikimedia.org/wikipedia/en/f/f4/Atletico_Madrid_2017_logo.svg',
        date: 'August 15th / 7pm',
        stadium: 'Wanda Metropolitano',
        pricePerPerson: 85,
        currentPlayers: 4,
        maxPlayers: 10,
        points: 7,
        trend: 'down',
        governorate: 'Cairo',
        matchesPlayed: 14,
        wins: 1,
        draws: 4,
        losses: 9,
        playedOpponents: [],
        playerImages: [
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&q=80',
        ],
      ),
    ];
  }
}

/// Championship data model
class Championship {
  final String id;
  final String name;
  final String type; // Football, League, etc.
  final String logoUrl;
  final String startDate;
  final String endDate;
  final double entryFee;
  final double grandPrize;
  final int teamsJoined;
  final int maxTeams;
  final List<String> teamLogos;

  final String ownerId;
  final String governorate;
  final String sportType;

  Championship({
    required this.id,
    required this.name,
    required this.type,
    required this.logoUrl,
    required this.startDate,
    required this.endDate,
    required this.entryFee,
    required this.grandPrize,
    required this.teamsJoined,
    required this.maxTeams,
    required this.teamLogos,
    this.ownerId = '',
    this.governorate = 'Cairo',
    this.sportType = 'Football',
  });

  factory Championship.fromFirestore(Map<String, dynamic> data, String id) {
    return Championship(
      id: id,
      name: data['name'] ?? '',
      type: data['type'] ?? '',
      logoUrl: data['logoUrl'] ?? '',
      startDate: data['startDate'] ?? '',
      endDate: data['endDate'] ?? '',
      entryFee: (data['entryFee'] ?? 0).toDouble(),
      grandPrize: (data['grandPrize'] ?? 0).toDouble(),
      teamsJoined: data['teamsJoined'] ?? 0,
      maxTeams: data['maxTeams'] ?? 16,
      teamLogos: List<String>.from(data['teamLogos'] ?? []),
      ownerId: data['ownerId'] ?? '',
      governorate: data['governorate'] ?? 'Cairo',
      sportType: data['sportType'] ?? 'Football',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type,
      'logoUrl': logoUrl,
      'startDate': startDate,
      'endDate': endDate,
      'entryFee': entryFee,
      'grandPrize': grandPrize,
      'teamsJoined': teamsJoined,
      'maxTeams': maxTeams,
      'teamLogos': teamLogos,
      'ownerId': ownerId,
      'governorate': governorate,
      'sportType': sportType,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // Mock data
  static List<Championship> getMockChampionships() {
    return [
      Championship(
        id: '1',
        name: 'Champions League',
        type: 'Football • Cup',
        logoUrl: 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=150&h=150&fit=crop&q=80',
        startDate: 'Aug 10',
        endDate: 'Oct 15',
        entryFee: 1500,
        grandPrize: 5000,
        teamsJoined: 12,
        maxTeams: 16,
        teamLogos: [
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&h=100&fit=crop&q=80',
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop&q=80',
          'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop&q=80',
          'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=100&h=100&fit=crop&q=80',
        ],
      ),
      Championship(
        id: '2',
        name: 'Summer Cup',
        type: 'Football • Knockout',
        logoUrl: 'https://images.unsplash.com/photo-1522778119026-d647f0596c20?w=400&h=400&fit=crop&q=80', // Real Trophy/Stadium logo
        startDate: 'Jul 15',
        endDate: 'Aug 20',
        entryFee: 500,
        grandPrize: 1500,
        teamsJoined: 14,
        maxTeams: 16,
        teamLogos: [
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&h=100&fit=crop&q=80',
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop&q=80',
          'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop&q=80',
          'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=100&h=100&fit=crop&q=80',
        ],
      ),
      Championship(
        id: '3',
        name: 'Winter League',
        type: 'Football • League',
        logoUrl: 'https://upload.wikimedia.org/wikipedia/en/thumb/f/f2/Premier_League_Logo.svg/1200px-Premier_League_Logo.svg.png', // Real logo
        startDate: 'Dec 1',
        endDate: 'Feb 28',
        entryFee: 1000,
        grandPrize: 5000,
        teamsJoined: 4,
        maxTeams: 20,
        teamLogos: [
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&h=100&fit=crop&q=80',
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop&q=80',
          'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop&q=80',
          'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=100&h=100&fit=crop&q=80',
        ],
      ),
    ];
  }
}

/// Notification data model
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // 'info', 'result_confirmation'
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromFirestore(Map<String, dynamic> data, String id) {
    return AppNotification(
      id: id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: data['type'] ?? 'info',
      isRead: data['isRead'] ?? false,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] is Timestamp 
              ? (data['createdAt'] as Timestamp).toDate() 
              : DateTime.parse(data['createdAt']))
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
