import 'dart:convert';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

class HostelRepository {
  HostelRepository({
    required this.database,
    required this.syncEngine,
    required this.tenantContext,
  });

  final AppLocalDatabase database;
  final SyncEngine syncEngine;
  final TenantContext tenantContext;

  Stream<List<HostelRoomEntry>> watchHostelRooms({
    bool includeInactive = false,
  }) {
    return database.watchHostelRooms(
      tenantId: _resolveTenantId(),
      includeInactive: includeInactive,
    );
  }

  Future<void> saveRoom({
    String? roomId,
    String? studentId,
    String? hostelName,
    String? roomNo,
    String? roomType,
    String? floorNo,
    String? bedNo,
    String? wardenName,
    String? wardenContact,
    double monthlyFees = 0,
    bool isActive = true,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();
    final resolvedId =
        roomId ?? 'hostel_${tenantId}_${now.microsecondsSinceEpoch}';

    await database.upsertHostelRoomRecord(
      roomId: resolvedId,
      tenantId: tenantId,
      studentId: studentId,
      hostelName: hostelName,
      roomNo: roomNo,
      roomType: roomType,
      floorNo: floorNo,
      bedNo: bedNo,
      wardenName: wardenName,
      wardenContact: wardenContact,
      monthlyFees: monthlyFees,
      isActive: isActive,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'hostel_room',
      entityId: resolvedId,
      operation: 'upsert',
      payload: jsonEncode({
        'roomId': resolvedId,
        'tenantId': tenantId,
        'studentId': studentId,
        'hostelName': hostelName,
        'roomNo': roomNo,
        'roomType': roomType,
        'floorNo': floorNo,
        'bedNo': bedNo,
        'wardenName': wardenName,
        'wardenContact': wardenContact,
        'monthlyFees': monthlyFees,
        'isActive': isActive,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> deleteRoom(HostelRoomEntry entry) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();

    await database.deleteHostelRoomRecord(tenantId: tenantId, roomId: entry.id);

    await syncEngine.enqueueOperation(
      entityType: 'hostel_room',
      entityId: entry.id,
      operation: 'delete',
      payload: jsonEncode({
        'roomId': entry.id,
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
