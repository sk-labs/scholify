import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../../core/database/local_database.dart';
import '../../../core/services/plan_comparison_service.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

/// Plan Upgrade Request Page for School Owners
/// 
/// Feature: scholify-roadmap-tracker
/// Requirements: B2.1, B2.2, B2.3, B2.4, B2.8
/// 
/// This page allows school owners to submit plan upgrade requests from within
/// the app. The Superadmin is notified and can action the upgrade without
/// requiring an out-of-band email.
class PlanUpgradePage extends StatefulWidget {
  const PlanUpgradePage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<PlanUpgradePage> createState() => _PlanUpgradePageState();
}

class _PlanUpgradePageState extends State<PlanUpgradePage> {
  late final PlanComparisonService _planComparisonService;

  final TextEditingController _messageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _currentPlan;
  String? _selectedRequestedPlan;
  PlanUpgradeRequestEntry? _existingRequest;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _planComparisonService = PlanComparisonService();
    _loadCurrentPlanAndExistingRequest();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentPlanAndExistingRequest() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tenantId = widget.tenantContext.tenantId;
      if (tenantId == null) {
        setState(() {
          _errorMessage = 'No tenant context available';
          _isLoading = false;
        });
        return;
      }

      // Load current plan from license
      final license = await (widget.syncEngine.database
              .select(widget.syncEngine.database.tenantLicenseEntries)
            ..where((tbl) => tbl.tenantId.equals(tenantId))
            ..limit(1))
          .getSingleOrNull();

      if (license == null) {
        setState(() {
          _errorMessage = 'No license found for your tenant';
          _isLoading = false;
        });
        return;
      }

      // Check for existing pending request (B2.8)
      final existingRequest = await (widget.syncEngine.database
              .select(widget.syncEngine.database.planUpgradeRequestEntries)
            ..where((tbl) => tbl.tenantId.equals(tenantId))
            ..where((tbl) => tbl.status.equals('pending'))
            ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
            ..limit(1))
          .getSingleOrNull();

      setState(() {
        _currentPlan = license.planCode;
        _existingRequest = existingRequest;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Failed to load plan information: $error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Plan Upgrade'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
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
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loadCurrentPlanAndExistingRequest,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _existingRequest != null
                  ? _buildExistingRequestView()
                  : _buildRequestForm(),
    );
  }

  /// Displays existing pending request status (B2.8)
  Widget _buildExistingRequestView() {
    final request = _existingRequest!;
    final statusColor = request.status == 'approved'
        ? Colors.green
        : request.status == 'rejected'
            ? Colors.red
            : Colors.orange;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    request.status == 'pending'
                        ? Icons.pending_outlined
                        : request.status == 'approved'
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                    size: 64,
                    color: statusColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Upgrade Request ${request.status == 'pending' ? 'Pending' : request.status == 'approved' ? 'Approved' : 'Rejected'}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: statusColor,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _buildInfoRow('Current Plan', _planComparisonService.getPlanDisplayName(request.currentPlan)),
                  const SizedBox(height: 8),
                  _buildInfoRow('Requested Plan', _planComparisonService.getPlanDisplayName(request.requestedPlan)),
                  if (request.message != null && request.message!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow('Message', request.message!),
                  ],
                  const SizedBox(height: 8),
                  _buildInfoRow('Submitted', _formatDate(request.createdAt)),
                  if (request.reviewedAt != null) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow('Reviewed', _formatDate(request.reviewedAt!)),
                  ],
                  const SizedBox(height: 24),
                  if (request.status == 'pending')
                    Text(
                      'Your upgrade request is pending review by the administrator. '
                      'You will be notified when it is reviewed.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    )
                  else if (request.status == 'approved')
                    Text(
                      'Your upgrade request has been approved! Your plan will be updated shortly.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.green[700],
                          ),
                      textAlign: TextAlign.center,
                    )
                  else
                    Text(
                      'Your upgrade request was not approved. Please contact support for more information.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.red[700],
                          ),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Builds the upgrade request form (B2.1, B2.2)
  Widget _buildRequestForm() {
    final upgradeOptions = _planComparisonService.getUpgradeOptions(_currentPlan ?? '');

    if (upgradeOptions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.workspace_premium,
                size: 64,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              Text(
                'You are already on the highest plan!',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Current Plan: ${_planComparisonService.getPlanDisplayName(_currentPlan ?? '')}',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                const Icon(
                  Icons.upgrade,
                  size: 64,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                Text(
                  'Request Plan Upgrade',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Current Plan (read-only) (B2.2)
                TextFormField(
                  initialValue: _planComparisonService.getPlanDisplayName(_currentPlan ?? ''),
                  decoration: const InputDecoration(
                    labelText: 'Current Plan',
                    prefixIcon: Icon(Icons.workspace_premium),
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                  enabled: false,
                ),
                const SizedBox(height: 16),

                // Requested Plan Dropdown (only higher plans) (B2.2, B2.3)
                DropdownButtonFormField<String>(
                  initialValue: _selectedRequestedPlan,
                  decoration: const InputDecoration(
                    labelText: 'Requested Plan',
                    prefixIcon: Icon(Icons.arrow_upward),
                    border: OutlineInputBorder(),
                  ),
                  items: upgradeOptions
                      .map(
                        (plan) => DropdownMenuItem<String>(
                          value: plan,
                          child: Text(_planComparisonService.getPlanDisplayName(plan)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedRequestedPlan = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a plan';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Optional Message (B2.2)
                TextFormField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message (Optional)',
                    hintText: 'Tell us why you need this upgrade...',
                    prefixIcon: Icon(Icons.message),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                  maxLength: 500,
                ),
                const SizedBox(height: 24),

                // Submit Button (B2.4)
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _isSubmitting ? 'Submitting...' : 'Submit Request',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),

                // Info Text
                Text(
                  'Your request will be reviewed by the administrator. '
                  'You will be notified when it is approved or rejected.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate upgrade (B2.3)
    if (!_planComparisonService.isUpgrade(_currentPlan!, _selectedRequestedPlan!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The requested plan must be higher than your current plan.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final tenantId = widget.tenantContext.tenantId!;
      final requestId = 'upgrade_req_${tenantId}_${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now().toUtc();

      // Insert PlanUpgradeRequestEntry (B2.4)
      await widget.syncEngine.database
          .into(widget.syncEngine.database.planUpgradeRequestEntries)
          .insert(
            PlanUpgradeRequestEntriesCompanion.insert(
              id: requestId,
              tenantId: tenantId,
              currentPlan: _currentPlan!,
              requestedPlan: _selectedRequestedPlan!,
              message: Value(_messageController.text.trim().isEmpty
                  ? null
                  : _messageController.text.trim()),
            ),
          );

      // Enqueue sync operation (B2.4)
      await widget.syncEngine.enqueueOperation(
        entityType: 'plan_upgrade_request',
        entityId: requestId,
        operation: 'upsert',
        payload: jsonEncode({
          'id': requestId,
          'tenantId': tenantId,
          'currentPlan': _currentPlan,
          'requestedPlan': _selectedRequestedPlan,
          'message': _messageController.text.trim().isEmpty
              ? null
              : _messageController.text.trim(),
          'status': 'pending',
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        }),
      );

      if (!mounted) return;

      // Show confirmation message (B2.4)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upgrade request submitted. You will be notified when reviewed.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );

      // Reload to show pending request
      await _loadCurrentPlanAndExistingRequest();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit request: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
