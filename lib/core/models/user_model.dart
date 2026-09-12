class UserModel {
  final String uid;
  final String email;
  final String role; // 'player', 'owner', 'admin', 'co_founder'
  final String? name;
  final String? phone;
  final String? profileImageUrl;
  final String? position;
  final Map<String, dynamic>? additionalData;
  final DateTime? createdAt;
  
  // Registration & Verification Flags
  final bool isEmailVerified;
  final bool hasStadium;
  final bool isIdentityVerified;
  final bool isRegistrationComplete;
  final String? governorate;
  final List<String> favoriteStadiums;
  final String? verificationStatus; // 'pending', 'approved', 'rejected'
  final DateTime? dateOfBirth;

  // P2P Receivables Settings
  final String? p2pInstapay;
  final String? p2pVodafone;
  final String? p2pBank;

  // Administrative Moderation & Anti-Spam
  final bool isBlocked;
  final int noShowCount;

  // VSP Subscription Plan (for owners)
  final String subscriptionPlan;
  final DateTime? trialEndsAt;
  final DateTime? subscriptionExpiresAt;
  final String favoriteSport;
  final bool isOnboardingConfirmed;

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
    this.dateOfBirth,
    this.p2pInstapay,
    this.p2pVodafone,
    this.p2pBank,
    this.subscriptionPlan = 'free_trial',
    this.trialEndsAt,
    this.subscriptionExpiresAt,
    this.favoriteSport = 'Football',
    this.isOnboardingConfirmed = false,
  });

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin' || role == 'co_founder' || role == 'super_admin';
  bool get isPlayer => !isOwner && !isAdmin;
  bool get isOwnerRole => role == 'owner';
  bool get isPlayerRole => !isOwnerRole && !isAdmin;

  DateTime? get effectiveTrialEndsAt =>
      trialEndsAt ?? createdAt?.add(const Duration(days: 60));

  bool get isInActiveTrial =>
      subscriptionPlan == 'free_trial' &&
      subscriptionExpiresAt == null &&
      effectiveTrialEndsAt != null &&
      DateTime.now().isBefore(effectiveTrialEndsAt!);

  bool get hasActiveSubscription =>
      isInActiveTrial ||
      (subscriptionExpiresAt != null &&
       DateTime.now().isBefore(subscriptionExpiresAt!));

  bool get isPro => isProPlan || subscriptionPlan == 'pro';

  bool get isProPlan =>
      subscriptionPlan == 'pro' &&
      subscriptionExpiresAt != null &&
      DateTime.now().isBefore(subscriptionExpiresAt!);

  bool get canCreateTournaments => true;

  bool get isBasicOrHigher =>
      (subscriptionPlan == 'basic' || subscriptionPlan == 'pro') &&
      subscriptionExpiresAt != null &&
      DateTime.now().isBefore(subscriptionExpiresAt!);

  bool get isPlanExpired => !hasActiveSubscription;

  int get maxStadiums {
    if (isProPlan) return 3;
    if (isBasicOrHigher || isInActiveTrial) return 1;
    return 0;
  }

  String get subscriptionPlanLabel {
    if (isProPlan) return 'Pro';
    if (isBasicOrHigher) return 'Basic';
    if (isInActiveTrial) {
      final remaining = effectiveTrialEndsAt!.difference(DateTime.now()).inDays;
      return 'تجريبي ($remaining يوم متبقي)';
    }
    return 'منتهي';
  }

  factory UserModel.fromMap(Map<String, dynamic> data) {
    final rawAdditional = data['additional_data'] ?? data['additionalData'];
    final Map<String, dynamic> addData = rawAdditional is Map<String, dynamic>
        ? Map<String, dynamic>.from(rawAdditional)
        : <String, dynamic>{};
    
    if (data.containsKey('last_warning')) {
      addData['last_warning'] = data['last_warning'];
    }
    if (data.containsKey('rejection_reason')) {
      addData['rejection_reason'] = data['rejection_reason'];
    }

    final rawRole = (data['role'] ?? addData['role'] ?? 'player').toString();
    final bool hasOwnerIndicator = data['has_stadium'] == true ||
        data['hasStadium'] == true ||
        addData['role'] == 'owner' ||
        addData['is_owner'] == true;
    final effectiveRole = (rawRole != 'admin' && rawRole != 'co_founder' && hasOwnerIndicator)
        ? 'owner'
        : rawRole;

    return UserModel(
      uid: data['id'] ?? data['uid'] ?? '',
      email: data['email'] ?? '',
      role: effectiveRole,
      name: data['name'],
      phone: data['phone'],
      profileImageUrl: data['profile_image_url'] ?? data['profileImageUrl'],
      position: data['position'],
      additionalData: addData.isNotEmpty ? addData : null,
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
      dateOfBirth: (data['date_of_birth'] ?? data['dateOfBirth']) != null
          ? DateTime.tryParse((data['date_of_birth'] ?? data['dateOfBirth']).toString())
          : null,
      p2pInstapay: data['p2p_instapay'] ?? data['p2pInstapay'],
      p2pVodafone: data['p2p_vodafone'] ?? data['p2pVodafone'],
      p2pBank: data['p2p_bank'] ?? data['p2pBank'],
      subscriptionPlan: data['subscription_plan'] ?? data['subscriptionPlan'] ?? 'free_trial',
      trialEndsAt: (data['trial_ends_at'] ?? data['trialEndsAt']) != null
          ? DateTime.tryParse((data['trial_ends_at'] ?? data['trialEndsAt']).toString())
          : null,
      subscriptionExpiresAt: (data['subscription_expires_at'] ?? data['subscriptionExpiresAt']) != null
          ? DateTime.tryParse((data['subscription_expires_at'] ?? data['subscriptionExpiresAt']).toString())
          : null,
      favoriteSport: data['favorite_sport'] ?? data['favoriteSport'] ?? 'Football',
      isOnboardingConfirmed: data['is_onboarding_confirmed'] == true ||
          data['isOnboardingConfirmed'] == true ||
          (addData['isOnboardingConfirmed'] == true),
    );
  }

  // Backward compatibility alias
  factory UserModel.fromFirestore(Map<String, dynamic> data) => UserModel.fromMap(data);

  Map<String, dynamic> toMap() {
    return {
      'id': uid,
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
      'date_of_birth': dateOfBirth?.toUtc().toIso8601String(),
      'p2p_instapay': p2pInstapay,
      'p2p_vodafone': p2pVodafone,
      'p2p_bank': p2pBank,
      'subscription_plan': subscriptionPlan,
      'trial_ends_at': trialEndsAt?.toUtc().toIso8601String(),
      'subscription_expires_at': subscriptionExpiresAt?.toUtc().toIso8601String(),
      'favorite_sport': favoriteSport,
      'is_onboarding_confirmed': isOnboardingConfirmed,
    };
  }

  // Backward compatibility alias
  Map<String, dynamic> toFirestore() => toMap();

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
    DateTime? dateOfBirth,
    String? p2pInstapay,
    String? p2pVodafone,
    String? p2pBank,
    String? subscriptionPlan,
    DateTime? trialEndsAt,
    DateTime? subscriptionExpiresAt,
    String? favoriteSport,
    bool? isOnboardingConfirmed,
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
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      p2pInstapay: p2pInstapay ?? this.p2pInstapay,
      p2pVodafone: p2pVodafone ?? this.p2pVodafone,
      p2pBank: p2pBank ?? this.p2pBank,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      trialEndsAt: trialEndsAt ?? this.trialEndsAt,
      subscriptionExpiresAt: subscriptionExpiresAt ?? this.subscriptionExpiresAt,
      favoriteSport: favoriteSport ?? this.favoriteSport,
      isOnboardingConfirmed: isOnboardingConfirmed ?? this.isOnboardingConfirmed,
    );
  }
}
