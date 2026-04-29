import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../../core/database/local_database.dart';
import '../../../core/services/audit_log_service.dart';
import '../../../core/services/wizard_validation_service.dart';
import '../../../core/sync/sync_engine.dart';

/// Tenant Onboarding Wizard Page
///
/// Feature: scholify-roadmap-tracker
/// Requirements: H1.1, H1.2, H1.3, H1.4, H1.5, H1.6, H1.7, H1.8
///
/// A guided 3-step flow that creates a Tenant, issues a License, and provisions
/// a School_Owner in a single session.
///
/// Steps:
/// 1. Tenant Identity: School name input, tenant_id derivation
/// 2. License Configuration: Plan dropdown, seat limit input
/// 3. Owner Email: Email input, validation
/// 4. Confirmation: Summary and "Create Tenant" button
class OnboardingWizardPage extends StatefulWidget {
  const OnboardingWizardPage({
    super.key,
    required this.syncEngine,
    required this.validationService,
    required this.auditLogService,
  });

  final SyncEngine syncEngine;
  final WizardValidationService validationService;
  final AuditLogService auditLogService;

  @override
  State<OnboardingWizardPage> createState() => _OnboardingWizardPageState();
}

class _OnboardingWizardPageState extends State<OnboardingWizardPage> {
  int _currentStep = 0;
  bool _isSaving = false;
  String? _errorMessage;

  // Step 1: Tenant Identity
  final _schoolNameController = TextEditingController();
  String _derivedTenantId = '';
  bool _tenantIdExists = false;

  // Step 2: License Configuration
  String _selectedPlan = 'starter';
  final _seatLimitController = TextEditingController(text: '100');

  // Step 3: Owner Email
  final _ownerEmailController = TextEditingController();

  static const List<String> _plans = ['starter', 'professional', 'enterprise'];

  @override
  void initState() {
    super.initState();
    _schoolNameController.addListener(_onSchoolNameChanged);
  }

  @override
  void dispose() {
    _schoolNameController.removeListener(_onSchoolNameChanged);
    _schoolNameController.dispose();
    _seatLimitController.dispose();
    _ownerEmailController.dispose();
    super.dispose();
  }

  void _onSchoolNameChanged() {
    final schoolName = _schoolNameController.text;
    if (schoolName.trim().isEmpty) {
      setState(() {
        _derivedTenantId = '';
        _tenantIdExists = false;
      });
      return;
    }

    final tenantId = widget.validationService.deriveTenantId(schoolName);
    setState(() {
      _derivedTenantId = tenantId;
    });

    // Check if tenant ID already exists
    widget.validationService.tenantIdExists(tenantId).then((exists) {
      if (mounted) {
        setState(() {
          _tenantIdExists = exists;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenant Onboarding Wizard'),
      ),
      body: _isSaving
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Creating tenant...'),
                ],
              ),
            )
          : Stepper(
              currentStep: _currentStep,
              onStepContinue: _onStepContinue,
              onStepCancel: _onStepCancel,
              controlsBuilder: _buildControls,
              steps: [
                _buildStep1TenantIdentity(),
                _buildStep2LicenseConfiguration(),
                _buildStep3OwnerEmail(),
                _buildStep4Confirmation(),
              ],
            ),
    );
  }

