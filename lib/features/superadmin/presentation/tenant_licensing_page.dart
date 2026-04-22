import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

class TenantLicensingPage extends StatefulWidget {
  const TenantLicensingPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<TenantLicensingPage> createState() => _TenantLicensingPageState();
}

class _TenantLicensingPageState extends State<TenantLicensingPage> {
  final _formKey = GlobalKey<FormState>();
  final _schoolNameController = TextEditingController();
  final _ownerEmailController = TextEditingController();
  final _seatLimitController = TextEditingController(text: '250');

  String _selectedPlan = 'professional';
  bool _isSaving = false;

  static const List<String> _plans = ['starter', 'professional', 'enterprise'];

  @override
  void dispose() {
    _schoolNameController.dispose();
    _ownerEmailController.dispose();
    _seatLimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Tenant Licensing')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildCreateLicenseCard(),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<TenantLicenseView>>(
                stream: widget.syncEngine.database.watchTenantLicenseViews(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Failed to load licenses: ${snapshot.error}'),
                    );
                  }

                  final licenses = snapshot.data ?? const [];
                  if (licenses.isEmpty) {
                    return const Center(
                      child: Text('No tenant licenses created yet.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: licenses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = licenses[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.tenantName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      item.isActive ? 'Active' : 'Suspended',
                                    ),
                                    backgroundColor: item.isActive
                                        ? Colors.green.shade100
                                        : Colors.red.shade100,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('Tenant ID: ${item.tenantId}'),
                              Text('Owner: ${item.schoolOwnerEmail}'),
                              Text(
                                'Plan: ${item.planCode.toUpperCase()} | Seats: ${item.seatLimit}',
                              ),
                              Text(
                                'Issued: ${dateFormat.format(item.issuedAt.toLocal())}',
                              ),
                              if (item.expiresAt != null)
                                Text(
                                  'Expires: ${dateFormat.format(item.expiresAt!.toLocal())}',
                                ),
                              Text(
                                'Updated: ${dateFormat.format(item.updatedAt.toLocal())}',
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: item.isActive
                                        ? null
                                        : () => _setLicenseStatus(item, true),
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('Activate'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: item.isActive
                                        ? () => _setLicenseStatus(item, false)
                                        : null,
                                    icon: const Icon(Icons.pause),
                                    label: const Text('Suspend'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () {
                                      widget.tenantContext.setTenant(
                                        tenantId: item.tenantId,
                                        tenantName: item.tenantName,
                                        role: 'school_owner',
                                        isSuperAdmin: true,
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Tenant context switched to ${item.tenantName}.',
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.switch_account),
                                    label: const Text('Set Context'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateLicenseCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create or Update School License',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _schoolNameController,
                decoration: const InputDecoration(
                  labelText: 'School Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'School name is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ownerEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Owner Email',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) {
                    return 'Owner email is required.';
                  }
                  if (!text.contains('@')) {
                    return 'Enter a valid email.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
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
                        if (value == null) return;
                        setState(() {
                          _selectedPlan = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _seatLimitController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Seat Limit',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final parsed = int.tryParse(value?.trim() ?? '');
                        if (parsed == null || parsed <= 0) {
                          return 'Enter a valid seat limit.';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _createOrUpdateLicense,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_user),
                label: Text(_isSaving ? 'Saving...' : 'Save License'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createOrUpdateLicense() async {
    if (!_formKey.currentState!.validate()) return;

    final schoolName = _schoolNameController.text.trim();
    final ownerEmail = _ownerEmailController.text.trim().toLowerCase();
    final seatLimit = int.parse(_seatLimitController.text.trim());
    final tenantId = _buildTenantId(schoolName);

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.syncEngine.database.createOrUpdateTenantLicense(
        tenantId: tenantId,
        tenantName: schoolName,
        schoolOwnerEmail: ownerEmail,
        planCode: _selectedPlan,
        seatLimit: seatLimit,
        expiresAt: DateTime.now().add(const Duration(days: 365)),
      );

      await widget.syncEngine.enqueueOperation(
        entityType: 'tenant_license',
        entityId: 'lic_$tenantId',
        operation: 'upsert',
        payload: jsonEncode({
          'tenantId': tenantId,
          'tenantName': schoolName,
          'ownerEmail': ownerEmail,
          'planCode': _selectedPlan,
          'seatLimit': seatLimit,
          'updatedAt': DateTime.now().toIso8601String(),
        }),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tenant license saved and queued for sync.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save license: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _setLicenseStatus(TenantLicenseView item, bool isActive) async {
    try {
      await widget.syncEngine.database.setTenantLicenseStatus(
        licenseId: item.licenseId,
        tenantId: item.tenantId,
        isActive: isActive,
      );

      await widget.syncEngine.enqueueOperation(
        entityType: 'tenant_license',
        entityId: item.licenseId,
        operation: 'status_update',
        payload: jsonEncode({
          'tenantId': item.tenantId,
          'isActive': isActive,
          'updatedAt': DateTime.now().toIso8601String(),
        }),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isActive ? 'License activated.' : 'License suspended.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $error')),
        );
      }
    }
  }

  String _buildTenantId(String schoolName) {
    final normalized = schoolName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    if (normalized.isEmpty) {
      return 'school_${DateTime.now().millisecondsSinceEpoch}';
    }

    return normalized;
  }
}
