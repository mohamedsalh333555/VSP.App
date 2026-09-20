import 'package:flutter/foundation.dart';

/// Defines the risk level associated with executing or triggering an AI capability.
enum AiRiskLevel {
  /// Read-only inquiries (e.g. searching stadiums, viewing financial totals)
  read,

  /// Low-risk mutations (e.g. updating profile fields, navigation)
  low,

  /// High-risk mutations requiring validation, atomic locking, or confirmation (e.g. bookings, cancellations)
  high,
}

/// Defines how the client application should process the capability's action.
enum AiActionType {
  /// Pure AI execution completed on the server; no immediate navigation required.
  execute,

  /// AI points the user directly to a verified app screen to perform the task manually.
  navigate,

  /// AI executes a verified server operation (e.g. atomic lock), then navigates to a destination (e.g. checkout).
  executeThenNavigate,
}

/// Represents a single declarative AI capability within the VSP operating system.
@immutable
class AiCapability {
  /// Unique identifier of the capability (e.g. PLAYER_CREATE_BOOKING)
  final String id;

  /// Role permitted to access this capability ('player', 'owner', 'admin', 'any')
  final String role;

  /// Required subscription entitlement ('none', 'owner_ai', 'admin_ai')
  final String requiredEntitlement;

  /// Whether the AI engine can execute this capability directly via tools/RPC
  final bool canExecuteByAi;

  /// The action type emitted when this capability is triggered
  final AiActionType actionType;

  /// The trusted client destination route (null if actionType == execute)
  final String? destinationRoute;

  /// Essential parameters required for execution
  final List<String> requiredParams;

  /// Whether user confirmation (Action Chip or Dialog) is required before final commit
  final bool confirmationRequired;

  /// Associated risk level
  final AiRiskLevel riskLevel;

  /// Human-readable Arabic description
  final String descriptionAr;

  const AiCapability({
    required this.id,
    required this.role,
    this.requiredEntitlement = 'none',
    required this.canExecuteByAi,
    required this.actionType,
    this.destinationRoute,
    this.requiredParams = const [],
    this.confirmationRequired = false,
    this.riskLevel = AiRiskLevel.read,
    required this.descriptionAr,
  });
}

/// Central registry of all approved VSP AI capabilities.
/// Acts as the single source of truth for AI actions in the client.
class AiCapabilityRegistry {
  AiCapabilityRegistry._();

  // -------------------------------------------------------------
  // Player Capabilities
  // -------------------------------------------------------------

  static const playerSearchStadiums = AiCapability(
    id: 'PLAYER_SEARCH_STADIUMS',
    role: 'player',
    canExecuteByAi: true,
    actionType: AiActionType.execute,
    riskLevel: AiRiskLevel.read,
    descriptionAr: 'البحث عن الملاعب المتاحة حسب المحافظة أو الاسم',
  );

  static const playerSearchTournaments = AiCapability(
    id: 'PLAYER_SEARCH_TOURNAMENTS',
    role: 'player',
    canExecuteByAi: true,
    actionType: AiActionType.execute,
    riskLevel: AiRiskLevel.read,
    descriptionAr: 'استعراض البطولات المفتوحة للتسجيل',
  );

  static const playerSearchOpenMatches = AiCapability(
    id: 'PLAYER_SEARCH_OPEN_MATCHES',
    role: 'player',
    canExecuteByAi: true,
    actionType: AiActionType.execute,
    riskLevel: AiRiskLevel.read,
    descriptionAr: 'البحث عن التقسيمات وماتشات الحجز المفتوح للاعبين',
  );

  static const playerCheckAvailability = AiCapability(
    id: 'PLAYER_CHECK_AVAILABILITY',
    role: 'player',
    canExecuteByAi: true,
    actionType: AiActionType.execute,
    riskLevel: AiRiskLevel.read,
    descriptionAr: 'فحص الفترات والساعات المتاحة للحجز في ملعب محدد',
  );

  static const playerCreateBooking = AiCapability(
    id: 'PLAYER_CREATE_BOOKING',
    role: 'player',
    canExecuteByAi: true,
    actionType: AiActionType.executeThenNavigate,
    destinationRoute: '/checkout',
    requiredParams: ['booking_id', 'stadium_id', 'start_time', 'end_time', 'total_price'],
    confirmationRequired: false, // Checkout payment acts as the confirmation
    riskLevel: AiRiskLevel.high,
    descriptionAr: 'قفل موعد الحجز ذرياً وفتح شاشة الدفع لإتمام العربون',
  );

  static const playerViewBookings = AiCapability(
    id: 'PLAYER_VIEW_BOOKINGS',
    role: 'player',
    canExecuteByAi: true,
    actionType: AiActionType.executeThenNavigate,
    destinationRoute: '/player', // Tab 3: Bookings
    riskLevel: AiRiskLevel.read,
    descriptionAr: 'عرض سجل الحجوزات النشطة والسابقة ومستحقات الاسترداد',
  );