  /// Step 1: Tenant Identity
  Step _buildStep1TenantIdentity() {
    return Step(
      title: const Text('Tenant Identity'),
      subtitle: const Text('School name and tenant ID'),
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _schoolNameController,
            decoration: const InputDecoration(
              labelText: 'School Name',
              hintText: 'Enter the school name',
              border: OutlineInputBorder(),
            ),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) {
              if (!widget.validationService.validateSchoolName(value ?? '')) {
                return 'School name is required.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          if (_derivedTenantId.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _tenantIdExists
                    ? Colors.red.shade50
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _tenantIdExists
                      ? Colors.red.shade200
                      : Colors.blue.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _tenantIdExists ? Icons.error : Icons.info,
                        size: 20,
                        color: _tenantIdExists ? Colors.red : Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Derived Tenant ID:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _derivedTenantId,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                  if (_tenantIdExists) ...[
                    const SizedBox(height: 8),
                    const Text(
                      '⚠️ A school with this name already exists. Please choose a different name.',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (_errorMessage != null && _currentStep == 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Step 2: License Configuration
  Step _buildStep2LicenseConfiguration() {
    return Step(
      title: const Text('License Configuration'),
      subtitle: const Text('Plan and seat limit'),
      isActive: _currentStep >= 1,
      state: _currentStep > 1
          ? StepState.complete
          : _currentStep == 1
              ? StepState.editing
              : StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedPlan,
            decoration: const InputDecoration(
              labelText: 'Plan',
              border: OutlineInputBorder(),
            ),
            items: _plans
                .map(
                  (plan) => DropdownMenuItem<String>(
                    value: plan,
                    child: Text(plan.toUpperCase()),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedPlan = value;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _seatLimitController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Seat Limit',
              hintText: 'Enter the maximum number of students',
              border: OutlineInputBorder(),
            ),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) {
              final parsed = int.tryParse(value?.trim() ?? '');
              if (parsed == null || !widget.validationService.validateSeatLimit(parsed)) {
                return 'Enter a valid positive number.';
              }
              return null;
            },
          ),
          if (_errorMessage != null && _currentStep == 1) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Step 3: Owner Email
  Step _buildStep3OwnerEmail() {
    return Step(
      title: const Text('Owner Email'),
      subtitle: const Text('School owner email address'),
      isActive: _currentStep >= 2,
      state: _currentStep > 2
          ? StepState.complete
          : _currentStep == 2
              ? StepState.editing
              : StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _ownerEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Owner Email',
              hintText: 'Enter the school owner email',
              border: OutlineInputBorder(),
            ),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) {
              if (!widget.validationService.validateEmail(value ?? '')) {
                return 'Enter a valid email address.';
              }
              return null;
            },
          ),
          if (_errorMessage != null && _currentStep == 2) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Step 4: Confirmation
  Step _buildStep4Confirmation() {
    return Step(
      title: const Text('Confirmation'),
      subtitle: const Text('Review and create'),
      isActive: _currentStep >= 3,
      state: _currentStep == 3 ? StepState.editing : StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review the information below and click "Create Tenant" to complete the onboarding.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryRow('School Name', _schoolNameController.text),
                  const Divider(),
                  _buildSummaryRow('Tenant ID', _derivedTenantId),
                  const Divider(),
                  _buildSummaryRow('Plan', _selectedPlan.toUpperCase()),
                  const Divider(),
                  _buildSummaryRow('Seat Limit', _seatLimitController.text),
                  const Divider(),
                  _buildSummaryRow('Owner Email', _ownerEmailController.text),
                ],
              ),
            ),
          ),
          if (_errorMessage != null && _currentStep == 3) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context, ControlsDetails details) {
    final isLastStep = _currentStep == 3;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: _isSaving ? null : details.onStepCancel,
              child: const Text('Back'),
            ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _isSaving ? null : details.onStepContinue,
            child: Text(isLastStep ? 'Create Tenant' : 'Next'),
          ),
        ],
      ),
    );
  }

  void _onStepContinue() {
    setState(() {
      _errorMessage = null;
    });

    // Validate current step
    if (_currentStep == 0) {
      if (!_validateStep1()) return;
    } else if (_currentStep == 1) {
      if (!_validateStep2()) return;
    } else if (_currentStep == 2) {
      if (!_validateStep3()) return;
    } else if (_currentStep == 3) {
      // Final step - create tenant
      _createTenant();
      return;
    }

    // Move to next step
    setState(() {
      _currentStep++;
    });
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _errorMessage = null;
      });
    }
  }

  bool _validateStep1() {
    final schoolName = _schoolNameController.text;

    if (!widget.validationService.validateSchoolName(schoolName)) {
      setState(() {
        _errorMessage = 'School name is required.';
      });
      return false;
    }

    if (_tenantIdExists) {
      setState(() {
        _errorMessage =
            'A school with this name already exists. Please choose a different name.';
      });
      return false;
    }

    return true;
  }

  bool _validateStep2() {
    if (!widget.validationService.validatePlan(_selectedPlan)) {
      setState(() {
        _errorMessage = 'Invalid plan selected.';
      });
      return false;
    }

    final seatLimit = int.tryParse(_seatLimitController.text.trim());
    if (seatLimit == null || !widget.validationService.validateSeatLimit(seatLimit)) {
      setState(() {
        _errorMessage = 'Seat limit must be a positive number.';
      });
      return false;
    }

    return true;
  }

  bool _validateStep3() {
    final email = _ownerEmailController.text;

    if (!widget.validationService.validateEmail(email)) {
      setState(() {
        _errorMessage = 'Enter a valid email address.';
      });
      return false;
    }

    return true;
  }

  /// Creates the tenant atomically with transaction
  ///
  /// Requirements: H1.5, H1.6, H3.1
  ///
  /// WHEN all three steps pass validation, THE Onboarding_Wizard SHALL atomically
  /// write a TenantRecord, a TenantLicenseEntry, and a SchoolOwnerEntry to the
  /// local Drift database and enqueue all three as upsert operations in the Sync_Queue.
  ///
  /// IF any local write fails, THEN THE Onboarding_Wizard SHALL roll back all
  /// partial writes and display an error message identifying the failed step.
  ///
  /// Audit log entries are created for each entity creation (H3.1).
  Future<void> _createTenant() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final schoolName = _schoolNameController.text.trim();
    final tenantId = _derivedTenantId;
    final planCode = _selectedPlan;
    final seatLimit = int.parse(_seatLimitController.text.trim());
    final ownerEmail = _ownerEmailController.text.trim().toLowerCase();

    try {
      // Generate IDs following existing patterns
      final licenseId = 'lic_$tenantId';
      final ownerId = 'owner_$tenantId';
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(days: 365));

      // Begin transaction
      await widget.syncEngine.database.transaction(() async {
        // 1. Insert TenantRecord
        await widget.syncEngine.database.into(widget.syncEngine.database.tenantRecords).insert(
              TenantRecordsCompanion.insert(
                id: tenantId,
                name: schoolName,
                isActive: const Value(true),
                createdAt: Value(now),
              ),
            );

        // Log tenant creation to audit log
        await widget.auditLogService.logWrite(
          entityType: 'TenantRecord',
          entityId: tenantId,
          operation: 'create',
          changedFields: {
            'id': tenantId,
            'name': schoolName,
            'isActive': true,
            'createdAt': now.toIso8601String(),
          },
          tenantId: tenantId,
        );

        // 2. Insert TenantLicenseEntry
        await widget.syncEngine.database.into(widget.syncEngine.database.tenantLicenseEntries).insert(
              TenantLicenseEntriesCompanion.insert(
                id: licenseId,
                tenantId: tenantId,
                schoolOwnerEmail: ownerEmail,
                planCode: Value(planCode),
                seatLimit: Value(seatLimit),
                isActive: const Value(true),
                issuedAt: Value(now),
                expiresAt: Value(expiresAt),
                updatedAt: Value(now),
              ),
            );

        // Log license issuance to audit log
        await widget.auditLogService.logWrite(
          entityType: 'TenantLicenseEntry',
          entityId: licenseId,
          operation: 'create',
          changedFields: {
            'id': licenseId,
            'tenantId': tenantId,
            'schoolOwnerEmail': ownerEmail,
            'planCode': planCode,
            'seatLimit': seatLimit,
            'isActive': true,
            'issuedAt': now.toIso8601String(),
            'expiresAt': expiresAt.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          },
          tenantId: tenantId,
        );

        // 3. Insert SchoolOwnerEntry
        await widget.syncEngine.database.into(widget.syncEngine.database.schoolOwnerEntries).insert(
              SchoolOwnerEntriesCompanion.insert(
                id: ownerId,
                tenantId: tenantId,
                fullName: schoolName, // Derived from school name
                email: ownerEmail,
                phone: const Value(null),
                isPrimary: const Value(true),
                isActive: const Value(true),
                provisioningStatus: const Value('pending'),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );

        // Log owner provisioning to audit log
        await widget.auditLogService.logWrite(
          entityType: 'SchoolOwnerEntry',
          entityId: ownerId,
          operation: 'create',
          changedFields: {
            'id': ownerId,
            'tenantId': tenantId,
            'fullName': schoolName,
            'email': ownerEmail,
            'phone': null,
            'isPrimary': true,
            'isActive': true,
            'provisioningStatus': 'pending',
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          },
          tenantId: tenantId,
        );

        // 4. Enqueue sync operations
        await widget.syncEngine.enqueueOperation(
          entityType: 'tenant',
          entityId: tenantId,
          operation: 'upsert',
          payload: jsonEncode({
            'id': tenantId,
            'name': schoolName,
            'isActive': true,
            'createdAt': now.toIso8601String(),
          }),
        );

        await widget.syncEngine.enqueueOperation(
          entityType: 'tenant_license',
          entityId: licenseId,
          operation: 'upsert',
          payload: jsonEncode({
            'id': licenseId,
            'tenantId': tenantId,
            'schoolOwnerEmail': ownerEmail,
            'planCode': planCode,
            'seatLimit': seatLimit,
            'isActive': true,
            'issuedAt': now.toIso8601String(),
            'expiresAt': expiresAt.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          }),
        );

        await widget.syncEngine.enqueueOperation(
          entityType: 'school_owner',
          entityId: ownerId,
          operation: 'upsert',
          payload: jsonEncode({
            'id': ownerId,
            'tenantId': tenantId,
            'fullName': schoolName,
            'email': ownerEmail,
            'isPrimary': true,
            'isActive': true,
            'provisioningStatus': 'pending',
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          }),
        );
      });

      // Success - show confirmation and navigate back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tenant "$schoolName" created successfully and queued for sync.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (error) {
      // Transaction rolled back automatically
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to create tenant: $error';
          _isSaving = false;
        });
      }
    }
  }
}
