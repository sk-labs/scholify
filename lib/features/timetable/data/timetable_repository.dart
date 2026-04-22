import 'dart:convert';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

class TimetableRepository {
  TimetableRepository({
    required this.database,
    required this.syncEngine,
    required this.tenantContext,
  });

  final AppLocalDatabase database;
  final SyncEngine syncEngine;
  final TenantContext tenantContext;

  static const List<String> weekdays = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  Stream<List<TimetableSlotEntry>> watchWeekSlots({
    bool includeInactive = false,
  }) {
    return database.watchTimetableSlots(
      tenantId: _resolveTenantId(),
      includeInactive: includeInactive,
    );
  }

  Stream<List<TimetableSlotEntry>> watchDaySlots(String dayOfWeek) {
    return database.watchTimetableSlots(
      tenantId: _resolveTenantId(),
      dayOfWeek: dayOfWeek,
      includeInactive: false,
    );
  }

  Future<void> saveSlot({
    String? slotId,
    required String dayOfWeek,
    required int periodIndex,
    required String subjectName,
    String? teacherName,
    String? roomNo,
    String? timeFrom,
    String? timeTo,
    String? classSection,
    bool isActive = true,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();
    final resolvedSlotId =
        slotId ??
        'tt_${tenantId}_${dayOfWeek}_${periodIndex}_${now.millisecondsSinceEpoch}';

    await database.upsertTimetableSlotRecord(
      slotId: resolvedSlotId,
      tenantId: tenantId,
      dayOfWeek: dayOfWeek,
      periodIndex: periodIndex,
      subjectName: subjectName,
      teacherName: teacherName,
      roomNo: roomNo,
      timeFrom: timeFrom,
      timeTo: timeTo,
      classSection: classSection,
      isActive: isActive,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'timetable_slot',
      entityId: resolvedSlotId,
      operation: 'upsert',
      payload: jsonEncode({
        'slotId': resolvedSlotId,
        'tenantId': tenantId,
        'dayOfWeek': dayOfWeek,
        'periodIndex': periodIndex,
        'subjectName': subjectName,
        'teacherName': teacherName,
        'roomNo': roomNo,
        'timeFrom': timeFrom,
        'timeTo': timeTo,
        'classSection': classSection,
        'isActive': isActive,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> deleteSlot(TimetableSlotEntry slot) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();

    await database.deleteTimetableSlotRecord(
      tenantId: tenantId,
      slotId: slot.id,
    );

    await syncEngine.enqueueOperation(
      entityType: 'timetable_slot',
      entityId: slot.id,
      operation: 'delete',
      payload: jsonEncode({
        'slotId': slot.id,
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
