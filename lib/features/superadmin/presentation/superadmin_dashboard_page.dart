import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/audit_log_service.dart';
import '../../../core/services/impersonation_service.dart';
import '../../../core/services/license_alert_service.dart';
import '../../../core/services/wizard_validation_service.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../../../core/database/local_database.dart';
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

class SuperadminDashboardPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([tenantContext, syncEngine]),
      builder: (context, _) {
        final activeTenant = tenantContext.tenantName ?? 'No tenant selected';
        final superadminMode = tenantContext.isSuperAdmin;

        return Scaffold(
          appBar: AppBar(title: const Text('Superadmin Dashboard')),
          body: Column(
            children: [
              // License expiry alert banners
              StreamBuilder<List<LicenseAlert>>(
                stream: licenseAlertService.watchAlerts(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final alerts = snapshot.data!;
                  return _buildAlertBanners(context, alerts);
                },
              ),
              // Main dashboard content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 800;
                      return ListView(
                        children: [
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
                          Text(
                            'Manage',
                            style:
                                Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                          const SizedBox(height: 12),
                          _buildModuleGrid(context, isWide, superadminMode, activeTenant),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
        color: Colors.blue,
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
        color: Colors.indigo,
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
        color: Colors.teal,
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
        color: Colors.green,
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
        color: Colors.orange,
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
        color: Colors.brown,
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
        color: Colors.purple,
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
        color: Colors.cyan,
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
        color: Colors.deepOrange,
        onTap: () => _openTenantDetailPicker(context),
      ),
    ];

    final cards = [
      for (final m in modules)
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
      return Column(children: cards);
    }
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 2.6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: cards,
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
    
    // Group alerts by tier
    final expired = alerts.where((a) => a.tier == AlertTier.expired).toList();
    final urgent7 = alerts.where((a) => a.tier == AlertTier.urgent7).toList();
    final alert14 = alerts.where((a) => a.tier == AlertTier.alert14).toList();

    return Column(
      children: [
        // Red urgent banner for expired licenses (H4.5)
        if (expired.isNotEmpty)
          _buildBanner(
            context: context,
            color: Colors.red.shade700,
            icon: Icons.error,
            title: 'Expired Licenses (${expired.length})',
            alerts: expired,
            dateFormat: dateFormat,
          ),
        // Red urgent banner for 7-day alerts (H4.4)
        if (urgent7.isNotEmpty)
          _buildBanner(
            context: context,
            color: Colors.red.shade700,
            icon: Icons.warning,
            title: 'Urgent: Expiring in 7 Days or Less (${urgent7.length})',
            alerts: urgent7,
            dateFormat: dateFormat,
          ),
        // Amber alert banner for 14-day alerts (H4.3)
        if (alert14.isNotEmpty)
          _buildBanner(
            context: context,
            color: Colors.orange.shade700,
            icon: Icons.warning_amber,
            title: 'Alert: Expiring in 14 Days or Less (${alert14.length})',
            alerts: alert14,
            dateFormat: dateFormat,
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
  }) {
    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...alerts.map((alert) {
            final expiryText = alert.tier == AlertTier.expired
                ? 'Expired on ${dateFormat.format(alert.expiresAt)}'
                : 'Expires on ${dateFormat.format(alert.expiresAt)} (${alert.daysRemaining} days)';
            
            return Padding(
              padding: const EdgeInsets.only(left: 28, top: 4),
              child: Text(
                '• ${alert.tenantName}: $expiryText',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            );
          }),
        ],
      ),
    );
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
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String status;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
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
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
