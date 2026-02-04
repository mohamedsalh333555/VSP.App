/// نموذج المستخدم
class UserModel {
  final String email;
  final String userType; // 'player' or 'owner'
  final bool isVerified;
  final bool hasCompletedOnboarding;

  UserModel({
    required this.email,
    required this.userType,
    this.isVerified = false,
    this.hasCompletedOnboarding = false,
  });

  UserModel copyWith({
    String? email,
    String? userType,
    bool? isVerified,
    bool? hasCompletedOnboarding,
  }) {
    return UserModel(
      email: email ?? this.email,
      userType: userType ?? this.userType,
      isVerified: isVerified ?? this.isVerified,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
    );
  }
}
