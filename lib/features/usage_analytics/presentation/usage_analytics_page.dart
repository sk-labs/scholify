import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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
        // MAU chart
        Expanded(
          child: _MauTimeSeriesChart(
            tenantId: tenantId,
            syncEngine: widget.syncEngine,
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

/// MAU Time-Series Chart widget (B4.3)
///
/// Displays a 6-month line chart of Monthly Active Users for a single tenant,
/// sourced from TenantUsageMetricEntries ordered by periodKey.
class _MauTimeSeriesChart extends StatelessWidget {
  const _MauTimeSeriesChart({
    required this.tenantId,
    required this.syncEngine,
  });

  final String tenantId;
  final SyncEngine syncEngine;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TenantUsageMetricEntry>>(
      stream: _watchMetrics(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading metrics: ${snapshot.error}'),
          );
        }

        final allMetrics = snapshot.data ?? [];

        // Take the last 6 periods, sorted by periodKey ascending
        final metrics = (allMetrics.toList()
              ..sort((a, b) => a.periodKey.compareTo(b.periodKey)))
            .reversed
            .take(6)
            .toList()
            .reversed
            .toList();

        if (metrics.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.show_chart, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No usage data available',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'MAU data will appear here after sync',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Monthly Active Users — Last ${metrics.length} Months',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Tenant: $tenantId',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Expanded(child: _buildChart(context, metrics)),
            ],
          ),
        );
      },
    );
  }

  Stream<List<TenantUsageMetricEntry>> _watchMetrics() {
    return (syncEngine.database.select(syncEngine.database.tenantUsageMetricEntries)
          ..where((tbl) => tbl.tenantId.equals(tenantId)))
        .watch();
  }

  Widget _buildChart(
      BuildContext context, List<TenantUsageMetricEntry> metrics) {
    final maxMau = metrics
        .map((m) => m.monthlyActiveUsers.toDouble())
        .fold(0.0, (a, b) => a > b ? a : b);
    final yMax = maxMau < 10 ? 10.0 : maxMau * 1.2;

    final spots = metrics.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        entry.value.monthlyActiveUsers.toDouble(),
      );
    }).toList();

    final colorScheme = Theme.of(context).colorScheme;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (metrics.length - 1).toDouble(),
        minY: 0,
        maxY: yMax,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yMax / 5,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withOpacity(0.2),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade300),
            left: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= metrics.length) {
                  return const SizedBox.shrink();
                }
                // periodKey format: YYYY-MM
                final periodKey = metrics[idx].periodKey;
                String label;
                try {
                  final parts = periodKey.split('-');
                  if (parts.length >= 2) {
                    final month = int.parse(parts[1]);
                    label = DateFormat('MMM').format(DateTime(0, month));
                    if (parts.length >= 1) label += '\n${parts[0]}';
                  } else {
                    label = periodKey;
                  }
                } catch (_) {
                  label = periodKey;
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (value, meta) {
                if (value == meta.max) return const SizedBox.shrink();
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 11),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: colorScheme.primary,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) =>
                  FlDotCirclePainter(
                radius: 5,
                color: colorScheme.primary,
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: colorScheme.primary.withOpacity(0.12),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.x.toInt();
                final periodKey = idx < metrics.length
                    ? metrics[idx].periodKey
                    : '';
                return LineTooltipItem(
                  '$periodKey\n${spot.y.toInt()} MAU',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}
