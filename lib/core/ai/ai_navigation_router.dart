import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../models/copilot_message.dart';
import 'ai_capability_registry.dart';
import '../../features/player/screens/player_home_screen.dart';
import '../../features/player/screens/champion_screen.dart';
import '../../features/owner/screens/owner_main_screen.dart';

/// Centralised AI Navigation Router.
///
/// Routes a [CopilotAction] to the correct in-app destination using the
/// [AiCapabilityRegistry] as the single source of truth.
///
/// Usage:
/// ```dart
/// final router = AiNavigationRouter(context, isOwner: auth.isOwner);
/// router.execute(action);
/// ```
class AiNavigationRouter {
  final dynamic _context; // BuildContext – dynamic to avoid circular imports
  final bool isOwner;

  AiNavigationRouter(this._context, {required this.isOwner});

  /// Execute an action emitted by the Copilot edge function.
  ///
  /// Returns `true` if navigation was handled, `false` if unresolvable.
  bool execute(CopilotAction action) {
    final actionType = action.actionType.toUpperCase();

    // ── 1. PROFILE_UPDATED — no navigation, caller shows snackbar ────────────
    if (actionType == 'PROFILE_UPDATED') return false;

    // ── 2. OPEN_PAYMENT — pop Copilot, push /checkout ────────────────────────
    if (actionType == 'OPEN_PAYMENT') {
      _safeGoPop();
      _safePush('/checkout', extra: action.params);
      return true;
    }

    // ── 3. Capability-aware routing ───────────────────────────────────────────
    final cap = AiCapabilityRegistry.getById(action.capabilityId);

    if (isOwner) {
      return _routeOwner(action, cap);
    }
    return _routePlayer(action, cap);
  }

  // ---------------------------------------------------------------------------
  // Owner routing
  // Tab layout: 0=Dashboard, 1=Cup, 2=Inbox, 3=Bookings, 4=Profile
  // ---------------------------------------------------------------------------
  bool _routeOwner(CopilotAction action, AiCapability? cap) {
    if (cap != null) {
      switch (cap.id) {
        case 'OWNER_VIEW_FINANCIALS':
        case 'OWNER_VIEW_STADIUMS':
          _safeGoPop();
          ownerMainScreenKey.currentState?.switchToTab(0);
          return true;

        case 'OWNER_VIEW_UPCOMING_BOOKINGS':
          _safeGoPop();
          ownerMainScreenKey.currentState?.switchToTab(3);
          return true;

        case 'OWNER_EDIT_STADIUM':
          _safeGoPop();
          _safePush('/documentation');
          return true;

        case 'OWNER_RENEW_SUBSCRIPTION':
          _safeGoPop();
          _safePush('/facility-onboarding');
          return true;
      }
    }

    // Route-based fallback for owners
    final route = action.route.toLowerCase();
    if (route.contains('ledger') || route.contains('financial') || route.contains('dashboard')) {
      _safeGoPop();
      ownerMainScreenKey.currentState?.switchToTab(0);
    } else if (route.contains('booking')) {
      _safeGoPop();
      ownerMainScreenKey.currentState?.switchToTab(3);
    } else if (route.contains('profile')) {
      _safeGoPop();
      ownerMainScreenKey.currentState?.switchToTab(4);
    } else if (route.contains('facility-onboarding') || route.contains('subscription')) {
      _safeGoPop();
      _safePush('/facility-onboarding');
    } else {
      _safePush(action.route);
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Player routing
  // Tab layout: 0=Home, 1=Team, 2=Tournaments, 3=Bookings, 4=Profile
  // ---------------------------------------------------------------------------
  bool _routePlayer(CopilotAction action, AiCapability? cap) {
    if (cap != null) {
      switch (cap.id) {
        case 'PLAYER_MY_TEAM':
          _safeGoPop();
          playerHomeScreenKey.currentState?.switchToTab(1);
          return true;

        case 'PLAYER_SEARCH_TOURNAMENTS':
        case 'PLAYER_SEARCH_OPEN_MATCHES':
        case 'PLAYER_LEAVE_TOURNAMENT':
          _safeGoPop();
          playerHomeScreenKey.currentState?.switchToTab(2);
          return true;

        case 'PLAYER_VIEW_BOOKINGS':
        case 'PLAYER_CANCEL_BOOKING':
        case 'PLAYER_LEAVE_MATCH':
          _safeGoPop();
          playerHomeScreenKey.currentState?.switchToTab(3);
          return true;

        case 'PLAYER_EDIT_PROFILE':
          _safeGoPop();
          playerHomeScreenKey.currentState?.switchToTab(4);
          return true;

        case 'PLAYER_VIEW_NOTIFICATIONS':
          _safeGoPop();
          _safePush('/notifications');
          return true;

        case 'PLAYER_SEARCH_STADIUMS':
        case 'PLAYER_CHECK_AVAILABILITY':
          _safeGoPop();
          playerHomeScreenKey.currentState?.switchToTab(0);
          return true;
      }
    }

    // Route-based fallback for players
    final route = action.route.toLowerCase();
    if (route.contains('team') || route.contains('my-team')) {
      _safeGoPop();
      playerHomeScreenKey.currentState?.switchToTab(1);
    } else if (route.contains('1v1')) {
      _safeGoPop();
      playerHomeScreenKey.currentState?.switchToTab(2);
      championScreenKey.currentState?.switchToTab(1);
    } else if (route.contains('tournament') || route.contains('championship')) {
      _safeGoPop();
      playerHomeScreenKey.currentState?.switchToTab(2);
    } else if (route.contains('booking') || route.contains('refund')) {
      _safeGoPop();
      playerHomeScreenKey.currentState?.switchToTab(3);
    } else if (route.contains('profile') || route.contains('setting')) {
      _safeGoPop();
      playerHomeScreenKey.currentState?.switchToTab(4);
    } else if (route.contains('notification')) {
      _safeGoPop();
      _safePush('/notifications');
    } else {
      _safePush(action.route);
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  void _safeGoPop() {
    try {
      GoRouter.of(_context as dynamic).pop();
    } catch (e) {
      debugPrint('[AiNavigationRouter] pop error: $e');
    }
  }

  void _safePush(String route, {Object? extra}) {
    try {
      GoRouter.of(_context as dynamic).push(route, extra: extra);
    } catch (e) {
      debugPrint('[AiNavigationRouter] push($route) error: $e');
    }
  }
}