  static const playerCancelBooking = AiCapability(
    id: 'PLAYER_CANCEL_BOOKING',
    role: 'player',
    canExecuteByAi: true,
    actionType: AiActionType.execute,
    requiredParams: ['booking_id'],
    confirmationRequired: true,
    riskLevel: AiRiskLevel.high,
    descriptionAr: 'إلغاء حجز محدد للمستخدم مع تسجيل سبب الإلغاء والاسترداد',
  );

  static const playerEditProfile = AiCapability(
    id: 'PLAYER_EDIT_PROFILE',
    role: 'player',
    canExecuteByAi: false,
    actionType: AiActionType.navigate,
    destinationRoute: '/player', // Tab 4: Profile
    riskLevel: AiRiskLevel.low,
    descriptionAr: 'الانتقال إلى شاشة تعديل بيانات الحساب والمركز والمحافظة',
  );

  static const playerViewNotifications = AiCapability(
    id: 'PLAYER_VIEW_NOTIFICATIONS',
    role: 'player',
    canExecuteByAi: false,
    actionType: AiActionType.navigate,
    destinationRoute: '/notifications',
    riskLevel: AiRiskLevel.read,
    descriptionAr: 'فتح مركز الإشعارات والتنبيهات',
  );

  static const playerMyTeam = AiCapability(
    id: 'PLAYER_MY_TEAM',
    role: 'player',
    canExecuteByAi: false,
    actionType: AiActionType.navigate,
    destinationRoute: '/player', // Tab 1: Team
    riskLevel: AiRiskLevel.read,
    descriptionAr: 'استعراض بيانات وإحصائيات فريق اللاعب',
  );

  static const playerLeaveMatch = AiCapability(
    id: 'PLAYER_LEAVE_MATCH',
    role: 'player',
    canExecuteByAi: true,
    actionType: AiActionType.executeThenNavigate,
    destinationRoute: '/match/:bookingId',
    requiredParams: ['booking_id'],
    confirmationRequired: true,
    riskLevel: AiRiskLevel.high,
    descriptionAr: 'فتح شاشة تفاصيل الماتش لتأكيد المغادرة',
  );

  static const playerDeleteAccount = AiCapability(
    id: 'PLAYER_DELETE_ACCOUNT',
    role: 'player',
    canExecuteByAi: false,
    actionType: AiActionType.navigate,
    destinationRoute: '/player',
    confirmationRequired: true,
    riskLevel: AiRiskLevel.high,
    descriptionAr: 'فتح إعدادات الحساب لحذف الحساب بعد تأكيد المستخدم',
  );

  static const playerLeaveTournament = AiCapability(
    id: 'PLAYER_LEAVE_TOURNAMENT',
    role: 'player',
    canExecuteByAi: true,
    actionType: AiActionType.executeThenNavigate,
    destinationRoute: '/championship/:championshipId',
    requiredParams: ['championship_id'],
    confirmationRequired: true,
    riskLevel: AiRiskLevel.high,
    descriptionAr: 'فتح شاشة تفاصيل البطولة لإلغاء الاشتراك',
  );

  // -------------------------------------------------------------
  // Owner Capabilities (Requires owner_ai entitlement)
  // -------------------------------------------------------------

  static const ownerCreateManualBooking = AiCapability(
    id: 'OWNER_CREATE_MANUAL_BOOKING',
    role: 'owner',
    requiredEntitlement: 'owner_ai',
    canExecuteByAi: true,
    actionType: AiActionType.executeThenNavigate,
    destinationRoute: '/owner',
    requiredParams: ['stadium_id', 'start_time', 'end_time'],
    confirmationRequired: true,
    riskLevel: AiRiskLevel.high,
    descriptionAr: 'تسجيل حجز يدوي للعميل من خلال بيانات الملعب والسعر الحقيقي',
  );

  static const ownerViewFinancials = AiCapability(
    id: 'OWNER_VIEW_FINANCIALS',
    role: 'owner',
    requiredEntitlement: 'owner_ai',
    canExecuteByAi: true,
    actionType: AiActionType.executeThenNavigate,
    destinationRoute: '/owner', // Tab 0: Dashboard / Ledger
    riskLevel: AiRiskLevel.read,
    descriptionAr: 'استعلام الأرباح المكتملة، الرصيد المتاح للسحب، ومديونية الكاش',
  );

  static const ownerViewUpcomingBookings = AiCapability(
    id: 'OWNER_VIEW_UPCOMING_BOOKINGS',
    role: 'owner',
    requiredEntitlement: 'owner_ai',
    canExecuteByAi: true,
    actionType: AiActionType.executeThenNavigate,
    destinationRoute: '/owner', // Tab 3: Bookings
    riskLevel: AiRiskLevel.read,
    descriptionAr: 'استعراض جدول الحجوزات القادمة في ملاعب المالك',
  );

