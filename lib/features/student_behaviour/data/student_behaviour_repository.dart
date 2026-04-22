import 'dart:convert';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

class StudentBehaviourRepository {
  StudentBehaviourRepository({
    required this.database,
    required this.syncEngine,
    required this.tenantContext,
  });

  final AppLocalDatabase database;
  final SyncEngine syncEngine;
  final TenantContext tenantContext;

  Stream<List<StudentBehaviourEntry>> watchBehaviour({
    required String studentId,
  }) {
    return database.watchStudentBehaviour(
      tenantId: _tid(),
      studentId: studentId,
    );
  }

  Stream<List<BehaviourCommentEntry>> watchComments({
    required String incidentId,
  }) {
    return database.watchBehaviourComments(
      tenantId: _tid(),
      incidentId: incidentId,
    );
  }

  Future<void> addComment({
    required String incidentId,
    required String commentText,
    String? commentedBy,
  }) async {
    final tenantId = _tid();
    final now = DateTime.now().toUtc();
    final commentId = 'bc_${incidentId}_${now.millisecondsSinceEpoch}';

    await database.upsertBehaviourCommentRecord(
      commentId: commentId,
      tenantId: tenantId,
      incidentId: incidentId,
      commentText: commentText,
      commentedBy: commentedBy,
      commentDate: now.toIso8601String(),
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'behaviour_comment',
      entityId: commentId,
      operation: 'upsert',
      payload: jsonEncode({
        'commentId': commentId,
        'tenantId': tenantId,
        'incidentId': incidentId,
        'commentText': commentText,
        'commentedBy': commentedBy,
        'commentDate': now.toIso8601String(),
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> deleteComment(BehaviourCommentEntry comment) async {
    final tenantId = _tid();
    final now = DateTime.now().toUtc();

    await database.deleteBehaviourCommentRecord(
      tenantId: tenantId,
      commentId: comment.id,
    );

    await syncEngine.enqueueOperation(
      entityType: 'behaviour_comment',
      entityId: comment.id,
      operation: 'delete',
      payload: jsonEncode({
        'commentId': comment.id,
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
