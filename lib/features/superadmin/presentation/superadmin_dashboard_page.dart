import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/license_alert_service.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import 'feature_flag_access_page.dart';
import 'school_owner_provisioning_page.dart';
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
                  child: ListView(
                    children: [
                      _ModuleCard(
                        title: 'Tenant Licensing',
                        subtitle:
                            'Create licenses, assign plans, and suspend/activate schools.',
                        trailing: superadminMode ? 'Active' : 'Restricted',
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
                      _ModuleCard(
                        title: 'School Owner Provisioning',
                        subtitle:
                            'Create owner accounts and bootstrap tenant defaults.',
                        trailing: activeTenant,
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
                      _ModuleCard(
                        title: 'Usage and Billing Monitor',
                        subtitle:
                            'Track tenant limits, seat counts, and renewal lifecycle.',
                        trailing: 'Pending sync jobs: ${syncEngine.pendingJobs}',
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
                      _ModuleCard(
                        title: 'Feature Flags and Add-ons',
                        subtitle:
                            'Enable/disable modules per tenant for plan-based access.',
                        trailing: 'Configure Access',
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
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Text(
          trailing,
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        onTap: onTap,
      ),
    );
  }
}
