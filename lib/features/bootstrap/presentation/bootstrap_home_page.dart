import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/constants/branding.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../../sync/presentation/sync_failure_page.dart';
import '../../plan_upgrade/presentation/plan_upgrade_page.dart';
import '../../branding/presentation/branding_settings_page.dart';

class BootstrapHomePage extends StatelessWidget {
  const BootstrapHomePage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
    this.onSignOut,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([tenantContext, syncEngine]),
      builder: (context, _) {
        final tenantLabel = tenantContext.hasTenant
            ? '${tenantContext.tenantName} (${tenantContext.role})'
            : 'No active tenant selected';

        final syncState = syncEngine.isSyncing
            ? 'Sync in progress'
            : syncEngine.isBackgroundSyncEnabled
            ? 'Background sync running'
            : 'Background sync stopped';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Scholify Foundation'),
            actions: [
              // Warning icon for sync failures (A2.7)
              StreamBuilder<List<dynamic>>(
                stream: syncEngine.database.watchFailedSyncEntries(),
                builder: (context, snapshot) {
                  final failedCount = snapshot.data?.length ?? 0;
                  
                  // Only show icon when there are failures
                  if (failedCount == 0) {
                    return const SizedBox.shrink();
                  }
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: IconButton(
                      icon: Badge(
                        label: Text('$failedCount'),
                        backgroundColor: Colors.red,
                        textColor: Colors.white,
                        child: const Icon(Icons.warning_amber_rounded),
                      ),
                      tooltip: 'Sync Failures ($failedCount)',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SyncFailurePage(),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                _StatusCard(
                  title: 'Product',
                  value: '${AppBranding.appName} (Desktop-first + Web)',
                ),
                _StatusCard(title: 'Tenant Context', value: tenantLabel),
                _StatusCard(title: 'Sync State', value: syncState),
                _StatusCard(
                  title: 'Pending Sync Jobs',
                  value: '${syncEngine.pendingJobs}',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        tenantContext.setTenant(
                          tenantId: 'school_demo',
                          tenantName: 'Demo School',
                          role: 'superadmin',
                          isSuperAdmin: true,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Demo tenant applied.')),
                        );
                      },
                      icon: const Icon(Icons.business),
                      label: const Text('Set Demo Tenant'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await syncEngine.enqueueOperation(
                          entityType: 'tenant_license',
                          entityId: DateTime.now().millisecondsSinceEpoch
                              .toString(),
                          operation: 'upsert',
                          payload: jsonEncode({
                            'tenantId': tenantContext.tenantId ?? 'school_demo',
                            'plan': 'professional',
                            'updatedAt': DateTime.now().toIso8601String(),
                          }),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Demo sync operation queued.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.playlist_add),
                      label: const Text('Queue Demo Job'),
                    ),
                    ElevatedButton.icon(
                      onPressed: syncEngine.isBackgroundSyncEnabled
                          ? syncEngine.stopBackgroundSync
                          : syncEngine.startBackgroundSync,
                      icon: Icon(
                        syncEngine.isBackgroundSyncEnabled
                            ? Icons.pause_circle
                            : Icons.play_circle,
                      ),
                      label: Text(
                        syncEngine.isBackgroundSyncEnabled
                            ? 'Stop Background Sync'
                            : 'Start Background Sync',
                      ),
                    ),
                    if (!tenantContext.isSuperAdmin) ...[
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PlanUpgradePage(
                                tenantContext: tenantContext,
                                syncEngine: syncEngine,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.upgrade),
                        label: const Text('Request Plan Upgrade'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => BrandingSettingsPage(
                                tenantContext: tenantContext,
                                syncEngine: syncEngine,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.palette),
                        label: const Text('Branding Settings'),
                      ),
                    ],
                    OutlinedButton.icon(
                      onPressed: syncEngine.manualSync,
                      icon: const Icon(Icons.sync),
                      label: const Text('Run Manual Sync'),
                    ),
                    if (onSignOut != null)
                      OutlinedButton.icon(
                        onPressed: () async {
                          await onSignOut!.call();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Signed out from this device.'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign Out'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(title: Text(title), subtitle: Text(value)),
    );
  }
}
