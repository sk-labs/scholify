import 'package:flutter/foundation.dart';

class TenantContext extends ChangeNotifier {
  String? _tenantId;
  String? _tenantName;
  String _role = 'guest';
  bool _isSuperAdmin = false;

  // Branding fields (B3.3, B3.4, B3.5, B3.6)
  String? _brandingDisplayName;
  String? _brandingLogoBase64;

  String? get tenantId => _tenantId;
  String? get tenantName => _tenantName;
  String get role => _role;
  bool get isSuperAdmin => _isSuperAdmin;
  bool get hasTenant => _tenantId != null && _tenantId!.isNotEmpty;

  /// Custom display name set via branding settings, or null if not configured.
  String? get brandingDisplayName => _brandingDisplayName;

  /// Base64-encoded logo image, or null if not configured.
  String? get brandingLogoBase64 => _brandingLogoBase64;

  void setTenant({
    required String tenantId,
    required String tenantName,
    required String role,
    required bool isSuperAdmin,
  }) {
    _tenantId = tenantId;
    _tenantName = tenantName;
    _role = role;
    _isSuperAdmin = isSuperAdmin;
    notifyListeners();
  }

  /// Updates branding fields and notifies listeners so the shell re-renders.
  /// Pass null for [logoBase64] to remove the logo.
  /// Requirements: B3.3, B3.4, B3.5, B3.6
  void setBranding({
    required String? displayName,
    required String? logoBase64,
  }) {
    _brandingDisplayName = displayName;
    _brandingLogoBase64 = logoBase64;
    notifyListeners();
  }

  void clear() {
    _tenantId = null;
    _tenantName = null;
    _role = 'guest';
    _isSuperAdmin = false;
    _brandingDisplayName = null;
    _brandingLogoBase64 = null;
    notifyListeners();
  }
}
