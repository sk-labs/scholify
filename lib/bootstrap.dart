import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/scholify_app.dart';
import 'core/auth/session_manager.dart';
import 'core/constants/branding.dart';
import 'core/database/local_database.dart';
import 'core/remote/pocketbase_gateway.dart';
import 'core/sync/sync_engine.dart';
import 'core/tenant/tenant_context.dart';
import 'app/app_runtime.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppLocalDatabase();
  final tenantContext = TenantContext();
  final pocketbaseGateway = PocketbaseGateway(
    baseUrl: AppBranding.defaultPocketBaseUrl,
  );
  final preferences = await SharedPreferences.getInstance();
  final sessionManager = SessionManager(
    gateway: pocketbaseGateway,
    tenantContext: tenantContext,
    preferences: preferences,
  );
  final syncEngine = SyncEngine(
    database: database,
    pocketbaseGateway: pocketbaseGateway,
    tenantContext: tenantContext,
  );

  AppRuntime.set(
    tenantContextValue: tenantContext,
    syncEngineValue: syncEngine,
  );

  await sessionManager.initialize();
  await syncEngine.initialize();

  runApp(
    ScholifyApp(
      tenantContext: tenantContext,
      syncEngine: syncEngine,
      sessionManager: sessionManager,
    ),
  );
}
