import 'package:flutter/material.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/services/impersonation_service.dart';
import 'package:scholify/core/sync/sync_engine.dart';

/// Tenant Detail Page (Q1)
/// 
/// Displays comprehensive information about a single tenant including:
/// - Basic info: name, ID, plan, seat limit, activation status
/// - License: expiry date
/// - Owner: email
/// - Usage: active students, active staff, MAU, storage GB
/// - Billing: outstanding amount, overdue invoices
/// 
/// Provides actions:
/// - Impersonate tenant
/// - Edit license
/// - Suspend/Activate tenant
/// 
/// Requirements: Q1.1, Q1.2, Q1.3, Q1.4, Q1.5, Q1.6
class TenantDetailPage extends StatefulWidget {
  final String tenantId;
  final SyncEngine syncEngine;
  final ImpersonationService impersonationService;

  const TenantDetailPage({
    super.key,
    required this.tenantId,
    required this.syncEngine,
    required this.impersonationService,
  });

  @override
  State<TenantDetailPage> createState() => _TenantDetailPageState();
}

class _TenantDetailPageState extends State<TenantDetailPage> {
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    // Q1.2, Q1.6: Load data from local Drift tables via stream
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenant Details'),
      ),
      body: StreamBuilder<TenantUsageBillingView?>(
        stream: _watchTenantDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Text('Tenant not found'),
            );
          }

          final tenant = snapshot.data!;
          return _buildDetailView(tenant);
        },
      ),
    );
  }

  /// Watch tenant details from TenantUsageBillingView (Q1.2, Q1.6)
  Stream<TenantUsageBillingView?> _watchTenantDetails() {
    return widget.syncEngine.database
        .watchTenantUsageBillingViews()
        .map((list) => list.where((t) => t.tenantId == widget.tenantId).firstOrNull);
  }

  Widget _buildDetailView(TenantUsageBillingView tenant) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Information Section
          _buildSection(
            title: 'Basic Information',
            children: [
              _buildInfoRow('Tenant Name', tenant.tenantName),
              _buildInfoRow('Tenant ID', tenant.tenantId),
              _buildInfoRow('Plan', tenant.planCode?.toUpperCase() ?? 'N/A'),
              _buildInfoRow('Seat Limit', tenant.seatLimit?.toString() ?? 'Unlimited'),
              _buildInfoRow(
                'Status',
                tenant.licenseActive == true ? 'Active' : 'Suspended',
                valueColor: tenant.licenseActive == true ? Colors.green : Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // License Information Section
          _buildSection(
            title: 'License Information',
            children: [
              _buildInfoRow(
                'Expires At',
                tenant.licenseExpiresAt != null
                    ? _formatDate(tenant.licenseExpiresAt!)
                    : 'Never',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Owner Information Section
          _buildSection(
            title: 'Owner Information',
            children: [
              _buildInfoRow('Owner Email', 'Not available in view'),
            ],
          ),
          const SizedBox(height: 24),

          // Usage Statistics Section
          _buildSection(
            title: 'Usage Statistics',
            children: [
              _buildInfoRow('Active Students', tenant.activeStudents?.toString() ?? '0'),
              _buildInfoRow('Active Staff', tenant.activeStaff?.toString() ?? '0'),
              _buildInfoRow('Monthly Active Users', tenant.monthlyActiveUsers?.toString() ?? '0'),
              _buildInfoRow('Storage (GB)', tenant.storageGb?.toStringAsFixed(2) ?? '0.00'),
            ],
          ),
          const SizedBox(height: 24),

          // Billing Information Section
          _buildSection(
            title: 'Billing Information',
            children: [
              _buildInfoRow(
                'Outstanding Amount',
                '\$${tenant.outstandingAmount?.toStringAsFixed(2) ?? '0.00'}',
                valueColor: (tenant.outstandingAmount ?? 0) > 0 ? Colors.orange : null,
              ),
              _buildInfoRow(
                'Overdue Invoices',
                tenant.overdueInvoices?.toString() ?? '0',
                valueColor: (tenant.overdueInvoices ?? 0) > 0 ? Colors.red : null,
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Action Buttons Section
          _buildActionButtons(tenant),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontWeight: valueColor != null ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(TenantUsageBillingView tenant) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Q1.3: Impersonate button
        ElevatedButton.icon(
          onPressed: _isUpdating ? null : () => _handleImpersonate(tenant),
          icon: const Icon(Icons.person_outline),
          label: const Text('Impersonate Tenant'),
        ),
        const SizedBox(height: 12),

        // Q1.4: Edit License button
        ElevatedButton.icon(
          onPressed: _isUpdating ? null : () => _handleEditLicense(tenant),
          icon: const Icon(Icons.edit),
          label: const Text('Edit License'),
        ),
        const SizedBox(height: 12),

        // Q1.5: Suspend/Activate toggle
        ElevatedButton.icon(
          onPressed: _isUpdating ? null : () => _handleToggleStatus(tenant),
          icon: Icon(tenant.licenseActive == true ? Icons.block : Icons.check_circle),
          label: Text(tenant.licenseActive == true ? 'Suspend Tenant' : 'Activate Tenant'),
          style: ElevatedButton.styleFrom(
            backgroundColor: tenant.licenseActive == true ? Colors.red : Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  /// Q1.3: Impersonate tenant
  Future<void> _handleImpersonate(TenantUsageBillingView tenant) async {
    try {
      await widget.impersonationService.startImpersonation(
        tenant.tenantId,
        tenant.tenantName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Now impersonating ${tenant.tenantName}'),
            backgroundColor: Colors.blue,
          ),
        );
        // Navigate back to dashboard
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to impersonate: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Q1.4: Navigate to edit license page
  void _handleEditLicense(TenantUsageBillingView tenant) {
    // Navigate to TenantLicensingPage (implementation depends on routing setup)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Navigate to Tenant Licensing Page (to be implemented)'),
      ),
    );
  }

  /// Q1.5: Toggle tenant activation status
  Future<void> _handleToggleStatus(TenantUsageBillingView tenant) async {
    setState(() => _isUpdating = true);

    try {
      final newStatus = !(tenant.licenseActive == true);
      
      // Query for the license ID first
      final licenses = await (widget.syncEngine.database
              .select(widget.syncEngine.database.tenantLicenseEntries)
            ..where((tbl) => tbl.tenantId.equals(tenant.tenantId))
            ..limit(1))
          .get();

      if (licenses.isEmpty) {
        throw Exception('License not found for tenant');
      }

      final licenseId = licenses.first.id;
      
      // Update license status using database method
      await widget.syncEngine.database.setTenantLicenseStatus(
        licenseId: licenseId,
        tenantId: tenant.tenantId,
        isActive: newStatus,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tenant ${newStatus ? 'activated' : 'suspended'} successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
