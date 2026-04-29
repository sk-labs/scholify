import 'package:flutter/material.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/sync/sync_engine.dart';

/// Dashboard Summary Cards (Q4)
/// 
/// Displays four summary metric cards showing platform health at a glance:
/// - Total Tenants
/// - Active Tenants
/// - At Risk Tenants
/// - Expiring Soon (≤30 days)
/// 
/// Requirements: Q4.1, Q4.2, Q4.3, Q4.4, Q4.5, Q4.6, Q4.7
class DashboardSummaryCards extends StatelessWidget {
  final SyncEngine syncEngine;

  const DashboardSummaryCards({
    super.key,
    required this.syncEngine,
  });

  @override
  Widget build(BuildContext context) {
    // Q4.2, Q4.7: Compute card values from TenantUsageBillingView stream
    return StreamBuilder<List<TenantUsageBillingView>>(
      stream: syncEngine.database.watchTenantUsageBillingViews(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingCards();
        }

        if (snapshot.hasError) {
          return _ErrorCards(error: snapshot.error.toString());
        }

        final tenants = snapshot.data ?? [];
        final metrics = _computeMetrics(tenants);

        return _buildCards(context, metrics);
      },
    );
  }

  /// Q4.2: Compute card values from local data without network call
  DashboardMetrics _computeMetrics(List<TenantUsageBillingView> tenants) {
    final now = DateTime.now();
    final thirtyDaysFromNow = now.add(const Duration(days: 30));

    // Q4.3: Total Tenants - count of all tenants
    final totalTenants = tenants.length;

    // Q4.4: Active - count where licenseActive = true
    final activeTenants = tenants
        .where((t) => t.licenseActive == true)
        .length;

    // Q4.5: At Risk - seat utilization >= 90% OR overdueInvoices > 0 OR outstandingAmount > 0
    final atRiskTenants = tenants.where((t) {
      // Check overdue invoices
      if ((t.overdueInvoices ?? 0) > 0) return true;

      // Check outstanding amount
      if ((t.outstandingAmount ?? 0) > 0) return true;

      // Check seat utilization >= 90%
      final seatLimit = t.seatLimit;
      final activeStudents = t.activeStudents ?? 0;
      if (seatLimit != null && seatLimit > 0) {
        final utilization = activeStudents / seatLimit;
        if (utilization >= 0.9) return true;
      }

      return false;
    }).length;

    // Q4.6: Expiring Soon - active tenants with expiresAt <= now + 30 days
    final expiringSoonTenants = tenants.where((t) {
      if (t.licenseActive != true) return false;
      final expiresAt = t.licenseExpiresAt;
      if (expiresAt == null) return false;
      return expiresAt.isBefore(thirtyDaysFromNow) || 
             expiresAt.isAtSameMomentAs(thirtyDaysFromNow);
    }).length;

    return DashboardMetrics(
      totalTenants: totalTenants,
      activeTenants: activeTenants,
      atRiskTenants: atRiskTenants,
      expiringSoonTenants: expiringSoonTenants,
    );
  }

  Widget _buildCards(BuildContext context, DashboardMetrics metrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive layout: 2 columns on mobile, 4 columns on desktop
        final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
        final childAspectRatio = constraints.maxWidth > 800 ? 1.5 : 1.2;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            // Q4.1, Q4.3: Total Tenants card
            _SummaryCard(
              title: 'Total Tenants',
              value: metrics.totalTenants.toString(),
              icon: Icons.business,
              color: Colors.blue,
            ),

            // Q4.1, Q4.4: Active card
            _SummaryCard(
              title: 'Active',
              value: metrics.activeTenants.toString(),
              icon: Icons.check_circle,
              color: Colors.green,
            ),

            // Q4.1, Q4.5: At Risk card
            _SummaryCard(
              title: 'At Risk',
              value: metrics.atRiskTenants.toString(),
              icon: Icons.warning,
              color: Colors.orange,
            ),

            // Q4.1, Q4.6: Expiring Soon card
            _SummaryCard(
              title: 'Expiring Soon (≤30d)',
              value: metrics.expiringSoonTenants.toString(),
              icon: Icons.schedule,
              color: Colors.red,
            ),
          ],
        );
      },
    );
  }
}

/// Loading state for cards
class _LoadingCards extends StatelessWidget {
  const _LoadingCards();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: List.generate(
        4,
        (index) => Card(
          child: Center(
            child: CircularProgressIndicator(
              color: Colors.grey.shade400,
            ),
          ),
        ),
      ),
    );
  }
}

/// Error state for cards
class _ErrorCards extends StatelessWidget {
  final String error;

  const _ErrorCards({required this.error});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.error, color: Colors.red.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Failed to load metrics: $error',
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual summary card widget
class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashboard metrics data class
class DashboardMetrics {
  final int totalTenants;
  final int activeTenants;
  final int atRiskTenants;
  final int expiringSoonTenants;

  const DashboardMetrics({
    required this.totalTenants,
    required this.activeTenants,
    required this.atRiskTenants,
    required this.expiringSoonTenants,
  });
}
