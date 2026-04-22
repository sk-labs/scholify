import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

class UsageBillingMonitorPage extends StatelessWidget {
  const UsageBillingMonitorPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return AnimatedBuilder(
      animation: Listenable.merge([tenantContext, syncEngine]),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Usage & Billing Monitor'),
            actions: [
              IconButton(
                tooltip: 'Sync now',
                onPressed: syncEngine.isSyncing
                    ? null
                    : () {
                        syncEngine.manualSync();
                      },
                icon: syncEngine.isSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: StreamBuilder<List<TenantUsageBillingView>>(
              stream: syncEngine.database.watchTenantUsageBillingViews(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Failed to load usage metrics: ${snapshot.error}',
                    ),
                  );
                }

                final rows = snapshot.data ?? const <TenantUsageBillingView>[];
                if (rows.isEmpty) {
                  return const Center(
                    child: Text(
                      'No tenant usage data yet. Create tenant licenses and run sync.',
                    ),
                  );
                }

                final atRiskCount = rows.where(_isAtRisk).length;
                final totalOutstanding = rows.fold<double>(
                  0,
                  (sum, row) => sum + (row.outstandingAmount ?? 0),
                );
                final totalCollected = rows.fold<double>(
                  0,
                  (sum, row) => sum + (row.collectedAmount ?? 0),
                );

                return ListView(
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _metricChip('Tenants', '${rows.length}'),
                        _metricChip('At Risk', '$atRiskCount'),
                        _metricChip(
                          'Outstanding',
                          totalOutstanding.toStringAsFixed(2),
                        ),
                        _metricChip(
                          'Collected',
                          totalCollected.toStringAsFixed(2),
                        ),
                        _metricChip(
                          'Pending Sync',
                          '${syncEngine.pendingJobs}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...rows.map(
                      (row) => _TenantUsageCard(
                        row: row,
                        dateFormat: dateFormat,
                        atRisk: _isAtRisk(row),
                        onSetContext: () {
                          tenantContext.setTenant(
                            tenantId: row.tenantId,
                            tenantName: row.tenantName,
                            role: 'school_owner',
                            isSuperAdmin: true,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Tenant context switched to ${row.tenantName}.',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  bool _isAtRisk(TenantUsageBillingView row) {
    final seatLimit = row.seatLimit ?? 0;
    final activeStudents = row.activeStudents ?? 0;
    final utilization = seatLimit <= 0
        ? 0.0
        : (activeStudents / seatLimit) * 100;
    final overdue = row.overdueInvoices ?? 0;
    final outstanding = row.outstandingAmount ?? 0;
    return utilization >= 90 || overdue > 0 || outstanding > 0;
  }

  Widget _metricChip(String label, String value) {
    return Chip(label: Text('$label: $value'));
  }
}

class _TenantUsageCard extends StatelessWidget {
  const _TenantUsageCard({
    required this.row,
    required this.dateFormat,
    required this.atRisk,
    required this.onSetContext,
  });

  final TenantUsageBillingView row;
  final DateFormat dateFormat;
  final bool atRisk;
  final VoidCallback onSetContext;

  @override
  Widget build(BuildContext context) {
    final seatLimit = row.seatLimit ?? 0;
    final activeStudents = row.activeStudents ?? 0;
    final activeStaff = row.activeStaff ?? 0;
    final monthlyActiveUsers = row.monthlyActiveUsers ?? 0;
    final storageGb = row.storageGb ?? 0;
    final outstandingAmount = row.outstandingAmount ?? 0;
    final collectedAmount = row.collectedAmount ?? 0;
    final overdueInvoices = row.overdueInvoices ?? 0;
    final utilization = seatLimit <= 0
        ? 0.0
        : (activeStudents / seatLimit) * 100;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.tenantName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Chip(
                  label: Text(atRisk ? 'AT RISK' : 'HEALTHY'),
                  backgroundColor: atRisk
                      ? Colors.orange.shade100
                      : Colors.green.shade100,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Plan: ${(row.planCode ?? 'N/A').toUpperCase()}'),
            Text('Seats: $activeStudents / $seatLimit | Staff: $activeStaff'),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: (utilization / 100).clamp(0.0, 1.0),
              minHeight: 8,
            ),
            const SizedBox(height: 4),
            Text('Seat utilization: ${utilization.toStringAsFixed(1)}%'),
            Text('Monthly Active Users: $monthlyActiveUsers'),
            Text('Storage: ${storageGb.toStringAsFixed(2)} GB'),
            Text(
              'Outstanding: ${outstandingAmount.toStringAsFixed(2)} | Collected: ${collectedAmount.toStringAsFixed(2)}',
            ),
            Text('Overdue invoices: $overdueInvoices'),
            if (row.nextBillingAt != null)
              Text(
                'Next billing: ${dateFormat.format(row.nextBillingAt!.toLocal())}',
              ),
            if (row.licenseExpiresAt != null)
              Text(
                'License expires: ${dateFormat.format(row.licenseExpiresAt!.toLocal())}',
              ),
            if (row.updatedAt != null)
              Text(
                'Usage updated: ${dateFormat.format(row.updatedAt!.toLocal())}',
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: onSetContext,
                  icon: const Icon(Icons.switch_account),
                  label: const Text('Set Context'),
                ),
                Chip(
                  label: Text(
                    'Billing: ${(row.billingStatus ?? 'unknown').toUpperCase()}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
