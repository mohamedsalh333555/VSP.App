import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vsp_application/core/models/user_model.dart';
import 'package:vsp_application/core/providers/auth_provider.dart';

/// Test double for the actual AppRouter.redirectLogic method. Unlike an
/// independent copy of routing logic, it cannot silently pass an obsolete
/// policy (for example allowing a suspended owner into the dashboard).
class FakeAuthProvider implements AuthProvider {
  FakeAuthProvider({
    bool isInitializing = false,
    bool isAuthenticated = true,
    bool isGhostUser = false,
    bool isLoading = false,
    UserModel? userModel,
    String? userType,
    bool isOwner = false,
    bool hasDataFetchError = false,
    String email = '',
  })  : _isInitializing = isInitializing,
        _isAuthenticated = isAuthenticated,
        _isGhostUser = isGhostUser,
        _isLoading = isLoading,
        _userModel = userModel,
        _userType = userType,
        _isOwner = isOwner,
        _hasDataFetchError = hasDataFetchError,
        _email = email;

  final bool _isInitializing;
  final bool _isAuthenticated;
  final bool _isGhostUser;
  final bool _isLoading;
  final UserModel? _userModel;
  final String? _userType;
  final bool _isOwner;
  final bool _hasDataFetchError;
  final String _email;

  @override
  bool get isInitializing => _isInitializing;
  @override
  bool get isAuthenticated => _isAuthenticated;
  @override
  bool get isGhostUser => _isGhostUser;
  @override
  bool get isLoading => _isLoading;
  @override
  UserModel? get userModel => _userModel;
  @override
  String? get userType => _userType;
  @override
  bool get isOwner => _isOwner;
  @override
  bool get isAdmin => _userModel?.isAdmin ?? false;
  @override
  bool get hasDataFetchError => _hasDataFetchError;
  @override
  String get email => _email;
  @override
  Stream<void> get celebrationEvents => const Stream.empty();
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
  @override
  bool get hasListeners => false;
  @override
  void dispose() {}
  @override
  void notifyListeners() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeGoRouterState implements GoRouterState {
  FakeGoRouterState(String location) : _uri = Uri.parse(location);

  final Uri _uri;
  @override
  Uri get uri => _uri;
  @override
  String get matchedLocation => _uri.path;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