  static const ownerViewStadiums = AiCapability(
    id: 'OWNER_VIEW_STADIUMS',
    role: 'owner',
    requiredEntitlement: 'owner_ai',
    canExecuteByAi: true,
    actionType: AiActionType.execute,
    riskLevel: AiRiskLevel.read,
    descriptionAr: 'عرض الملاعب المسجلة باسم المالك وحالتها وسعر الساعة',
  );

  static const ownerBlockSlot = AiCapability(
    id: 'OWNER_BLOCK_SLOT',
    role: 'owner',
    requiredEntitlement: 'owner_ai',
    canExecuteByAi: true,
    actionType: AiActionType.execute,
    requiredParams: ['stadium_id', 'date', 'time'],
    confirmationRequired: true,
    riskLevel: AiRiskLevel.high,
    descriptionAr: 'قفل فترة زمنية في جدول الملعب لمنع الحجز العام',
  );

  static const ownerUnblockSlot = AiCapability(
    id: 'OWNER_UNBLOCK_SLOT',
    role: 'owner',
    requiredEntitlement: 'owner_ai',
    canExecuteByAi: true,
    actionType: AiActionType.execute,
    requiredParams: ['stadium_id', 'date', 'time'],
    confirmationRequired: true,
    riskLevel: AiRiskLevel.high,
    descriptionAr: 'إلغاء قفل فترة زمنية وإعادة إتاحتها للحجز العام',
  );

  static const ownerEditStadium = AiCapability(
    id: 'OWNER_EDIT_STADIUM',
    role: 'owner',
    requiredEntitlement: 'owner_ai',
    canExecuteByAi: false,
    actionType: AiActionType.navigate,
    destinationRoute: '/documentation',
    riskLevel: AiRiskLevel.low,
    descriptionAr: 'الانتقال إلى إعدادات الملعب والمستندات والأسعار',
  );

  static const ownerRenewSubscription = AiCapability(
    id: 'OWNER_RENEW_SUBSCRIPTION',
    role: 'owner',
    requiredEntitlement: 'none',
    canExecuteByAi: false,
    actionType: AiActionType.navigate,
    destinationRoute: '/facility-onboarding',
    riskLevel: AiRiskLevel.low,
    descriptionAr: 'فتح شاشة تجديد باقة إدارة الملاعب والذكاء الاصطناعي',
  );

  // -------------------------------------------------------------
  // System Capabilities
  // -------------------------------------------------------------

  static const systemLogin = AiCapability(
    id: 'SYSTEM_LOGIN',
    role: 'any',
    canExecuteByAi: false,
    actionType: AiActionType.navigate,
    destinationRoute: '/login',
    riskLevel: AiRiskLevel.read,
    descriptionAr: 'فتح شاشة تسجيل الدخول',
  );

  /// Complete list of all registered capabilities
  static const List<AiCapability> all = [
    // Player
    playerSearchStadiums,
    playerSearchTournaments,
    playerSearchOpenMatches,
    playerCheckAvailability,
    playerCreateBooking,
    playerViewBookings,
    playerCancelBooking,
    playerEditProfile,
    playerViewNotifications,
    playerMyTeam,
    playerLeaveMatch,
    playerDeleteAccount,
    playerLeaveTournament,
    // Owner
    ownerCreateManualBooking,
    ownerViewFinancials,
    ownerViewUpcomingBookings,
    ownerViewStadiums,
    ownerBlockSlot,
    ownerUnblockSlot,
    ownerEditStadium,
    ownerRenewSubscription,
    // System
    systemLogin,
  ];

  /// Fast lookup index by capability ID
  static final Map<String, AiCapability> _byId = {
    for (final c in all) c.id: c,
  };

  /// Retrieves a capability by its unique ID. Returns null if not found.
  static AiCapability? getById(String? id) {
    if (id == null) return null;
    return _byId[id.trim().toUpperCase()];
  }

  /// Checks if an action is permitted for a given user role and entitlement.
  static bool isPermitted({
    required String capabilityId,
    required String userRole,
    required Set<String> userEntitlements,
  }) {
    final cap = getById(capabilityId);
    if (cap == null) return false;

    // 1. Role Check
    final normRole = userRole.toLowerCase().trim();
    if (cap.role != 'any') {
      if (cap.role == 'player' && normRole != 'player' && normRole != 'admin') return false;
      if (cap.role == 'owner' && normRole != 'owner' && normRole != 'admin') return false;
      if (cap.role == 'admin' && normRole != 'admin') return false;
    }

    // 2. Entitlement Check
    if (cap.requiredEntitlement != 'none') {
      if (!userEntitlements.contains(cap.requiredEntitlement) && normRole != 'admin') {
        return false;
      }
    }

    return true;
  }
}
