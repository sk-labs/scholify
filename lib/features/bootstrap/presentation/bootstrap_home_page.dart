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
                  // Action cards: 2-column grid on wide screens.
                  if (isWide)
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 2.2,
                      children: [
                        for (final spec in _buildActionSpecs(context))
                          _ActionCard(spec: spec),
                      ],
                    )
                  else
                    Column(
                      children: [
                        for (var i = 0;
                            i < _buildActionSpecs(context).length;
                            i++) ...[
                          _ActionCard(
                              spec: _buildActionSpecs(context)[i]),
                          if (i < _buildActionSpecs(context).length - 1)
                            const SizedBox(height: 12),
                        ],
                      ],
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
  /// Quick action definitions with icons, colors, and handlers.
  /// Returns a list of (_ActionSpec) for the current user role.
  List<_ActionSpec> _buildActionSpecs(BuildContext context) {
    final specs = <_ActionSpec>[];

    // Superadmin-only debug tools.
    if (tenantContext.isSuperAdmin) {
      specs.addAll([
        _ActionSpec(
          icon: Icons.business_outlined,
          color: ScholifyColors.academicNavy,
          title: 'Set Demo Tenant',
          subtitle: 'Switch to demo workspace',
          onTap: () {
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
        ),
        _ActionSpec(
          icon: Icons.playlist_add_outlined,
          color: ScholifyColors.accentOperations,
          title: 'Queue Demo Job',
          subtitle: 'Enqueue test sync op',
          onTap: () async {
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
        ),
      ]);
    }

    // Sync controls: visible to everyone.
    specs.addAll([
      _ActionSpec(
        icon: syncEngine.isBackgroundSyncEnabled
            ? Icons.pause_circle_outline
            : Icons.play_circle_outline,
        color: ScholifyColors.scholarTeal,
        title: syncEngine.isBackgroundSyncEnabled
            ? 'Stop Background Sync'
            : 'Start Background Sync',
        subtitle: syncEngine.isBackgroundSyncEnabled
            ? 'Pause automatic syncing'
            : 'Enable automatic syncing',
        onTap: syncEngine.isBackgroundSyncEnabled
            ? syncEngine.stopBackgroundSync
            : syncEngine.startBackgroundSync,
      ),
      _ActionSpec(
        icon: Icons.sync_outlined,
        color: ScholifyColors.info,
        title: 'Run Manual Sync',
        subtitle: 'Sync now with server',
        onTap: syncEngine.manualSync,
      ),
    ]);

    if (!tenantContext.isSuperAdmin) {
      specs.addAll([
        _ActionSpec(
          icon: Icons.upgrade_outlined,
          color: ScholifyColors.achievementAmber,
          title: 'Request Plan Upgrade',
          subtitle: 'Unlock more features',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PlanUpgradePage(
                  tenantContext: tenantContext,
                  syncEngine: syncEngine,
                ),
              ),
            );
          },
        ),
        _ActionSpec(
          icon: Icons.palette_outlined,
          color: ScholifyColors.accentComms,
          title: 'Branding Settings',
          subtitle: 'Logo, colors, name',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BrandingSettingsPage(
                  tenantContext: tenantContext,
                  syncEngine: syncEngine,
                ),
              ),
            );
          },
        ),
      ]);
    }

    final signOut = onSignOut;
    if (signOut != null) {
      specs.add(
        _ActionSpec(
          icon: Icons.logout_outlined,
          color: ScholifyColors.slate600,
          title: 'Sign Out',
          subtitle: 'End this session',
          onTap: () async {
            await signOut.call();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Signed out from this device.'),
                ),
              );
            }
          },
        ),
      );
    }

    return specs;
  }

  /// Page header with welcome banner for the dashboard.
  Widget _buildHeader(BuildContext context, ThemeData theme) {
    final tenantName = tenantContext.tenantName ?? 'Scholify';
    final roleLabel = tenantContext.isSuperAdmin
        ? 'Superadmin'
        : tenantContext.role.replaceAll('_', ' ').split(' ').map((w) =>
            w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome banner with gradient
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ScholifyColors.academicNavy,
                ScholifyColors.navyLight,
                ScholifyColors.scholarTeal.withValues(alpha: 0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: ScholifyColors.academicNavy.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tenantName,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            tenantContext.isSuperAdmin
                                ? Icons.admin_panel_settings_outlined
                                : Icons.business_outlined,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            roleLabel,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Sync failure badge (if any)
              StreamBuilder<List<dynamic>>(
                stream: syncEngine.database.watchFailedSyncEntries(),
                builder: (context, snapshot) {
                  final failedCount = snapshot.data?.length ?? 0;
                  if (failedCount == 0) {
                    return Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.school_outlined,
                        color: Colors.white,
                        size: 36,
                      ),
                    );
                  }
                  return Container(
                    decoration: BoxDecoration(
                      color: ScholifyColors.error.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      icon: Badge(
                        label: Text('$failedCount'),
                        backgroundColor: Colors.white,
                        textColor: ScholifyColors.error,
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                        ),
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
          ),
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

/// Specification for a quick action card.
class _ActionSpec {
  const _ActionSpec({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

/// A polished quick action card: icon medallion + title + subtitle,
/// 16px radius with subtle border and hover effect.
class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.spec});

  final _ActionSpec spec;

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
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: spec.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: spec.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(spec.icon, color: spec.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      spec.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      spec.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
