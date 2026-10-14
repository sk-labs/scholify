import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/audit_log_service.dart';
import '../../../core/services/impersonation_service.dart';
import '../../../core/services/license_alert_service.dart';
import '../../../core/services/wizard_validation_service.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../../../core/database/local_database.dart';
import '../../../core/theme/scholify_colors.dart';
import '../../dashboard/presentation/dashboard_summary_cards.dart';
import '../../plan_upgrade/presentation/plan_upgrade_review_page.dart';
import '../../tenant_detail/presentation/tenant_detail_page.dart';
import '../../usage_analytics/presentation/usage_analytics_page.dart';
import 'feature_flag_access_page.dart';
import 'onboarding_wizard_page.dart';
import 'school_owner_provisioning_page.dart';
import 'superadmin_audit_page.dart';
import 'tenant_licensing_page.dart';
import 'usage_billing_monitor_page.dart';

class SuperadminDashboardPage extends StatefulWidget {
  const SuperadminDashboardPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
    required this.licenseAlertService,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;
  final LicenseAlertService licenseAlertService;

  @override
  State<SuperadminDashboardPage> createState() =>
      _SuperadminDashboardPageState();
}

class _SuperadminDashboardPageState extends State<SuperadminDashboardPage> {
  /// Tiers the user has dismissed this session.
  final Set<AlertTier> _dismissedTiers = {};

