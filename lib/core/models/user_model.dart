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
    );
  }
}
