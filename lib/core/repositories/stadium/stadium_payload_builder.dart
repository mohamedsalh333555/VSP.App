/// Pure domain helper for sanitizing, formatting, and constructing
/// database insert and update payloads for stadiums in Supabase.
class StadiumPayloadBuilder {
  const StadiumPayloadBuilder._();

  /// Formats time strings into standard HH:mm:ss format for Postgres TIME column.
  static String? formatTimeToHms(dynamic timeVal) {
    if (timeVal == null) return null;
    final str = timeVal.toString().trim();
    if (str.isEmpty) return null;
    final parts = str.split(':');
    if (parts.length == 1) {
      final h = int.tryParse(parts[0]) ?? 0;
      return '${h.toString().padLeft(2, '0')}:00:00';
    } else if (parts.length == 2) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:00';
    } else if (parts.length >= 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final s = int.tryParse(parts[2]) ?? 0;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return str;
  }

  /// Builds a sanitized map payload for inserting a new stadium into Postgres.
  static Map<String, dynamic> buildInsertPayload(Map<String, dynamic> rawData) {
    final sanitizedData = Map<String, dynamic>.from(rawData);
    sanitizedData.remove('isVerified');
    sanitizedData.remove('is_verified');
    sanitizedData.remove('createdAt');
    sanitizedData.remove('created_at');

    final price = sanitizedData['pricePerHour'] ?? sanitizedData['price_per_hour'] ?? 0.0;
    final features = sanitizedData['features'] ?? {};
    final String sport = features['sportType'] ?? sanitizedData['sportType'] ?? sanitizedData['type'] ?? 'Football';
    final String originalDesc = sanitizedData['description'] ?? sanitizedData['notes'] ?? '';
    final String descWithSport = "$originalDesc|Sport:$sport";

    final ppt = sanitizedData['players_per_team'] ?? sanitizedData['seatsCapacity'] ?? 5;
    final tfc = sanitizedData['total_field_capacity'] ?? (ppt * 2);

    final imagesList = sanitizedData['images'] ?? (sanitizedData['imageUrl'] != null ? [sanitizedData['imageUrl']] : []);
    final firstImage = (imagesList is List && imagesList.isNotEmpty) ? imagesList.first : null;

    final bool isSplitShift = sanitizedData['isSplitShift'] == true ||
        sanitizedData['is_split_shift'] == true ||
        (features is Map && features['isSplitShift'] == true);

    dynamic rawBreakStart = sanitizedData['breakStartTime'] ??
        sanitizedData['break_start_time'] ??
        ((features is Map && features['breakTime'] is Map) ? features['breakTime']['start'] : null);
    dynamic rawBreakEnd = sanitizedData['breakEndTime'] ??
        sanitizedData['break_end_time'] ??
        ((features is Map && features['breakTime'] is Map) ? features['breakTime']['end'] : null);

    return {
      'name': sanitizedData['name'],
      'owner_id': sanitizedData['ownerId'] ?? sanitizedData['owner_id'],
      'description': descWithSport,
      'notes': sanitizedData['notes'] ?? '',
      'features': features,
      'opening_time': sanitizedData['openingTime'] ??
          sanitizedData['opening_time'] ??
          ((features is Map && features['workingHours'] is Map) ? features['workingHours']['start'] : null),
      'closing_time': sanitizedData['closingTime'] ??
          sanitizedData['closing_time'] ??
          ((features is Map && features['workingHours'] is Map) ? features['workingHours']['end'] : null),
      'is_split_shift': isSplitShift,
      'break_start_time': isSplitShift ? formatTimeToHms(rawBreakStart) : null,
      'break_end_time': isSplitShift ? formatTimeToHms(rawBreakEnd) : null,
      'players_per_team': ppt,
      'total_field_capacity': tfc,
      'governorate': sanitizedData['governorate'] ?? 'Cairo',
      'city': sanitizedData['area'] ?? sanitizedData['location'] ?? 'Cairo',
      'location': sanitizedData['address'] ?? sanitizedData['location'] ?? '',
      'price_per_hour': price,
      'base_price': sanitizedData['basePrice'] ?? sanitizedData['base_price'] ?? price,
      'images': imagesList,
      'image_url': sanitizedData['imageUrl'] ?? sanitizedData['image_url'] ?? firstImage,
      'is_verified': false,
      'is_blocked': false,
      'is_deleted_by_owner': false,
      'rating': 0.0,
      'reviews_count': 0,
      'deposit_amount': sanitizedData['depositAmount'] ?? sanitizedData['deposit_amount'] ?? 0.0,
      'needs_deposit': sanitizedData['needsDeposit'] ?? sanitizedData['needs_deposit'] ?? false,
      'lat': sanitizedData['lat'],
      'lng': sanitizedData['lng'],
    };
  }

