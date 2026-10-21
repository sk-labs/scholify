import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../remote/pocketbase_gateway.dart';
import '../tenant/tenant_context.dart';
import '../../features/family/family_links.dart';
import 'auth_session.dart';

class SessionManager extends ChangeNotifier {
  SessionManager({
    required this.gateway,
    required this.tenantContext,
    required this.preferences,
  });

  static const String _tokenKey = 'scholify.auth.token';
  static const String _modelKey = 'scholify.auth.model';

  final PocketbaseGateway gateway;
  final TenantContext tenantContext;
  final SharedPreferences preferences;

  bool _isInitialized = false;
  bool _isSigningIn = false;
  String? _errorMessage;

  bool get isInitialized => _isInitialized;
  bool get isSigningIn => _isSigningIn;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated =>
      gateway.isAuthenticated && tenantContext.hasTenant;

  Future<void> initialize() async {
    try {
      final token = preferences.getString(_tokenKey);
      final modelJsonRaw = preferences.getString(_modelKey);
      if (token != null && token.isNotEmpty && modelJsonRaw != null) {
        final decoded = jsonDecode(modelJsonRaw);
        if (decoded is Map<String, dynamic>) {
          gateway.restoreAuthSnapshot(token: token, modelJson: decoded);
        } else if (decoded is Map) {
          gateway.restoreAuthSnapshot(
            token: token,
            modelJson: decoded.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          );
        }
      }

      final session = gateway.currentSession();
      if (session != null) {
        _applySession(session);
      } else {
        tenantContext.clear();
      }
    } catch (_) {
      await signOut();
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<bool> signIn({
    required String identity,
    required String password,
  }) async {
    _isSigningIn = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final session = await gateway.signInAndResolveSession(
        identity: identity,
        password: password,
      );

      if (session == null) {
        final details = gateway.lastSignInError?.trim();
        if (details != null && details.isNotEmpty) {
          _errorMessage = 'Sign in failed. $details';
        } else {
          _errorMessage =
              'Sign in failed. Check credentials and tenant mapping.';
        }
        return false;
      }

      _applySession(session);
      await _persistCurrentAuth();
      return true;
    } catch (_) {
      _errorMessage = 'Unable to sign in right now. Please try again.';
      return false;
    } finally {
      _isSigningIn = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    gateway.signOut();
    tenantContext.clear();
    FamilyChildSelection.reset();
    _errorMessage = null;

    await preferences.remove(_tokenKey);
    await preferences.remove(_modelKey);

    notifyListeners();
  }

  Future<void> _persistCurrentAuth() async {
    final token = gateway.currentAuthToken;
    final model = gateway.currentAuthModelJson;

    if (token == null || token.isEmpty || model == null) {
      await preferences.remove(_tokenKey);
      await preferences.remove(_modelKey);
      return;
    }

    await preferences.setString(_tokenKey, token);
    await preferences.setString(_modelKey, jsonEncode(model));
  }

  void _applySession(AuthSession session) {
    tenantContext.setTenant(
      tenantId: session.tenantId,
      tenantName: session.tenantName,
      role: session.role,
      isSuperAdmin: session.isSuperAdmin,
    );
  }
}
