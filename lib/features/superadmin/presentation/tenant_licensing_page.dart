import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/local_database.dart';
import '../../../core/services/audit_log_service.dart';
import '../../../core/services/csv_export_service.dart';
import '../../../core/services/impersonation_service.dart';
import '../../../core/services/license_alert_service.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../../tenant_detail/presentation/tenant_detail_page.dart';

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
  final _searchController = TextEditingController();

  String _selectedPlan = 'professional';
  bool _isSaving = false;
  String _searchQuery = '';
  Timer? _debounceTimer;
  String? _planFilter; // null = all, 'starter', 'professional', 'enterprise'
  bool? _activeFilter; // null = all, true = active, false = suspended
  
  late final LicenseAlertService _licenseAlertService;
  late final ImpersonationService _impersonationService;
  Map<String, AlertTier> _alertTiers = {};

  static const List<String> _plans = ['starter', 'professional', 'enterprise'];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _licenseAlertService = LicenseAlertService(
      database: widget.syncEngine.database,
    );
    _impersonationService = ImpersonationService(
      tenantContext: widget.tenantContext,
      auditLogService: AuditLogService(
        database: widget.syncEngine.database,
        tenantContext: widget.tenantContext,
        gateway: widget.syncEngine.pocketbaseGateway,
      ),
    );
    
    // Watch alerts and build a map of tenantId -> AlertTier
    _licenseAlertService.watchAlerts().listen((alerts) {
      if (mounted) {
        setState(() {
          _alertTiers = {
            for (final alert in alerts) alert.tenantId: alert.tier,
          };
        });
      }
    });
  }

  @override
  void dispose() {
    _schoolNameController.dispose();
    _ownerEmailController.dispose();
    _seatLimitController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  List<TenantLicenseView> _applyFilters(List<TenantLicenseView> tenants) {
    var filtered = tenants;

    // Apply search query filter
    if (_searchQuery.isNotEmpty) {
      final lowerQuery = _searchQuery.toLowerCase();
      filtered = filtered
          .where((t) => t.tenantName.toLowerCase().contains(lowerQuery))
          .toList();
    }

    // Apply plan filter
    if (_planFilter != null) {
      filtered =
          filtered.where((t) => t.planCode == _planFilter).toList();
    }

    // Apply active status filter
    if (_activeFilter != null) {
      filtered =
          filtered.where((t) => t.isActive == _activeFilter).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenant Licensing'),
        actions: [
          // Q2.1: Export CSV button visible only to Superadmin
          if (widget.tenantContext.isSuperAdmin)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Export to CSV',
              onPressed: _handleExportCsv,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildCreateLicenseCard(),
            const SizedBox(height: 16),
            _buildSearchField(),
            const SizedBox(height: 12),
            _buildFilterChips(),
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

                  final allLicenses = snapshot.data ?? const [];
                  final licenses = _applyFilters(allLicenses);

                  if (allLicenses.isEmpty) {
                    return const Center(
                      child: Text('No tenant licenses created yet.'),
                    );
                  }

                  if (licenses.isEmpty) {
                    return const Center(
                      child: Text('No tenants match the current filters.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: licenses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = licenses[index];
                      final alertTier = _alertTiers[item.tenantId];
                      
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
                                  // Display expired status (H4.5)
                                  if (alertTier == AlertTier.expired)
                                    Chip(
                                      label: const Text('Expired'),
                                      backgroundColor: Colors.red.shade700,
                                      labelStyle: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  else
                                    Chip(
                                      label: Text(
                                        item.isActive ? 'Active' : 'Suspended',
                                      ),
                                      backgroundColor: item.isActive
                                          ? Colors.green.shade100
                                          : Colors.red.shade100,
                                    ),
                                  // Display warning badge for 30-day alerts (H4.2)
                                  if (alertTier == AlertTier.warning30) ...[
                                    const SizedBox(width: 8),
                                    Chip(
                                      avatar: const Icon(
                                        Icons.warning_amber,
                                        size: 18,
                                        color: Colors.orange,
                                      ),
                                      label: const Text('Expiring Soon'),
                                      backgroundColor: Colors.orange.shade100,
                                    ),
                                  ],
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
                                  style: TextStyle(
                                    color: alertTier == AlertTier.expired
                                        ? Colors.red.shade700
                                        : null,
                                    fontWeight: alertTier == AlertTier.expired
                                        ? FontWeight.bold
                                        : null,
                                  ),
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
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => TenantDetailPage(
                                            tenantId: item.tenantId,
                                            syncEngine: widget.syncEngine,
                                            impersonationService:
                                                _impersonationService,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.visibility),
                                    label: const Text('Details'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _handleImpersonate(item),
                                    icon: const Icon(Icons.person_search),
                                    label: const Text('Impersonate'),
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

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        labelText: 'Search by school name',
        hintText: 'Type to filter tenants...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                },
              )
            : null,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Plan filter chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            const Text(
              'Plan:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            FilterChip(
              label: const Text('All'),
              selected: _planFilter == null,
              onSelected: (selected) {
                setState(() {
                  _planFilter = null;
                });
              },
            ),
            FilterChip(
              label: const Text('Starter'),
              selected: _planFilter == 'starter',
              onSelected: (selected) {
                setState(() {
                  _planFilter = selected ? 'starter' : null;
                });
              },
            ),
            FilterChip(
              label: const Text('Professional'),
              selected: _planFilter == 'professional',
              onSelected: (selected) {
                setState(() {
                  _planFilter = selected ? 'professional' : null;
                });
              },
            ),
            FilterChip(
              label: const Text('Enterprise'),
              selected: _planFilter == 'enterprise',
              onSelected: (selected) {
                setState(() {
                  _planFilter = selected ? 'enterprise' : null;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Status filter chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            const Text(
              'Status:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            FilterChip(
              label: const Text('All'),
              selected: _activeFilter == null,
              onSelected: (selected) {
                setState(() {
                  _activeFilter = null;
                });
              },
            ),
            FilterChip(
              label: const Text('Active'),
              selected: _activeFilter == true,
              onSelected: (selected) {
                setState(() {
                  _activeFilter = selected ? true : null;
                });
              },
            ),
            FilterChip(
              label: const Text('Suspended'),
              selected: _activeFilter == false,
              onSelected: (selected) {
                setState(() {
                  _activeFilter = selected ? false : null;
                });
              },
            ),
          ],
        ),
      ],
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

  /// Q3: Impersonate a tenant directly from the licensing list
  Future<void> _handleImpersonate(TenantLicenseView item) async {
    try {
      await _impersonationService.startImpersonation(
        item.tenantId,
        item.tenantName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Now impersonating ${item.tenantName}'),
            backgroundColor: Colors.blue,
          ),
        );
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

  /// Q2: Export tenant list to CSV
  Future<void> _handleExportCsv() async {
    try {
      // Fetch all tenants from TenantUsageBillingView (Q2.2)
      final tenants = await widget.syncEngine.database
          .watchTenantUsageBillingViews()
          .first;

      // Create CSV export service
      final csvService = CSVExportService(
        database: widget.syncEngine.database,
      );

      // Generate CSV content (Q2.2, Q2.3, Q2.5, Q2.6)
      final csvContent = await csvService.exportTenantList(tenants);

      // Save CSV file (Q2.4)
      // Note: This will show a placeholder message since platform-specific
      // file save is not yet implemented
      try {
        await csvService.saveCsvFile(csvContent);
      } catch (e) {
        // Show CSV content in a dialog as fallback
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('CSV Export'),
              content: SingleChildScrollView(
                child: SelectableText(csvContent),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${tenants.length} tenants to CSV'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
