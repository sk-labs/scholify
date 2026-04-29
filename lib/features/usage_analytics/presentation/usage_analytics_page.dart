import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/local_database.dart';
import '../../../core/services/csv_export_service.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

/// Usage Analytics Page for Superadmin
/// 
/// Feature: scholify-roadmap-tracker
/// Requirements: B4.1, B4.2, B4.3, B4.4, B4.5, B4.6
/// 
/// Displays per-tenant module usage statistics including active students,
/// active staff, monthly active users, storage consumed, and module engagement.
class UsageAnalyticsPage extends StatefulWidget {
  const UsageAnalyticsPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<UsageAnalyticsPage> createState() => _UsageAnalyticsPageState();
}

class _UsageAnalyticsPageState extends State<UsageAnalyticsPage> {
  late final CSVExportService _csvExportService;
  String? _selectedTenantId;

  @override
  void initState() {
    super.initState();
    _csvExportService = CSVExportService(database: widget.syncEngine.database);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usage Analytics'),
        actions: [
          // CSV Export button (B4.6)
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export to CSV',
            onPressed: _handleExportCSV,
          ),
        ],
      ),
      body: _selectedTenantId == null
          ? _buildTenantList()
          : _buildTenantDetail(_selectedTenantId!),
    );
  }

  /// Builds the main tenant metrics table (B4.1, B4.2, B4.4, B4.5)
  Widget _buildTenantList() {
    return StreamBuilder<List<TenantUsageBillingView>>(
      stream: widget.syncEngine.database.watchTenantUsageBillingViews(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading analytics: ${snapshot.error}'),
          );
        }

        final metrics = snapshot.data ?? [];

        if (metrics.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No usage data available',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Usage metrics will appear here after sync',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Tenant Name')),
                  DataColumn(label: Text('Plan')),
                  DataColumn(label: Text('Active Students')),
                  DataColumn(label: Text('Active Staff')),
                  DataColumn(label: Text('MAU')),
                  DataColumn(label: Text('Storage (GB)')),
                  DataColumn(label: Text('Module Engagement')),
                  DataColumn(label: Text('Last Updated')),
                ],
                rows: metrics.map((metric) => _buildMetricRow(metric)).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  DataRow _buildMetricRow(TenantUsageBillingView metric) {
    final now = DateTime.now();
    final isStale = metric.updatedAt != null 
        ? _isDataStale(metric.updatedAt!, now) 
        : true; // B4.5

    return DataRow(
      onSelectChanged: (_) {
        setState(() {
          _selectedTenantId = metric.tenantId;
        });
      },
      cells: [
        DataCell(
          Row(
            children: [
              Text(metric.tenantName),
              if (isStale) ...[
                const SizedBox(width: 8),
                const Tooltip(
                  message: 'Data may be stale (not synced in 24h)',
                  child: Icon(
                    Icons.warning_amber,
                    size: 16,
                    color: Colors.orange,
                  ),
                ),
              ],
            ],
          ),
        ),
        DataCell(Text(metric.planCode ?? '-')),
        DataCell(Text('${metric.activeStudents ?? 0}')),
        DataCell(Text('${metric.activeStaff ?? 0}')),
        DataCell(Text('${metric.monthlyActiveUsers ?? 0}')),
        DataCell(Text((metric.storageGb ?? 0.0).toStringAsFixed(2))),
        DataCell(
          FutureBuilder<int>(
            future: _getModuleEngagement(metric.tenantId),
            builder: (context, snapshot) {
              return Text('${snapshot.data ?? 0} modules');
            },
          ),
        ),
        DataCell(Text(metric.updatedAt != null ? _formatDate(metric.updatedAt!) : '-')),
      ],
    );
  }

  /// Checks if data is stale (not synced in 24h) (B4.5)
  bool _isDataStale(DateTime lastUpdated, DateTime now) {
    return now.difference(lastUpdated).inHours > 24;
  }

  /// Gets module engagement count (B4.2, B4.5)
  Future<int> _getModuleEngagement(String tenantId) async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    // Query audit log for tenant
    final entries = await (widget.syncEngine.database
            .select(widget.syncEngine.database.auditLogEntries)
          ..where((tbl) => tbl.tenantId.equals(tenantId)))
        .get();

    // Filter for last 30 days and count distinct entity types
    final recentEntries = entries.where((e) => 
        e.timestamp.isAfter(thirtyDaysAgo) || e.timestamp.isAtSameMomentAs(thirtyDaysAgo));
    final entityTypes = recentEntries.map((e) => e.entityType).toSet();
    return entityTypes.length;
  }

  /// Builds tenant detail view with MAU time-series chart (B4.3)
  Widget _buildTenantDetail(String tenantId) {
    return Column(
      children: [
        // Back button
        Container(
          padding: const EdgeInsets.all(16),
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () {
              setState(() {
                _selectedTenantId = null;
              });
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to List'),
          ),
        ),
        // Detail content
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.show_chart, size: 64, color: Colors.blue),
                  const SizedBox(height: 16),
                  const Text(
                    'MAU Time-Series Chart',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tenant ID: $tenantId',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chart visualization requires a charting library like fl_chart.\n'
                    'Add fl_chart to pubspec.yaml to enable this feature.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
  }

  /// Exports usage analytics to CSV (B4.6)
  Future<void> _handleExportCSV() async {
    try {
      final metrics = await widget.syncEngine.database
          .watchTenantUsageBillingViews()
          .first;

      if (metrics.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to export')),
        );
        return;
      }

      // Export using CSVExportService
      final csv = await _csvExportService.exportTenantList(metrics);
      await _csvExportService.saveCsvFile(csv, filename: 'usage_analytics.csv');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usage analytics exported successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export feature requires additional setup: $error'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}
