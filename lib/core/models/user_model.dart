class UserModel {
  final String uid;
  final String email;
  final String role; // 'player' or 'owner'
  final String? name;
  final String? phone;
  final String? profileImageUrl;
  final String? position;
  final Map<String, dynamic>? additionalData;
  final DateTime? createdAt;
  
  // Owner Registration Flags
  final bool isEmailVerified;
  final bool hasStadium;
  final bool isIdentityVerified;
  final bool isRegistrationComplete;
  final String? governorate;
  final List<String> favoriteStadiums;
  final String? verificationStatus; // 'pending', 'approved', 'rejected' or null

  // 🔴 Kill Switch & Debt Flags
  final bool isBlocked; // ✅ Administrative user block
  final int noShowCount; // ✅ No-show count for spam protection

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    this.name,
    this.phone,
    this.profileImageUrl,
    this.position,
    this.additionalData,
    this.createdAt,
    this.isEmailVerified = false,
    this.hasStadium = false,
    this.isIdentityVerified = false,
    this.isRegistrationComplete = false,
    this.governorate,
    this.isBlocked = false,
    this.favoriteStadiums = const [],
    this.verificationStatus,
    this.noShowCount = 0,
  });

  // Create UserModel from Firestore document
  factory UserModel.fromFirestore(Map<String, dynamic> data) {
    return UserModel(
      uid: data['id'] ?? data['uid'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'player',
      name: data['name'],
      phone: data['phone'],
      profileImageUrl: data['profile_image_url'] ?? data['profileImageUrl'],
      position: data['position'],
      additionalData: data['additionalData'] ?? data['additional_data'],
      createdAt: (data['created_at'] ?? data['createdAt']) != null
          ? ((data['created_at'] ?? data['createdAt']) is String
              ? DateTime.tryParse(data['created_at'] ?? data['createdAt'])
              : ((data['created_at'] ?? data['createdAt']) as dynamic).toDate())
          : null,
      isEmailVerified: data['is_email_verified'] ?? data['isEmailVerified'] ?? false,
      hasStadium: data['has_stadium'] ?? data['hasStadium'] ?? false,
      isIdentityVerified: data['is_identity_verified'] ?? data['isIdentityVerified'] ?? false,
      isRegistrationComplete: data['is_registration_complete'] ?? data['isRegistrationComplete'] ?? false,
      governorate: data['governorate'],
      isBlocked: data['is_blocked'] ?? data['isBlocked'] ?? false,
      favoriteStadiums: List<String>.from(data['favorite_stadiums'] ?? data['favoriteStadiums'] ?? []),
      verificationStatus: data['verification_status'] ?? data['verificationStatus'],
      noShowCount: data['no_show_count'] ?? data['noShowCount'] ?? 0,
    );
  }

  // Convert UserModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'role': role,
      'name': name,
      'phone': phone,
      'profile_image_url': profileImageUrl,
      'position': position,
      'additional_data': additionalData,
      'is_email_verified': isEmailVerified,
      'has_stadium': hasStadium,
      'is_identity_verified': isIdentityVerified,
      'is_registration_complete': isRegistrationComplete,
      'governorate': governorate,
      'is_blocked': isBlocked,
      'favorite_stadiums': favoriteStadiums,
      'verification_status': verificationStatus,
      'no_show_count': noShowCount,
    };
  }

  // Copy with method
  UserModel copyWith({
    String? uid,
    String? email,
    String? role,
    String? name,
    String? phone,
    String? profileImageUrl,
    String? position,
    Map<String, dynamic>? additionalData,
    DateTime? createdAt,
    bool? isEmailVerified,
    bool? hasStadium,
    bool? isIdentityVerified,
    bool? isRegistrationComplete,
    String? governorate,
    bool? isBlocked,
    List<String>? favoriteStadiums,
    String? verificationStatus,
    int? noShowCount,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      role: role ?? this.role,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      position: position ?? this.position,
      additionalData: additionalData ?? this.additionalData,
      createdAt: createdAt ?? this.createdAt,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      hasStadium: hasStadium ?? this.hasStadium,
      isIdentityVerified: isIdentityVerified ?? this.isIdentityVerified,
      isRegistrationComplete: isRegistrationComplete ?? this.isRegistrationComplete,
      governorate: governorate ?? this.governorate,
      isBlocked: isBlocked ?? this.isBlocked,
      favoriteStadiums: favoriteStadiums ?? this.favoriteStadiums,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      noShowCount: noShowCount ?? this.noShowCount,
    );
  }
}
