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
  final DateTime? dateOfBirth;

  // P2P Receivables Settings
  final String? p2pInstapay;
  final String? p2pVodafone;
  final String? p2pBank;

  // 🔴 Kill Switch & Debt Flags
  final bool isBlocked; // ✅ Administrative user block
  final int noShowCount; // ✅ No-show count for spam protection

  // 💰 VSP SUBSCRIPTION PLAN (for owners)
  // Values: 'free_trial' | 'basic' | 'pro'
  final String subscriptionPlan;
  final DateTime? trialEndsAt;           // free_trial ends at
  final DateTime? subscriptionExpiresAt; // paid plan expiry

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
  });

  /// هل المستخدم مالك ملعب (سواء من حقل role أو امتلاك ملعب)؟
  bool get isOwnerRole => role == 'owner' || hasStadium;

  /// هل المستخدم لاعب فقط؟
  bool get isPlayerRole => !isOwnerRole;

  /// تاريخ نهاية الفترة التجريبية الفعلي (مع افتراض 60 يوماً من الإنشاء إذا كانت null)
  DateTime? get effectiveTrialEndsAt =>
      trialEndsAt ?? (createdAt != null ? createdAt!.add(const Duration(days: 60)) : DateTime.now().add(const Duration(days: 60)));

  /// هل المالك في فترة تجريبية نشطة؟ (يشترط عدم وجود أي اشتراك مدفوع مسبقاً)
  bool get isInActiveTrial =>
      subscriptionPlan == 'free_trial' &&
      subscriptionExpiresAt == null &&
      effectiveTrialEndsAt != null &&
      DateTime.now().isBefore(effectiveTrialEndsAt!);

  /// هل الاشتراك ساري (تجريبي أو مدفوع)؟
  bool get hasActiveSubscription =>
      isInActiveTrial ||
      (subscriptionExpiresAt != null &&
       DateTime.now().isBefore(subscriptionExpiresAt!));

  /// هل الباقة Pro وسارية؟
  bool get isProPlan =>
      subscriptionPlan == 'pro' &&
      subscriptionExpiresAt != null &&
      DateTime.now().isBefore(subscriptionExpiresAt!);

  /// هل يسمح للمالك بإنشاء وإدارة البطولات الاحترافية؟ (متاحة لجميع الملاك بدون استثناء)
  bool get canCreateTournaments => true;

  /// هل الباقة Basic أو أعلى (Pro يشمل Basic)؟
  bool get isBasicOrHigher =>
      (subscriptionPlan == 'basic' || subscriptionPlan == 'pro') &&
      subscriptionExpiresAt != null &&
      DateTime.now().isBefore(subscriptionExpiresAt!);

  /// هل الاشتراك منتهي؟
  bool get isPlanExpired => !hasActiveSubscription;

  /// الحد الأقصى لعدد الملاعب المسموح به حسب الباقة
  int get maxStadiums {
    if (isProPlan) return 3; // Pro: حتى 3 ملاعب
    if (isBasicOrHigher) return 1; // Basic: ملعب واحد
    if (isInActiveTrial) return 1; // Trial: ملعب واحد
    return 0; // منتهي — لا يقدر يضيف ملاعب جديدة
  }

  /// نص الباقة الحالية للعرض
  String get subscriptionPlanLabel {
    if (isProPlan) return 'Pro';
    if (isBasicOrHigher) return 'Basic';
    if (isInActiveTrial) {
      final remaining = effectiveTrialEndsAt!.difference(DateTime.now()).inDays;
      return 'تجريبي ($remaining يوم متبقي)';
    }
    return 'منتهي';
  }

  // Create UserModel from Firestore document
  factory UserModel.fromFirestore(Map<String, dynamic> data) {
    final rawAdditional = data['additionalData'] ?? data['additional_data'];
    final Map<String, dynamic> addData = rawAdditional is Map<String, dynamic>
        ? Map<String, dynamic>.from(rawAdditional)
        : <String, dynamic>{};
    
    if (data.containsKey('last_warning')) {
      addData['last_warning'] = data['last_warning'];
    }
    if (data.containsKey('rejection_reason')) {
      addData['rejection_reason'] = data['rejection_reason'];
    }

    return UserModel(
      uid: data['id'] ?? data['uid'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'player',
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
      dateOfBirth: data['date_of_birth'] != null ? DateTime.tryParse(data['date_of_birth']) : null,
      p2pInstapay: data['p2p_instapay'] ?? data['p2pInstapay'],
      p2pVodafone: data['p2p_vodafone'] ?? data['p2pVodafone'],
      p2pBank: data['p2p_bank'] ?? data['p2pBank'],
      // 💰 Subscription fields
      subscriptionPlan: data['subscription_plan'] ?? 'free_trial',
      trialEndsAt: data['trial_ends_at'] != null
          ? DateTime.tryParse(data['trial_ends_at'].toString())
          : null,
      subscriptionExpiresAt: data['subscription_expires_at'] != null
          ? DateTime.tryParse(data['subscription_expires_at'].toString())
          : null,
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
      'date_of_birth': dateOfBirth?.toUtc().toIso8601String(),
      'p2p_instapay': p2pInstapay,
      'p2p_vodafone': p2pVodafone,
      'p2p_bank': p2pBank,
      'subscription_plan': subscriptionPlan,
      'trial_ends_at': trialEndsAt?.toUtc().toIso8601String(),
      'subscription_expires_at': subscriptionExpiresAt?.toUtc().toIso8601String(),
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
    DateTime? dateOfBirth,
    String? p2pInstapay,
    String? p2pVodafone,
    String? p2pBank,
    String? subscriptionPlan,
    DateTime? trialEndsAt,
    DateTime? subscriptionExpiresAt,
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
    );
  }
}
