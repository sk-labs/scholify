import 'dart:convert';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

class LiveClassRepository {
  LiveClassRepository({
    required this.database,
    required this.syncEngine,
    required this.tenantContext,
  });

  final AppLocalDatabase database;
  final SyncEngine syncEngine;
  final TenantContext tenantContext;

  static const String zoomProvider = 'zoom';
  static const String gmeetProvider = 'gmeet';

  Stream<List<LiveClassEntry>> watchZoomClasses({
    bool includeInactive = false,
  }) {
    return database.watchLiveClasses(
      tenantId: _resolveTenantId(),
      providerType: zoomProvider,
      includeInactive: includeInactive,
    );
  }

  Stream<List<LiveClassEntry>> watchGmeetClasses({
    bool includeInactive = false,
  }) {
    return database.watchLiveClasses(
      tenantId: _resolveTenantId(),
      providerType: gmeetProvider,
      includeInactive: includeInactive,
    );
  }

  Future<void> saveClass({
    String? classId,
    required String providerType,
    required String title,
    String? classSection,
    String? hostName,
    DateTime? startAt,
    DateTime? endAt,
    String? joinUrl,
    String? meetingId,
    String? meetingPassword,
    String statusLabel = 'scheduled',
    bool isActive = true,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();
    final resolvedId =
        classId ?? 'live_${tenantId}_${now.microsecondsSinceEpoch}';

    await database.upsertLiveClassRecord(
      classId: resolvedId,
      tenantId: tenantId,
      providerType: providerType,
      title: title,
      classSection: classSection,
      hostName: hostName,
      startAt: startAt?.toUtc() ?? now,
      endAt: endAt?.toUtc(),
      joinUrl: joinUrl,
      meetingId: meetingId,
      meetingPassword: meetingPassword,
      statusLabel: statusLabel,
      isActive: isActive,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'live_class',
      entityId: resolvedId,
      operation: 'upsert',
      payload: jsonEncode({
        'classId': resolvedId,
        'tenantId': tenantId,
        'providerType': providerType,
        'title': title,
        'classSection': classSection,
        'hostName': hostName,
        'startAt': (startAt?.toUtc() ?? now).toIso8601String(),
        'endAt': endAt?.toUtc().toIso8601String(),
        'joinUrl': joinUrl,
        'meetingId': meetingId,
        'meetingPassword': meetingPassword,
        'statusLabel': statusLabel,
        'isActive': isActive,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> deleteClass(LiveClassEntry entry) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();

    await database.deleteLiveClassRecord(tenantId: tenantId, classId: entry.id);

    await syncEngine.enqueueOperation(
      entityType: 'live_class',
      entityId: entry.id,
      operation: 'delete',
      payload: jsonEncode({
        'classId': entry.id,
        'tenantId': tenantId,
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  String _resolveTenantId() {
    if (tenantContext.tenantId != null && tenantContext.tenantId!.isNotEmpty) {
      return tenantContext.tenantId!;
    }
    return 'school_demo';
  }
}
