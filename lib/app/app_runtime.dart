import '../core/sync/sync_engine.dart';
import '../core/tenant/tenant_context.dart';

class AppRuntime {
  static TenantContext? tenantContext;
  static SyncEngine? syncEngine;

  static bool get isReady => tenantContext != null && syncEngine != null;

  static void set({
    required TenantContext tenantContextValue,
    required SyncEngine syncEngineValue,
  }) {
    tenantContext = tenantContextValue;
    syncEngine = syncEngineValue;
  }
}