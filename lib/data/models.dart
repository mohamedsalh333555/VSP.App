/// Stadium data model
class Stadium {
  final String id;
  final String name;
  final String location;
  final String imageUrl;
  final String type; // Football, Basketball, etc.
  final String size; // 11 VS 11, 5 VS 5, etc.
  final int baths;
  final int cafeteria;
  final int seatsCapacity;
  final double pricePerHour;
  final String area; // Jeresh, etc.
  final bool isFavorite;
  
  // Extended fields for details screen
  final String address;
  final double rating;
  final int reviewsCount;
  final String description;
  final List<String> features;
  final List<String> policies;
  final String pitchCondition;
  final bool hasJerash;
  final bool hasSeats;
  final bool hasBall;
  final double ballRentPrice;

  Stadium({
    required this.id,
    required this.name,
    required this.location,
    required this.imageUrl,
    required this.type,
    required this.size,
    required this.baths,
    required this.cafeteria,
    required this.seatsCapacity,
    required this.pricePerHour,
    required this.area,
    this.isFavorite = false,
    this.address = '',
    this.rating = 4.5,
    this.reviewsCount = 52,
    this.description = '',
    this.features = const [],
    this.policies = const [],
    this.pitchCondition = 'Excellent',
    this.hasJerash = true,
    this.hasSeats = true,
    this.hasBall = false,
    this.ballRentPrice = 20,
  });

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
        ballRentPrice: 20,
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
        ballRentPrice: 25,
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
        ballRentPrice: 30,
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
        ballRentPrice: 25,
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
        ballRentPrice: 35,
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
      imageUrl: data['imageUrl'] ?? 'https://via.placeholder.com/150',
      type: data['type'] ?? 'Football',
      size: data['size'] ?? '5x5',
      baths: data['baths'] ?? 0,
      cafeteria: data['cafeteria'] ?? 0,
      seatsCapacity: data['seatsCapacity'] ?? 0,
      pricePerHour: (data['pricePerHour'] ?? 0).toDouble(),
      area: data['area'] ?? '',
      isFavorite: data['isFavorite'] ?? false,
      address: data['address'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      reviewsCount: data['reviewsCount'] ?? 0,
      description: data['description'] ?? '',
      features: (data['features'] is List) ? List<String>.from(data['features']) : [],
      policies: (data['policies'] is List) ? List<String>.from(data['policies']) : [],
      pitchCondition: data['pitchCondition'] ?? 'Good',
      hasJerash: data['hasJerash'] ?? false,
      hasSeats: data['hasSeats'] ?? false,
      hasBall: data['hasBall'] ?? false,
      ballRentPrice: (data['ballRentPrice'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'location': location,
      'imageUrl': imageUrl,
      'type': type,
      'size': size,
      'baths': baths,
      'cafeteria': cafeteria,
      'seatsCapacity': seatsCapacity,
      'pricePerHour': pricePerHour,
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
      'ballRentPrice': ballRentPrice,
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

/// Booking data model
class Booking {
  final String id;
  final String stadiumId;
  final String date;
  final TimeSlot timeSlot;
  final bool isPrivate;
  final bool rentBall;
  final String bookingType; // 'personal', 'team', 'challenge'
  final String? teamId;
  final double totalPrice;

  Booking({
    required this.id,
    required this.stadiumId,
    required this.date,
    required this.timeSlot,
    this.isPrivate = false,
    this.rentBall = false,
    required this.bookingType,
    this.teamId,
    required this.totalPrice,
  });
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
    required this.playerImages,
    this.points = 0,
    this.trend = 'stable',
  });

  // Mock data
  static List<Team> getMockTeams() {
    return [
      Team(
        id: '1',
        name: 'Real Madrid CF',
        captainName: 'Mohamed Salah',
        captainImageUrl: 'https://images.unsplash.com/photo-1543351611-58f69d7c1781?w=150&h=150&fit=crop&q=80', // Real player portrait
        date: 'August 6th / 7pm',
        stadium: 'Santiago Bernabéu',
        pricePerPerson: 100,
        currentPlayers: 8,
        maxPlayers: 12,
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
        captainImageUrl: 'https://images.unsplash.com/photo-1516567727245-ad8c68f3ec93?w=150&h=150&fit=crop&q=80', // Real athlete face
        date: 'August 7th / 8pm',
        stadium: 'Camp Nou',
        pricePerPerson: 120,
        currentPlayers: 10,
        maxPlayers: 14,
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
        captainImageUrl: 'https://images.unsplash.com/photo-1551958219-acbc608c6377?w=150&h=150&fit=crop&q=80', // Real player on field
        date: 'August 8th / 9pm',
        stadium: 'Etihad Stadium',
        pricePerPerson: 110,
        currentPlayers: 5,
        maxPlayers: 10,
        playerImages: [
          'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1544723795-3fb6469f5b39?w=150&h=150&fit=crop&q=80',
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
  });

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
