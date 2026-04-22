import 'package:flutter/foundation.dart';

class TenantContext extends ChangeNotifier {
  String? _tenantId;
  String? _tenantName;
  String _role = 'guest';
  bool _isSuperAdmin = false;

  String? get tenantId => _tenantId;
  String? get tenantName => _tenantName;
  String get role => _role;
  bool get isSuperAdmin => _isSuperAdmin;
  bool get hasTenant => _tenantId != null && _tenantId!.isNotEmpty;

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

  void clear() {
    _tenantId = null;
    _tenantName = null;
    _role = 'guest';
    _isSuperAdmin = false;
    notifyListeners();
  }
}