  /// Builds a sanitized map payload for updating an existing stadium in Postgres.
  static Map<String, dynamic> buildUpdatePayload(Map<String, dynamic> data) {
    final securedData = Map<String, dynamic>.from(data);
    securedData.remove('ownerId');
    securedData.remove('owner_id');
    securedData.remove('createdAt');
    securedData.remove('created_at');

    final pgData = <String, dynamic>{};
    if (securedData.containsKey('name')) pgData['name'] = securedData['name'];
    if (securedData.containsKey('description') || securedData.containsKey('sportType') || securedData.containsKey('type')) {
      final String sport = securedData['sportType'] ?? securedData['type'] ?? 'Football';
      String desc = securedData['description'] ?? '';
      desc = desc.replaceAll(RegExp(r'\|Sport:[^|]*'), '').trim();
      pgData['description'] = '$desc|Sport:$sport';
    }
    if (securedData.containsKey('features')) {
      pgData['features'] = securedData['features'];
      final feat = securedData['features'];
      if (feat is Map && feat['workingHours'] is Map) {
        if (feat['workingHours']['start'] != null) pgData['opening_time'] = feat['workingHours']['start'];
        if (feat['workingHours']['end'] != null) pgData['closing_time'] = feat['workingHours']['end'];
      }
      if (feat is Map && feat.containsKey('isSplitShift')) {
        pgData['is_split_shift'] = feat['isSplitShift'] == true;
        if (feat['isSplitShift'] == true && feat['breakTime'] is Map) {
          pgData['break_start_time'] = formatTimeToHms(feat['breakTime']['start']);
          pgData['break_end_time'] = formatTimeToHms(feat['breakTime']['end']);
        } else if (feat['isSplitShift'] == false) {
          pgData['break_start_time'] = null;
          pgData['break_end_time'] = null;
        }
      }
    }
    if (securedData.containsKey('isSplitShift') || securedData.containsKey('is_split_shift')) {
      final bool isSplit = securedData['isSplitShift'] == true || securedData['is_split_shift'] == true;
      pgData['is_split_shift'] = isSplit;
      if (!isSplit) {
        pgData['break_start_time'] = null;
        pgData['break_end_time'] = null;
      }
    }
    if (securedData.containsKey('breakStartTime')) pgData['break_start_time'] = formatTimeToHms(securedData['breakStartTime']);
    if (securedData.containsKey('break_start_time')) pgData['break_start_time'] = formatTimeToHms(securedData['break_start_time']);
    if (securedData.containsKey('breakEndTime')) pgData['break_end_time'] = formatTimeToHms(securedData['breakEndTime']);
    if (securedData.containsKey('break_end_time')) pgData['break_end_time'] = formatTimeToHms(securedData['break_end_time']);
    if (securedData.containsKey('openingTime')) pgData['opening_time'] = securedData['openingTime'];
    if (securedData.containsKey('opening_time')) pgData['opening_time'] = securedData['opening_time'];
    if (securedData.containsKey('closingTime')) pgData['closing_time'] = securedData['closingTime'];
    if (securedData.containsKey('closing_time')) pgData['closing_time'] = securedData['closing_time'];
    if (securedData.containsKey('governorate')) pgData['governorate'] = securedData['governorate'];
    if (securedData.containsKey('address')) pgData['location'] = securedData['address'];
    if (securedData.containsKey('location')) pgData['location'] = securedData['location'];
    if (securedData.containsKey('pricePerHour')) pgData['price_per_hour'] = securedData['pricePerHour'];
    if (securedData.containsKey('price_per_hour')) pgData['price_per_hour'] = securedData['price_per_hour'];
    if (securedData.containsKey('basePrice')) pgData['base_price'] = securedData['basePrice'];
    if (securedData.containsKey('base_price')) pgData['base_price'] = securedData['base_price'];
    if (securedData.containsKey('images')) pgData['images'] = securedData['images'];
    if (securedData.containsKey('imageUrl')) pgData['image_url'] = securedData['imageUrl'];
    if (securedData.containsKey('image_url')) pgData['image_url'] = securedData['image_url'];
    if (securedData.containsKey('isBlocked')) pgData['is_blocked'] = securedData['isBlocked'];
    if (securedData.containsKey('is_blocked')) pgData['is_blocked'] = securedData['is_blocked'];
    if (securedData.containsKey('is_verified')) pgData['is_verified'] = securedData['is_verified'];
    if (securedData.containsKey('isVerified')) pgData['is_verified'] = securedData['isVerified'];
    if (securedData.containsKey('is_deleted_by_owner')) pgData['is_deleted_by_owner'] = securedData['is_deleted_by_owner'];
    if (securedData.containsKey('rating')) pgData['rating'] = securedData['rating'];
    if (securedData.containsKey('reviewsCount')) pgData['reviews_count'] = securedData['reviewsCount'];
    if (securedData.containsKey('reviews_count')) pgData['reviews_count'] = securedData['reviews_count'];
    if (securedData.containsKey('deposit_amount')) pgData['deposit_amount'] = securedData['deposit_amount'];
    if (securedData.containsKey('depositAmount')) pgData['deposit_amount'] = securedData['depositAmount'];
    if (securedData.containsKey('needs_deposit')) pgData['needs_deposit'] = securedData['needs_deposit'];
    if (securedData.containsKey('needsDeposit')) pgData['needs_deposit'] = securedData['needsDeposit'];
    if (securedData.containsKey('players_per_team')) pgData['players_per_team'] = securedData['players_per_team'];
    if (securedData.containsKey('total_field_capacity')) pgData['total_field_capacity'] = securedData['total_field_capacity'];
    if (securedData.containsKey('lat')) pgData['lat'] = securedData['lat'];
    if (securedData.containsKey('lng')) pgData['lng'] = securedData['lng'];

    // Keep base_price in sync with price_per_hour if modified
    if (pgData.containsKey('price_per_hour') && !pgData.containsKey('base_price')) {
      pgData['base_price'] = pgData['price_per_hour'];
    }

    return pgData;
  }
}
