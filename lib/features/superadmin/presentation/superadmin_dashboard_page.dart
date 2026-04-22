import 'package:flutter/material.dart';

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
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([tenantContext, syncEngine]),
      builder: (context, _) {
        final activeTenant = tenantContext.tenantName ?? 'No tenant selected';
        final superadminMode = tenantContext.isSuperAdmin;

        return Scaffold(
          appBar: AppBar(title: const Text('Superadmin Dashboard')),
          body: Padding(
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
        );
      },
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
