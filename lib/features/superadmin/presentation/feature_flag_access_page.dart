import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/access/module_access_policy.dart';
import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

class FeatureFlagAccessPage extends StatefulWidget {
  const FeatureFlagAccessPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<FeatureFlagAccessPage> createState() => _FeatureFlagAccessPageState();
}

class _FeatureFlagAccessPageState extends State<FeatureFlagAccessPage> {
  String? _selectedTenantId;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Feature Flags & Access Control')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<TenantLicenseView>>(
          stream: widget.syncEngine.database.watchTenantLicenseViews(),
          builder: (context, licenseSnapshot) {
            if (licenseSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (licenseSnapshot.hasError) {
              return Center(
                child: Text(
                  'Failed to load tenant licenses: ${licenseSnapshot.error}',
                ),
              );
            }

            final licenses =
                licenseSnapshot.data ?? const <TenantLicenseView>[];
            if (licenses.isEmpty) {
              return const Center(
                child: Text(
                  'No tenant licenses found. Create a license first.',
                ),
              );
            }

            final selectedTenantId = _resolveTenant(licenses);
            final selectedLicense = licenses.firstWhere(
              (license) => license.tenantId == selectedTenantId,
              orElse: () => licenses.first,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 360,
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedTenantId,
                        decoration: const InputDecoration(
                          labelText: 'Tenant',
                          border: OutlineInputBorder(),
                        ),
                        items: licenses
                            .map(
                              (license) => DropdownMenuItem<String>(
                                value: license.tenantId,
                                child: Text(
                                  '${license.tenantName} (${license.planCode.toUpperCase()})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedTenantId = value;
                          });
                        },
                      ),
                    ),
                    Chip(
                      label: Text(
                        'Plan: ${selectedLicense.planCode.toUpperCase()} | Seats: ${selectedLicense.seatLimit}',
                      ),
                    ),
                    Chip(
                      label: Text(
                        selectedLicense.isActive ? 'ACTIVE' : 'SUSPENDED',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<List<TenantFeatureFlagEntry>>(
                    stream: widget.syncEngine.database.watchTenantFeatureFlags(
                      tenantId: selectedTenantId,
                    ),
                    builder: (context, flagSnapshot) {
                      if (flagSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (flagSnapshot.hasError) {
                        return Center(
                          child: Text(
                            'Failed to load feature flags: ${flagSnapshot.error}',
                          ),
                        );
                      }

                      final rows =
                          flagSnapshot.data ?? const <TenantFeatureFlagEntry>[];
                      final explicitMap = <String, TenantFeatureFlagEntry>{
                        for (final row in rows) row.featureKey: row,
                      };
                      final defaults = ModuleAccessPolicy.defaultsForPlan(
                        selectedLicense.planCode,
                      );

                      return ListView(
                        children: [
                          const Text(
                            'Toggle modules per tenant. If disabled by plan defaults, enabling here grants explicit access.',
                          ),
                          const SizedBox(height: 12),
                          for (final featureKey in ScholifyModuleFeature.all)
                            Card(
                              child: SwitchListTile.adaptive(
                                value:
                                    explicitMap[featureKey]?.isEnabled ??
                                    (defaults[featureKey] ?? false),
                                onChanged: _isSaving
                                    ? null
                                    : (value) => _setFeatureFlag(
                                        tenantId: selectedTenantId,
                                        featureKey: featureKey,
                                        isEnabled: value,
                                      ),
                                title: Text(_labelForFeature(featureKey)),
                                subtitle: Text(
                                  _subtitleForFeature(
                                    featureKey: featureKey,
                                    defaultEnabled:
                                        defaults[featureKey] ?? false,
                                    explicit: explicitMap[featureKey],
                                    dateFormat: dateFormat,
                                  ),
                                ),
                              ),
                            ),
                        ],
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
  }

  String _resolveTenant(List<TenantLicenseView> licenses) {
    final selectedTenantId = _selectedTenantId;
    if (selectedTenantId != null &&
        licenses.any((license) => license.tenantId == selectedTenantId)) {
      return selectedTenantId;
    }

    final fallback = licenses.first.tenantId;
    if (selectedTenantId != fallback) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedTenantId = fallback;
        });
      });
    }

    return fallback;
  }

  Future<void> _setFeatureFlag({
    required String tenantId,
    required String featureKey,
    required bool isEnabled,
  }) async {
    final now = DateTime.now().toUtc();
    final flagId = 'ff_${tenantId}_$featureKey';

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.syncEngine.database.upsertTenantFeatureFlagRecord(
        flagId: flagId,
        tenantId: tenantId,
        featureKey: featureKey,
        isEnabled: isEnabled,
        source: 'local',
        updatedAt: now,
      );

      await widget.syncEngine.enqueueOperation(
        entityType: 'tenant_feature_flag',
        entityId: flagId,
        operation: 'upsert',
        payload: jsonEncode({
          'flagId': flagId,
          'tenantId': tenantId,
          'featureKey': featureKey,
          'isEnabled': isEnabled,
          'source': 'local',
          'updatedAt': now.toIso8601String(),
        }),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_labelForFeature(featureKey)} ${isEnabled ? 'enabled' : 'disabled'} for tenant.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update feature flag: $error')),
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

  String _labelForFeature(String key) {
    switch (key) {
      case ScholifyModuleFeature.students:
        return 'Students';
      case ScholifyModuleFeature.guardians:
        return 'Guardians';
      case ScholifyModuleFeature.enrollment:
        return 'Enrollment';
      case ScholifyModuleFeature.classRoll:
        return 'Class Roll';
      case ScholifyModuleFeature.leaveRequests:
        return 'Leave Requests';
      case ScholifyModuleFeature.pendingTasks:
        return 'Pending Tasks';
      case ScholifyModuleFeature.hostel:
        return 'Hostel';
      case ScholifyModuleFeature.fees:
        return 'Fees';
      case ScholifyModuleFeature.attendance:
        return 'Attendance';
      case ScholifyModuleFeature.exams:
        return 'Exams';
      case ScholifyModuleFeature.notices:
        return 'Notices';
      case ScholifyModuleFeature.timetable:
        return 'Timetable';
      case ScholifyModuleFeature.transport:
        return 'Transport';
      case ScholifyModuleFeature.homework:
        return 'Homework';
      case ScholifyModuleFeature.onlineLearning:
        return 'Online Learning';
      case ScholifyModuleFeature.curriculum:
        return 'Curriculum';
      case ScholifyModuleFeature.library:
        return 'Library';
      case ScholifyModuleFeature.documentCenter:
        return 'Document Center';
      case ScholifyModuleFeature.visitorCommunication:
        return 'Visitor & Communication';
      case ScholifyModuleFeature.notifications:
        return 'Notifications';
      case ScholifyModuleFeature.liveClasses:
        return 'Live Classes';
      default:
        return key;
    }
  }

  String _subtitleForFeature({
    required String featureKey,
    required bool defaultEnabled,
    required TenantFeatureFlagEntry? explicit,
    required DateFormat dateFormat,
  }) {
    final defaultText = defaultEnabled
        ? 'Default by plan: Enabled'
        : 'Default by plan: Disabled';
    if (explicit == null) {
      return '$defaultText | No explicit override';
    }

    return '$defaultText | Override: ${explicit.isEnabled ? 'Enabled' : 'Disabled'} | Updated: ${dateFormat.format(explicit.updatedAt.toLocal())}';
  }
}
