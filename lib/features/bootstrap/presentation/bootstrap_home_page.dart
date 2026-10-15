import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/constants/branding.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../../../core/theme/scholify_colors.dart';
import '../../sync/presentation/sync_failure_page.dart';
import '../../plan_upgrade/presentation/plan_upgrade_page.dart';
import '../../branding/presentation/branding_settings_page.dart';

class BootstrapHomePage extends StatelessWidget {
  const BootstrapHomePage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
    this.onSignOut,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([tenantContext, syncEngine]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;

        final tenantLabel = tenantContext.hasTenant
            ? '${tenantContext.tenantName} (${tenantContext.role})'
            : 'No active tenant selected';

        final syncState = syncEngine.isSyncing
            ? 'Sync in progress'
            : syncEngine.isBackgroundSyncEnabled
            ? 'Background sync running'
            : 'Background sync stopped';

        final statusCards = [
          _StatusCard(
            icon: Icons.school,
            color: ScholifyColors.academicNavy,
            title: 'Product',
            value: '${AppBranding.appName} (Desktop-first + Web)',
          ),
          _StatusCard(
            icon: Icons.business,
            color: ScholifyColors.scholarTeal,
            title: 'Tenant Context',
            value: tenantLabel,
          ),
          _StatusCard(
            icon: Icons.sync,
            color: ScholifyColors.scholarTeal,
            title: 'Sync State',
            value: syncState,
          ),
          _StatusCard(
            icon: Icons.pending_actions,
            color: ScholifyColors.achievementAmber,
            title: 'Pending Sync Jobs',
            value: '${syncEngine.pendingJobs}',
          ),
        ];

        // No page-level AppBar: the shell already provides the top bar with
        // product branding. The in-page header below is the page title.
        return Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Page header: title + subtitle + sync-failure warning.
                  _buildHeader(context, theme),
                  const SizedBox(height: 20),
                  // Status cards: 2-column grid on wide screens.
                  if (isWide)
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 2.9,
                      children: statusCards,
                    )
                  else
                    Column(
                      children: [
                        for (var i = 0; i < statusCards.length; i++) ...[
                          statusCards[i],
                          if (i < statusCards.length - 1)
                            const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  const SizedBox(height: 28),
                  Text('Quick Actions', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    'Common workspace tasks',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _buildActionButtons(context),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// Action buttons for common workspace tasks.
  /// Debug/superadmin tools (Set Demo Tenant, Queue Demo Job) are only
  /// visible to superadmins. Regular tenant users see sync controls plus
  /// their own actions (Plan Upgrade, Branding Settings).
  List<Widget> _buildActionButtons(BuildContext context) {
    final buttons = <Widget>[];

    // Superadmin-only debug tools.
    if (tenantContext.isSuperAdmin) {
      buttons.addAll([
        ElevatedButton.icon(
          onPressed: () {
            tenantContext.setTenant(
              tenantId: 'school_demo',
              tenantName: 'Demo School',
              role: 'superadmin',
              isSuperAdmin: true,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Demo tenant applied.')),
            );
          },
          icon: const Icon(Icons.business),
          label: const Text('Set Demo Tenant'),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            await syncEngine.enqueueOperation(
              entityType: 'tenant_license',
              entityId: DateTime.now().millisecondsSinceEpoch.toString(),
              operation: 'upsert',
              payload: jsonEncode({
                'tenantId': tenantContext.tenantId ?? 'school_demo',
                'plan': 'professional',
                'updatedAt': DateTime.now().toIso8601String(),
              }),
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Demo sync operation queued.'),
                ),
              );
            }
          },
          icon: const Icon(Icons.playlist_add),
          label: const Text('Queue Demo Job'),
        ),
      ]);
    }

    // Sync controls: visible to everyone.
    buttons.addAll([
      ElevatedButton.icon(
        onPressed: syncEngine.isBackgroundSyncEnabled
            ? syncEngine.stopBackgroundSync
            : syncEngine.startBackgroundSync,
        icon: Icon(
          syncEngine.isBackgroundSyncEnabled
              ? Icons.pause_circle
              : Icons.play_circle,
        ),
        label: Text(
          syncEngine.isBackgroundSyncEnabled
              ? 'Stop Background Sync'
              : 'Start Background Sync',
        ),
      ),
      OutlinedButton.icon(
        onPressed: syncEngine.manualSync,
        icon: const Icon(Icons.sync),
        label: const Text('Run Manual Sync'),
      ),
    ]);

    if (!tenantContext.isSuperAdmin) {
      // Insert after the sync controls (which are always present).
      buttons.insertAll(2, [
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PlanUpgradePage(
                  tenantContext: tenantContext,
                  syncEngine: syncEngine,
                ),
              ),
            );
          },
          icon: const Icon(Icons.upgrade),
          label: const Text('Request Plan Upgrade'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BrandingSettingsPage(
                  tenantContext: tenantContext,
                  syncEngine: syncEngine,
                ),
              ),
            );
          },
          icon: const Icon(Icons.palette),
          label: const Text('Branding Settings'),
        ),
      ]);
    }

    final signOut = onSignOut;
    if (signOut != null) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: () async {
            await signOut.call();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Signed out from this device.'),
                ),
              );
            }
          },
          icon: const Icon(Icons.logout),
          label: const Text('Sign Out'),
        ),
      );
    }

    return buttons;
  }

  /// Page header with title, subtitle, and the sync-failure warning badge
  /// (A2.7) — moved here from the removed page-level AppBar.
  Widget _buildHeader(BuildContext context, ThemeData theme) {
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scholify Foundation',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Your workspace home — product, tenant, and sync health at a glance.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        StreamBuilder<List<dynamic>>(
          stream: syncEngine.database.watchFailedSyncEntries(),
          builder: (context, snapshot) {
            final failedCount = snapshot.data?.length ?? 0;

            // Only show the badge when there are failures.
            if (failedCount == 0) {
              return const SizedBox.shrink();
            }

            return Container(
              decoration: BoxDecoration(
                color: ScholifyColors.tint(
                  ScholifyColors.error,
                  isDark ? 0.2 : 0.12,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Badge(
                  label: Text('$failedCount'),
                  backgroundColor: ScholifyColors.error,
                  textColor: Colors.white,
                  child: const Icon(Icons.warning_amber_rounded),
                ),
                tooltip: 'Sync Failures ($failedCount)',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SyncFailurePage(),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

/// A polished status card: gradient icon medallion + label + value,
/// 16px radius with a subtle border.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : scheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, color.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
