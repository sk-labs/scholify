import 'dart:convert';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

class OnlineLessonRepository {
  OnlineLessonRepository({
    required this.database,
    required this.syncEngine,
    required this.tenantContext,
  });

  final AppLocalDatabase database;
  final SyncEngine syncEngine;
  final TenantContext tenantContext;

  Stream<List<OnlineLessonEntry>> watchLessons({required String itemId}) {
    return database.watchCourseLessons(tenantId: _tid(), itemId: itemId);
  }

  Future<void> saveLesson({
    String? lessonId,
    required String itemId,
    required String title,
    String contentType = 'video',
    String? contentUrl,
    String? description,
    int sortOrder = 0,
    int durationSeconds = 0,
  }) async {
    final tenantId = _tid();
    final now = DateTime.now().toUtc();
    final resolvedId =
        lessonId ?? 'ol_${itemId}_${now.millisecondsSinceEpoch}';

    await database.upsertOnlineLessonRecord(
      lessonId: resolvedId,
      tenantId: tenantId,
      itemId: itemId,
      title: title,
      contentType: contentType,
      contentUrl: contentUrl,
      description: description,
      sortOrder: sortOrder,
      durationSeconds: durationSeconds,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'online_lesson',
      entityId: resolvedId,
      operation: 'upsert',
      payload: jsonEncode({
        'lessonId': resolvedId,
        'tenantId': tenantId,
        'itemId': itemId,
        'title': title,
        'contentType': contentType,
        'contentUrl': contentUrl,
        'description': description,
        'sortOrder': sortOrder,
        'durationSeconds': durationSeconds,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> markCompleted(OnlineLessonEntry lesson) async {
    final tenantId = _tid();
    final now = DateTime.now().toUtc();

    await database.upsertOnlineLessonRecord(
      lessonId: lesson.id,
      tenantId: tenantId,
      itemId: lesson.itemId,
      title: lesson.title,
      contentType: lesson.contentType,
      contentUrl: lesson.contentUrl,
      description: lesson.description,
      sortOrder: lesson.sortOrder,
      durationSeconds: lesson.durationSeconds,
      isCompleted: true,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'online_lesson',
      entityId: lesson.id,
      operation: 'upsert',
      payload: jsonEncode({
        'lessonId': lesson.id,
        'tenantId': tenantId,
        'itemId': lesson.itemId,
        'title': lesson.title,
        'isCompleted': true,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> deleteLesson(OnlineLessonEntry lesson) async {
    final tenantId = _tid();
    final now = DateTime.now().toUtc();

    await database.deleteOnlineLessonRecord(
      tenantId: tenantId,
      lessonId: lesson.id,
    );

    await syncEngine.enqueueOperation(
      entityType: 'online_lesson',
      entityId: lesson.id,
      operation: 'delete',
      payload: jsonEncode({
        'lessonId': lesson.id,
        'tenantId': tenantId,
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  String _tid() {
    final id = tenantContext.tenantId;
    return (id != null && id.isNotEmpty) ? id : 'school_demo';
  }
}
