import '../../core/services/remote_config_service.dart';

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
 final String? governorate; // Added for filtering
 final double depositAmount; // Owner's determined deposit amount
 final bool needsDeposit; // Owner's deposit requirement flag
 
 // Backward compatibility getter
 int get seatsCapacity => totalFieldCapacity;

 // Format stadium name to always start with 'ملعب'
 String get formattedName {
 final trimmed = name.trim();
 if (trimmed.isEmpty) return 'ملعب';
 if (trimmed.startsWith('ملعب')) return trimmed;
 return 'ملعب $trimmed';
 }

 /// Google Maps direct link generated from coordinates or address
 String? get googleMapsUrl {
 if (lat != null && lng != null) {
 return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
 }
 if (location.trim().isNotEmpty) {
 return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(location.trim())}';
 }
 return null;
 }

 /// Stadium / Owner contact phone if provided in features
 String? get phone {
 if (features is Map) {
 return features['phone']?.toString() ??
 features['ownerPhone']?.toString() ??
 features['contactPhone']?.toString();
 }
 return null;
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
 final String notes; // Owner's custom pitch condition notes
 final String? contractUrl;
 final String? ownerIdUrl;
 final bool isVerified;
 final bool isFeatured; // Added featured status
 final String ownerId; // Stadium owner's UID
 final bool isBlocked; // Administrative block flag for debt management
 
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
 this.notes = '', // Default empty notes
 this.contractUrl,
 this.ownerIdUrl,
 this.isVerified = false,
 this.isFeatured = false, // Default to false
 this.ownerId = '', // Default empty ownerId
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
 this.governorate, // Added for filtering
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

 factory Stadium.fromMap(Map<String, dynamic> data, [String? id]) =>
 Stadium.fromFirestore(data, id ?? (data['id']?.toString() ?? ''));

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

  final defaultStadiumPrice = RemoteConfigService().stadiumPriceDefault;
  final rawPPH = data['pricePerHour'] ?? data['price_per_hour'] ?? defaultStadiumPrice;
  final double parsedPricePerHour = (rawPPH is num) ? rawPPH.toDouble() : (double.tryParse(rawPPH.toString()) ?? defaultStadiumPrice);

  final rawBasePrice = data['basePrice'] ?? data['pricePerHour'] ?? data['price_per_hour'] ?? defaultStadiumPrice;
  double parsedBasePrice = (rawBasePrice is num) ? rawBasePrice.toDouble() : (double.tryParse(rawBasePrice.toString()) ?? parsedPricePerHour);
  if (parsedBasePrice <= 0) parsedBasePrice = defaultStadiumPrice;

 final rawRating = data['rating'] ?? 0.0;
 final double parsedRating = (rawRating is num) ? rawRating.toDouble() : (double.tryParse(rawRating.toString()) ?? 0.0);

 final rawBallPrice = data['ballPrice'] ?? (data['features'] is Map ? data['features']['ballPrice'] ?? 0 : 0);
 final double parsedBallPrice = (rawBallPrice is num) ? rawBallPrice.toDouble() : (double.tryParse(rawBallPrice.toString()) ?? 0.0);

 final rawDeposit = data['deposit_amount'] ?? data['depositAmount'] ?? 0.0;
 final double parsedDeposit = (rawDeposit is num) ? rawDeposit.toDouble() : (double.tryParse(rawDeposit.toString()) ?? 0.0);

 return Stadium(
 id: id,
 name: data['name'] ?? '',
 location: data['location'] ?? data['address'] ?? '',
 governorate: data['governorate'], // Added for filtering
 type: sportType,
 size: data['size'] ?? '5 VS 5',
 imageUrl: parsedImages.isNotEmpty ? parsedImages.first : (data['imageUrl'] ?? data['image_url'] ?? ''),
 images: parsedImages,
 baths: data['baths'] ?? 0,
 cafeteria: data['cafeteria'] ?? 0,
 playersPerTeam: ppt,
 totalFieldCapacity: tfc,
 pricePerHour: parsedPricePerHour,
 basePrice: parsedBasePrice,
 area: data['area'] ?? data['city'] ?? data['governorate'] ?? '',
 isFavorite: data['isFavorite'] ?? false,
 address: data['address'] ?? '',
 rating: parsedRating,
 reviewsCount: data['reviewsCount'] ?? data['reviews_count'] ?? 0,
 description: cleanDesc,
 features: data['features'] ?? {},
 policies: (data['policies'] is List) ? List<String>.from(data['policies']) : [],
 pitchCondition: data['pitchCondition'] ?? 'Good',
 hasJerash: data['hasJerash'] ?? (data['features'] is Map ? data['features']['hasJerash'] ?? false : false),
 hasSeats: data['hasSeats'] ?? (data['features'] is Map ? data['features']['hasSeats'] ?? false : false),
 hasBall: data['hasBall'] ?? (data['features'] is Map ? data['features']['hasBall'] ?? false : false),
 ballPrice: parsedBallPrice,
 notes: (data['notes'] as String?) ?? '', // Read notes
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
 lat: (data['lat'] is num) ? (data['lat'] as num).toDouble() : double.tryParse(data['lat']?.toString() ?? ''),
 lng: (data['lng'] is num) ? (data['lng'] as num).toDouble() : double.tryParse(data['lng']?.toString() ?? ''),
 depositAmount: parsedDeposit,
 needsDeposit: data['needs_deposit'] ?? data['needsDeposit'] ?? false,
 maintenanceUntil: data['maintenance_until'] != null ? DateTime.tryParse(data['maintenance_until'].toString()) : null,
 maintenanceReason: data['maintenance_reason'],
 lastEmergencyClosureAt: data['last_emergency_closure_at'] != null ? DateTime.tryParse(data['last_emergency_closure_at'].toString()) : null,
 );
 }

 Map<String, dynamic> toMap() => toFirestore();

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

