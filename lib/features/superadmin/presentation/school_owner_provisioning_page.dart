import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

class SchoolOwnerProvisioningPage extends StatefulWidget {
  const SchoolOwnerProvisioningPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<SchoolOwnerProvisioningPage> createState() =>
      _SchoolOwnerProvisioningPageState();
}

class _SchoolOwnerProvisioningPageState
    extends State<SchoolOwnerProvisioningPage> {
  final _formKey = GlobalKey<FormState>();
  final _ownerNameController = TextEditingController();
  final _ownerEmailController = TextEditingController();
  final _ownerPhoneController = TextEditingController();

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy, HH:mm');

  StreamSubscription<List<TenantLicenseView>>? _tenantSubscription;
  List<TenantLicenseView> _tenantOptions = const [];
  String? _selectedTenantId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tenantSubscription = widget.syncEngine.database
        .watchTenantLicenseViews()
        .listen((licenses) {
          if (!mounted) return;

          final activeTenants = licenses.where((l) => l.isActive).toList();
          setState(() {
            _tenantOptions = activeTenants;
            final stillValid =
                _selectedTenantId != null &&
                _tenantOptions.any((t) => t.tenantId == _selectedTenantId);
            if (!stillValid) {
              _selectedTenantId = _tenantOptions.isNotEmpty
                  ? _tenantOptions.first.tenantId
                  : null;
            }
          });
        });
  }

  @override
  void dispose() {
    _tenantSubscription?.cancel();
    _ownerNameController.dispose();
    _ownerEmailController.dispose();
    _ownerPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('School Owner Provisioning')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProvisioningCard(),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<SchoolOwnerView>>(
                stream: widget.syncEngine.database.watchSchoolOwnerViews(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Failed to load owners: ${snapshot.error}'),
                    );
                  }

                  final owners = snapshot.data ?? const [];
                  if (owners.isEmpty) {
                    return const Center(
                      child: Text('No school owners provisioned yet.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: owners.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final owner = owners[index];
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
                                      owner.fullName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      owner.isActive ? 'Active' : 'Suspended',
                                    ),
                                    backgroundColor: owner.isActive
                                        ? Colors.green.shade100
                                        : Colors.red.shade100,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('Tenant: ${owner.tenantName}'),
                              Text('Email: ${owner.email}'),
                              Text('Phone: ${owner.phone ?? '-'}'),
                              Text(
                                'Role: ${owner.isPrimary ? 'Primary Owner' : 'Secondary Owner'}',
                              ),
                              Text('Status: ${owner.provisioningStatus}'),
                              Text(
                                'Updated: ${_dateFormat.format(owner.updatedAt.toLocal())}',
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: owner.isActive
                                        ? null
                                        : () => _setOwnerStatus(owner, true),
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('Activate'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: owner.isActive
                                        ? () => _setOwnerStatus(owner, false)
                                        : null,
                                    icon: const Icon(Icons.pause),
                                    label: const Text('Suspend'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () {
                                      widget.tenantContext.setTenant(
                                        tenantId: owner.tenantId,
                                        tenantName: owner.tenantName,
                                        role: 'school_owner',
                                        isSuperAdmin: true,
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Tenant context switched to ${owner.tenantName}.',
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

  Widget _buildProvisioningCard() {
    final hasTenants = _tenantOptions.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Provision School Owner',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (!hasTenants)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(
                    'No active tenant license found. Create a tenant license first.',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              DropdownButtonFormField<String>(
                initialValue: _selectedTenantId,
                decoration: const InputDecoration(
                  labelText: 'Tenant',
                  border: OutlineInputBorder(),
                ),
                items: _tenantOptions
                    .map(
                      (tenant) => DropdownMenuItem<String>(
                        value: tenant.tenantId,
                        child: Text(
                          '${tenant.tenantName} (${tenant.planCode})',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: hasTenants
                    ? (value) {
                        setState(() {
                          _selectedTenantId = value;
                        });
                      }
                    : null,
                validator: (_) {
                  if (_selectedTenantId == null || _selectedTenantId!.isEmpty) {
                    return 'Select a tenant.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ownerNameController,
                decoration: const InputDecoration(
                  labelText: 'Owner Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Owner name is required.';
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
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) {
                    return 'Owner email is required.';
                  }
                  if (!email.contains('@')) {
                    return 'Enter a valid email.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ownerPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Owner Phone (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _isSaving || !hasTenants ? null : _provisionOwner,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add_alt_1),
                label: Text(_isSaving ? 'Provisioning...' : 'Provision Owner'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _provisionOwner() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTenantId == null) return;

    final tenant = _tenantOptions.firstWhere(
      (item) => item.tenantId == _selectedTenantId,
    );

    final fullName = _ownerNameController.text.trim();
    final email = _ownerEmailController.text.trim().toLowerCase();
    final phone = _ownerPhoneController.text.trim();
    final ownerId = _buildOwnerId(tenant.tenantId, email);

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.syncEngine.database.createOrUpdateSchoolOwner(
        ownerId: ownerId,
        tenantId: tenant.tenantId,
        fullName: fullName,
        email: email,
        phone: phone.isEmpty ? null : phone,
      );

      await widget.syncEngine.enqueueOperation(
        entityType: 'school_owner',
        entityId: ownerId,
        operation: 'upsert',
        payload: jsonEncode({
          'ownerId': ownerId,
          'tenantId': tenant.tenantId,
          'tenantName': tenant.tenantName,
          'fullName': fullName,
          'email': email,
          'phone': phone,
          'updatedAt': DateTime.now().toIso8601String(),
        }),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('School owner provisioned and queued for sync.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Provisioning failed: $error')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _setOwnerStatus(SchoolOwnerView owner, bool isActive) async {
    try {
      await widget.syncEngine.database.setSchoolOwnerStatus(
        ownerId: owner.ownerId,
        isActive: isActive,
      );

      await widget.syncEngine.enqueueOperation(
        entityType: 'school_owner',
        entityId: owner.ownerId,
        operation: 'status_update',
        payload: jsonEncode({
          'ownerId': owner.ownerId,
          'tenantId': owner.tenantId,
          'isActive': isActive,
          'updatedAt': DateTime.now().toIso8601String(),
        }),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isActive ? 'Owner activated.' : 'Owner suspended.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update owner status: $error')),
        );
      }
    }
  }

  String _buildOwnerId(String tenantId, String email) {
    final emailSlug = email
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    if (emailSlug.isEmpty) {
      return 'owner_${tenantId}_${DateTime.now().millisecondsSinceEpoch}';
    }

    return 'owner_${tenantId}_$emailSlug';
  }
}
