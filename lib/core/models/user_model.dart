class UserModel {
  final String uid;
  final String email;
  final String role; // 'player' or 'owner'
  final String? name;
  final String? phone;
  final String? profileImageUrl;
  final Map<String, dynamic>? additionalData;
  final DateTime? createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    this.name,
    this.phone,
    this.profileImageUrl,
    this.additionalData,
    this.createdAt,
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
      additionalData: data['additionalData'],
      createdAt: data['createdAt']?.toDate(),
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
      'additionalData': additionalData,
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
    Map<String, dynamic>? additionalData,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      role: role ?? this.role,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      additionalData: additionalData ?? this.additionalData,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
