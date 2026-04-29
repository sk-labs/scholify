import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../../core/database/local_database.dart';
import '../../../core/services/plan_comparison_service.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

/// Plan Upgrade Request Review Page for Superadmin
/// 
/// Feature: scholify-roadmap-tracker
/// Requirements: B2.5, B2.6, B2.7
/// 
/// This page allows superadmins to review and action plan upgrade requests
/// submitted by school owners.
class PlanUpgradeReviewPage extends StatefulWidget {
  const PlanUpgradeReviewPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<PlanUpgradeReviewPage> createState() => _PlanUpgradeReviewPageState();
}

class _PlanUpgradeReviewPageState extends State<PlanUpgradeReviewPage> {
  late final PlanComparisonService _planComparisonService;

  @override
  void initState() {
    super.initState();
    _planComparisonService = PlanComparisonService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Upgrade Requests'),
      ),
      body: StreamBuilder<List<PlanUpgradeRequestWithTenant>>(
        stream: _watchPendingRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load requests: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final requests = snapshot.data ?? [];

          if (requests.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Pending Requests',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All upgrade requests have been reviewed.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final request = requests[index];
              return _buildRequestCard(request);
            },
          );
        },
      ),
    );
  }

  /// Watches pending upgrade requests with tenant information (B2.5)
  Stream<List<PlanUpgradeRequestWithTenant>> _watchPendingRequests() {
    return (widget.syncEngine.database
            .select(widget.syncEngine.database.planUpgradeRequestEntries)
          ..where((tbl) => tbl.status.equals('pending'))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
        .watch()
        .asyncMap((requests) async {
      final results = <PlanUpgradeRequestWithTenant>[];

      for (final request in requests) {
        // Load tenant information
        final tenant = await (widget.syncEngine.database
                .select(widget.syncEngine.database.tenantRecords)
              ..where((tbl) => tbl.id.equals(request.tenantId))
              ..limit(1))
            .getSingleOrNull();

        results.add(PlanUpgradeRequestWithTenant(
          request: request,
          tenantName: tenant?.name ?? 'Unknown Tenant',
        ));
      }

      return results;
    });
  }

  Widget _buildRequestCard(PlanUpgradeRequestWithTenant data) {
    final request = data.request;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with tenant name
            Row(
              children: [
                const Icon(Icons.business, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data.tenantName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'PENDING',
                    style: TextStyle(
                      color: Colors.orange[900],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Plan upgrade details
            Row(
              children: [
                Expanded(
                  child: _buildPlanBadge(
                    'Current Plan',
                    request.currentPlan,
                    Colors.grey,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(Icons.arrow_forward, color: Colors.blue),
                ),
                Expanded(
                  child: _buildPlanBadge(
                    'Requested Plan',
                    request.requestedPlan,
                    Colors.green,
                  ),
                ),
              ],
            ),

            // Message (if provided)
            if (request.message != null && request.message!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.message, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Message from School Owner:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      request.message!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],

            // Submitted date
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Submitted: ${_formatDate(request.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),

            // Action buttons (B2.6, B2.7)
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _handleApprove(request),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleReject(request),
                    icon: const Icon(Icons.cancel),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanBadge(String label, String planCode, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color),
          ),
          child: Text(
            _planComparisonService.getPlanDisplayName(planCode).toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Approves an upgrade request (B2.6)
  Future<void> _handleApprove(PlanUpgradeRequestEntry request) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Upgrade Request'),
        content: Text(
          'Are you sure you want to approve this upgrade from '
          '${_planComparisonService.getPlanDisplayName(request.currentPlan)} to '
          '${_planComparisonService.getPlanDisplayName(request.requestedPlan)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final now = DateTime.now().toUtc();

      await widget.syncEngine.database.transaction(() async {
        // 1. Update tenant license with new plan code (B2.6)
        await (widget.syncEngine.database
                .update(widget.syncEngine.database.tenantLicenseEntries)
              ..where((tbl) => tbl.tenantId.equals(request.tenantId)))
            .write(
          TenantLicenseEntriesCompanion(
            planCode: Value(request.requestedPlan),
            updatedAt: Value(now),
          ),
        );

        // 2. Mark request as approved (B2.6)
        await (widget.syncEngine.database
                .update(widget.syncEngine.database.planUpgradeRequestEntries)
              ..where((tbl) => tbl.id.equals(request.id)))
            .write(
          PlanUpgradeRequestEntriesCompanion(
            status: const Value('approved'),
            reviewedBy: const Value('superadmin'),
            reviewedAt: Value(now),
            updatedAt: Value(now),
          ),
        );

        // 3. Enqueue sync operations
        await widget.syncEngine.enqueueOperation(
          entityType: 'tenant_license',
          entityId: 'lic_${request.tenantId}',
          operation: 'upsert',
          payload: jsonEncode({
            'id': 'lic_${request.tenantId}',
            'tenantId': request.tenantId,
            'planCode': request.requestedPlan,
            'updatedAt': now.toIso8601String(),
          }),
        );

        await widget.syncEngine.enqueueOperation(
          entityType: 'plan_upgrade_request',
          entityId: request.id,
          operation: 'upsert',
          payload: jsonEncode({
            'id': request.id,
            'tenantId': request.tenantId,
            'status': 'approved',
            'reviewedBy': 'superadmin',
            'reviewedAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          }),
        );
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upgrade request approved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve request: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Rejects an upgrade request (B2.7)
  Future<void> _handleReject(PlanUpgradeRequestEntry request) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Upgrade Request'),
        content: const Text(
          'Are you sure you want to reject this upgrade request? '
          'The school owner will be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final now = DateTime.now().toUtc();

      // Mark request as rejected (B2.7)
      await (widget.syncEngine.database
              .update(widget.syncEngine.database.planUpgradeRequestEntries)
            ..where((tbl) => tbl.id.equals(request.id)))
          .write(
        PlanUpgradeRequestEntriesCompanion(
          status: const Value('rejected'),
          reviewedBy: const Value('superadmin'),
          reviewedAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Enqueue sync operation (B2.7)
      await widget.syncEngine.enqueueOperation(
        entityType: 'plan_upgrade_request',
        entityId: request.id,
        operation: 'upsert',
        payload: jsonEncode({
          'id': request.id,
          'tenantId': request.tenantId,
          'status': 'rejected',
          'reviewedBy': 'superadmin',
          'reviewedAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        }),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upgrade request rejected'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reject request: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// Helper class to combine request with tenant information
class PlanUpgradeRequestWithTenant {
  const PlanUpgradeRequestWithTenant({
    required this.request,
    required this.tenantName,
  });

  final PlanUpgradeRequestEntry request;
  final String tenantName;
}