  TenantContext get tenantContext => widget.tenantContext;
  SyncEngine get syncEngine => widget.syncEngine;
  LicenseAlertService get licenseAlertService => widget.licenseAlertService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([tenantContext, syncEngine]),
      builder: (context, _) {
        final activeTenant = tenantContext.tenantName ?? 'No tenant selected';
        final superadminMode = tenantContext.isSuperAdmin;
        final theme = Theme.of(context);

        // No page-level AppBar: the shell already provides the top bar with
        // tenant branding. The in-page "Platform Overview" header is the title.
        return Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Page header: title + context
                  _buildPageHeader(context, theme),
                  // License expiry alert banners (below header for hierarchy,
                  // dismissible per tier)
                  StreamBuilder<List<LicenseAlert>>(
                    stream: licenseAlertService.watchAlerts(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _buildAlertBanners(context, snapshot.data!),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  // Q4: Dashboard summary metric cards (tap navigates to licensing)
                  DashboardSummaryCards(
                    syncEngine: syncEngine,
                    onCardTap: (type) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => TenantLicensingPage(
                            tenantContext: tenantContext,
                            syncEngine: syncEngine,
                            initialActiveFilter:
                                type == DashboardMetricType.active
                                    ? true
                                    : null,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  // System status strip
                  _buildSystemStatus(context, theme),
                  const SizedBox(height: 28),
                  _buildSectionHeader(
                    context,
                    theme,
                    'Management',
                    'Tools to run the platform',
                  ),
                  const SizedBox(height: 12),
                  _buildModuleGrid(
                      context, isWide, superadminMode, activeTenant),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// Page header with title, subtitle, and tenant context chip.
  /// Page header: title + subtitle. No tenant chip — the top bar already
  /// carries the product brand.
  Widget _buildPageHeader(BuildContext context, ThemeData theme) {
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Platform Overview',
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Monitor tenants, licenses, and system health at a glance.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// Section header with title + subtitle.
  Widget _buildSectionHeader(BuildContext context, ThemeData theme,
      String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// System status strip: sync engine, pending jobs, and database state.
  /// Gives the dashboard a "live ops" feel.
  Widget _buildSystemStatus(BuildContext context, ThemeData theme) {
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final pending = syncEngine.pendingJobs;

    final items = [
      _StatusItem(
        icon: Icons.sync,
        label: 'Sync Engine',
        value: 'Running',
        color: ScholifyColors.scholarTeal,
      ),
      _StatusItem(
        icon: Icons.pending_actions,
        label: 'Pending Jobs',
        value: '$pending',
        color: pending > 0
            ? ScholifyColors.achievementAmber
            : ScholifyColors.success,
      ),
      _StatusItem(
        icon: Icons.storage,
        label: 'Local Database',
        value: 'Connected',
        color: ScholifyColors.success,
      ),
    ];

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
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              Expanded(child: _buildStatusCell(context, theme, items[i])),
              if (i < items.length - 1)
                Container(
                  width: 1,
                  height: 40,
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCell(
      BuildContext context, ThemeData theme, _StatusItem item) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: ScholifyColors.tint(item.color, 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(item.icon, size: 20, color: item.color),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              item.value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds the module navigation grid: 2 columns on wide screens,
  /// single column list on narrow screens.
  Widget _buildModuleGrid(
    BuildContext context,
    bool isWide,
    bool superadminMode,
    String activeTenant,
  ) {
    final modules = <_ModuleSpec>[
      _ModuleSpec(
        title: 'Tenant Onboarding Wizard',
        subtitle: 'Guided 3-step flow to create a tenant, issue a license, and provision the owner.',
        status: superadminMode ? 'Create Tenant' : 'Restricted',
        icon: Icons.person_add,
        color: ScholifyColors.academicNavy,
        category: 'Tenant Management',
        onTap: () {
          final auditLogService = AuditLogService(
            database: syncEngine.database,
            tenantContext: tenantContext,
            gateway: syncEngine.pocketbaseGateway,
          );
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => OnboardingWizardPage(
                syncEngine: syncEngine,
                validationService:
                    WizardValidationService(database: syncEngine.database),
                auditLogService: auditLogService,
              ),
            ),
          );
        },
      ),
      _ModuleSpec(
        title: 'Tenant Licensing',
        subtitle: 'Create licenses, assign plans, and suspend/activate schools.',
        status: superadminMode ? 'Active' : 'Restricted',
        icon: Icons.badge,
        color: ScholifyColors.accentStudents,
        category: 'Tenant Management',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TenantLicensingPage(
                tenantContext: tenantContext,
                syncEngine: syncEngine,
              ),
            ),
          );
        },
      ),
      _ModuleSpec(
        title: 'School Owner Provisioning',
        subtitle: 'Create owner accounts and bootstrap tenant defaults.',
        status: activeTenant,
        icon: Icons.manage_accounts,
        color: ScholifyColors.scholarTeal,
        category: 'Tenant Management',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SchoolOwnerProvisioningPage(
                tenantContext: tenantContext,
                syncEngine: syncEngine,
              ),
            ),
          );
        },
      ),
      _ModuleSpec(
        title: 'Usage and Billing Monitor',
        subtitle: 'Track tenant limits, seat counts, and renewal lifecycle.',
        status: 'Pending sync jobs: ${syncEngine.pendingJobs}',
        icon: Icons.receipt_long,
        color: ScholifyColors.success,
        category: 'Billing & Plans',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => UsageBillingMonitorPage(
                tenantContext: tenantContext,
                syncEngine: syncEngine,
              ),
            ),
          );
        },
      ),
      _ModuleSpec(
        title: 'Feature Flags and Add-ons',
        subtitle: 'Enable/disable modules per tenant for plan-based access.',
        status: 'Configure Access',
        icon: Icons.tune,
        color: ScholifyColors.achievementAmber,
        category: 'Billing & Plans',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FeatureFlagAccessPage(
                tenantContext: tenantContext,
                syncEngine: syncEngine,
              ),
            ),
          );
        },
      ),
      _ModuleSpec(
        title: 'Audit Log',
        subtitle: 'Review write operations, actors, and entity changes.',
        status: 'View Log',
        icon: Icons.history,
        color: ScholifyColors.slate600,
        category: 'System',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SuperadminAuditPage(
                syncEngine: syncEngine,
              ),
            ),
          );
        },
      ),
      _ModuleSpec(
        title: 'Plan Upgrade Requests',
        subtitle: 'Approve or reject tenant plan upgrade requests.',
        status: 'Review',
        icon: Icons.upgrade,
        color: ScholifyColors.accentOperations,
        category: 'Billing & Plans',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PlanUpgradeReviewPage(
                tenantContext: tenantContext,
                syncEngine: syncEngine,
              ),
            ),
          );
        },
      ),
      _ModuleSpec(
        title: 'Usage Analytics',
        subtitle: 'Per-tenant usage metrics, MAU trends, and CSV export.',
        status: 'View Analytics',
        icon: Icons.analytics,
        color: ScholifyColors.tealSoft,
        category: 'Billing & Plans',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => UsageAnalyticsPage(
                tenantContext: tenantContext,
                syncEngine: syncEngine,
              ),
            ),
          );
        },
      ),
      _ModuleSpec(
        title: 'Tenant Details',
        subtitle: 'Open a tenant detail view (single tenant management).',
        status: 'Pick Tenant',
        icon: Icons.business,
        color: ScholifyColors.accentComms,
        category: 'Tenant Management',
        onTap: () => _openTenantDetailPicker(context),
      ),
    ];

    // Group modules by category for a structured layout.
    const order = ['Tenant Management', 'Billing & Plans', 'System'];
    final grouped = <String, List<_ModuleSpec>>{};
    for (final m in modules) {
      grouped.putIfAbsent(m.category, () => []).add(m);
    }

    Widget buildCards(List<_ModuleSpec> specs) {
      final cards = [
        for (final m in specs)
          _ModuleCard(
            title: m.title,
            subtitle: m.subtitle,
            status: m.status,
            icon: m.icon,
            color: m.color,
            onTap: m.onTap,
          ),
      ];
      if (!isWide) {
        return Column(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              cards[i],
              if (i < cards.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      }
      return GridView.count(
        crossAxisCount: 2,
        childAspectRatio: 2.4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        children: cards,
      );
    }

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final category in order)
          if (grouped.containsKey(category)) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 10),
              child: Text(
                category.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            buildCards(grouped[category]!),
            const SizedBox(height: 20),
          ],
      ],
    );
  }

  /// Opens a tenant picker dialog and navigates to TenantDetailPage.
  Future<void> _openTenantDetailPicker(BuildContext context) async {
    final views = await syncEngine.database.watchTenantUsageBillingViews().first;
    if (views.isEmpty || !context.mounted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No tenants available.')),
        );
      }
      return;
    }

    final selected = await showDialog<TenantUsageBillingView>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Select Tenant'),
        children: [
          for (final view in views)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(view),
              child: Text(
                '${view.tenantName} (${view.planCode ?? '-'})',
              ),
            ),
        ],
      ),
    );

    if (selected == null || !context.mounted) return;

    final impersonationService = ImpersonationService(
      tenantContext: tenantContext,
      auditLogService: AuditLogService(
        database: syncEngine.database,
        tenantContext: tenantContext,
        gateway: syncEngine.pocketbaseGateway,
      ),
    );

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TenantDetailPage(
          tenantId: selected.tenantId,
          syncEngine: syncEngine,
          impersonationService: impersonationService,
        ),
      ),
    );
  }

  /// Builds alert banners for license expiry warnings.
  /// 
  /// Requirements: H4.3, H4.4, H4.5
  Widget _buildAlertBanners(BuildContext context, List<LicenseAlert> alerts) {
    final dateFormat = DateFormat('dd MMM yyyy');

    // Group alerts by tier, excluding dismissed ones
    final expired = alerts
        .where((a) =>
            a.tier == AlertTier.expired &&
            !_dismissedTiers.contains(AlertTier.expired))
        .toList();
    final urgent7 = alerts
        .where((a) =>
            a.tier == AlertTier.urgent7 &&
            !_dismissedTiers.contains(AlertTier.urgent7))
        .toList();
    final alert14 = alerts
        .where((a) =>
            a.tier == AlertTier.alert14 &&
            !_dismissedTiers.contains(AlertTier.alert14))
        .toList();

    if (expired.isEmpty && urgent7.isEmpty && alert14.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Red urgent banner for expired licenses (H4.5)
        if (expired.isNotEmpty)
          _buildBanner(
            context: context,
            color: ScholifyColors.error,
            icon: Icons.error,
            title: 'Expired Licenses (${expired.length})',
            alerts: expired,
            dateFormat: dateFormat,
            tier: AlertTier.expired,
          ),
        // Red urgent banner for 7-day alerts (H4.4)
        if (urgent7.isNotEmpty)
          _buildBanner(
            context: context,
            color: ScholifyColors.error,
            icon: Icons.warning,
            title: 'Expiring within 7 days (${urgent7.length})',
            alerts: urgent7,
            dateFormat: dateFormat,
            tier: AlertTier.urgent7,
          ),
        // Amber alert banner for 14-day alerts (H4.3)
        if (alert14.isNotEmpty)
          _buildBanner(
            context: context,
            color: ScholifyColors.achievementAmber,
            icon: Icons.warning_amber,
            title: 'Expiring within 14 days (${alert14.length})',
            alerts: alert14,
            dateFormat: dateFormat,
            tier: AlertTier.alert14,
          ),
      ],
    );
  }

  Widget _buildBanner({
    required BuildContext context,
    required Color color,
    required IconData icon,
    required String title,
    required List<LicenseAlert> alerts,
    required DateFormat dateFormat,
    required AlertTier tier,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.85)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // Inline action: jump straight to licensing to renew.
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TenantLicensingPage(
                        tenantContext: tenantContext,
                        syncEngine: syncEngine,
                      ),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: color,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.autorenew, size: 18),
                label: const Text('Renew'),
              ),
              const SizedBox(width: 4),
              // Dismiss for this session
              IconButton(
                tooltip: 'Dismiss',
                onPressed: () =>
                    setState(() => _dismissedTiers.add(tier)),
                icon: const Icon(Icons.close,
                    size: 20, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final alert in alerts)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        const Icon(Icons.circle,
                            size: 6, color: Colors.white70),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${alert.tenantName}: ${_expiryText(alert, dateFormat)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _expiryText(LicenseAlert alert, DateFormat dateFormat) {
    if (alert.tier == AlertTier.expired) {
      return 'Expired on ${dateFormat.format(alert.expiresAt)}';
    }
    return 'Expires on ${dateFormat.format(alert.expiresAt)} (${alert.daysRemaining}d left)';
  }
}

/// Spec for a dashboard module tile: visual identity + navigation.
class _ModuleSpec {
  const _ModuleSpec({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.icon,
    required this.color,
    required this.category,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String status;
  final IconData icon;
  final Color color;
  final String category;
  final VoidCallback onTap;
}

/// A single system status cell (icon + label + value).
class _StatusItem {
  const _StatusItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String status;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

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
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              // Gradient icon medallion
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: ScholifyColors.tint(color, isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isDark ? color.lighten() : color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: ScholifyColors.tint(
                      scheme.onSurface, isDark ? 0.08 : 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lightens a color for dark-mode legibility.
extension on Color {
  Color lighten([double amount = 0.25]) {
    final hsl = HSLColor.fromColor(this);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }
}
