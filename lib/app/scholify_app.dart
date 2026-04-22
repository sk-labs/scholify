import 'package:flutter/material.dart';

import '../core/auth/session_manager.dart';
import '../core/constants/branding.dart';
import '../core/sync/sync_engine.dart';
import '../core/tenant/tenant_context.dart';
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
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0F4C81),
            ),
          ),
          routes: {
            '/superadmin': (context) => SuperadminDashboardPage(
              tenantContext: widget.tenantContext,
              syncEngine: widget.syncEngine,
            ),
          },
          home: home,
        );
      },
    );
  }
}
