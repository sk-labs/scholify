import 'package:flutter/material.dart';

import '../core/auth/session_manager.dart';
import '../core/constants/branding.dart';
import '../core/services/license_alert_service.dart';
import '../core/sync/sync_engine.dart';
import '../core/tenant/tenant_context.dart';
import '../core/theme/scholify_theme.dart';
import '../core/theme/theme_controller.dart';
import '../features/auth/presentation/sign_in_page.dart';
import '../features/superadmin/presentation/superadmin_dashboard_page.dart';
import 'scholify_shell_page.dart';

class ScholifyApp extends StatefulWidget {
  const ScholifyApp({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
    required this.sessionManager,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;
  final SessionManager sessionManager;

  @override
  State<ScholifyApp> createState() => _ScholifyAppState();
}

class _ScholifyAppState extends State<ScholifyApp> {
  @override
  void initState() {
    super.initState();
    // Load persisted theme preference (fire-and-forget; defaults to light).
    ThemeController.load();
  }

  @override
  void dispose() {
    widget.syncEngine.disposeEngine();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.tenantContext,
        widget.sessionManager,
        ThemeController.mode,
      ]),
      builder: (context, _) {
        final Widget home;
        if (!widget.sessionManager.isInitialized) {
          home = const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (!widget.sessionManager.isAuthenticated) {
          home = SignInPage(sessionManager: widget.sessionManager);
        } else {
          home = ScholifyShellPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
            onSignOut: widget.sessionManager.signOut,
          );
        }

        return MaterialApp(
          title: AppBranding.appName,
          debugShowCheckedModeBanner: false,
          theme: ScholifyTheme.light(),
          darkTheme: ScholifyTheme.dark(),
          themeMode: ThemeController.mode.value,
          routes: {
            '/superadmin': (context) => SuperadminDashboardPage(
              tenantContext: widget.tenantContext,
              syncEngine: widget.syncEngine,
              licenseAlertService: LicenseAlertService(
                database: widget.syncEngine.database,
              ),
            ),
          },
          home: home,
        );
      },
    );
  }
}
