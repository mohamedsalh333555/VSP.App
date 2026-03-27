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

  // 🔴 Kill Switch & Debt Flags
  final bool isSuspended;
  final bool isBlocked; // ✅ Administrative user block
  final double commissionDebt;

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
    this.isSuspended = false,
    this.isBlocked = false,
    this.commissionDebt = 0.0,
    this.favoriteStadiums = const [],
  });

  // Create UserModel from Firestore document
  factory UserModel.fromFirestore(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'player',
      name: data['name'],
      phone: data['phone'],
      profileImageUrl: data['profileImageUrl'],
      position: data['position'],
      additionalData: data['additionalData'],
      createdAt: data['createdAt']?.toDate(),
      isEmailVerified: data['isEmailVerified'] ?? false,
      hasStadium: data['hasStadium'] ?? false,
      isIdentityVerified: data['isIdentityVerified'] ?? false,
      isRegistrationComplete: data['isRegistrationComplete'] ?? false,
      governorate: data['governorate'],
      isSuspended: data['isSuspended'] ?? false,
      isBlocked: data['isBlocked'] ?? false,
      commissionDebt: (data['commissionDebt'] ?? 0).toDouble(),
      favoriteStadiums: List<String>.from(data['favoriteStadiums'] ?? []),
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
      'profileImageUrl': profileImageUrl,
      'position': position,
      'additionalData': additionalData,
      'isEmailVerified': isEmailVerified,
      'hasStadium': hasStadium,
      'isIdentityVerified': isIdentityVerified,
      'isRegistrationComplete': isRegistrationComplete,
      'governorate': governorate,
      'isSuspended': isSuspended,
      'isBlocked': isBlocked,
      'commissionDebt': commissionDebt,
      'favoriteStadiums': favoriteStadiums,
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
    bool? isSuspended,
    bool? isBlocked,
    double? commissionDebt,
    List<String>? favoriteStadiums,
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
      isSuspended: isSuspended ?? this.isSuspended,
      isBlocked: isBlocked ?? this.isBlocked,
      commissionDebt: commissionDebt ?? this.commissionDebt,
      favoriteStadiums: favoriteStadiums ?? this.favoriteStadiums,
    );
  }
}
