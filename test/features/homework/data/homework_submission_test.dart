import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';
import 'package:scholify/features/homework/data/homework_repository.dart';

void main() {
  group('HomeworkRepository – submission lifecycle', () {
    const tenantId = 'tenant_alpha';

    late AppLocalDatabase database;
    late TenantContext tenantContext;
    late SyncEngine syncEngine;
    late HomeworkRepository repository;

    setUp(() {
      database = AppLocalDatabase(executor: NativeDatabase.memory());
      tenantContext = TenantContext()
        ..setTenant(
          tenantId: tenantId,
          tenantName: 'Alpha School',
          role: 'school_owner',
          isSuperAdmin: false,
        );
      syncEngine = SyncEngine(
        database: database,
        pocketbaseGateway: PocketbaseGateway(baseUrl: 'http://127.0.0.1:8090'),
        tenantContext: tenantContext,
      );
      repository = HomeworkRepository(
        database: database,
        syncEngine: syncEngine,
        tenantContext: tenantContext,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('submit, review, and delete a homework submission', () async {
      // Create an assignment first
      await repository.saveAssignment(
        assignmentType: HomeworkRepository.homeworkType,
        title: 'Math Worksheet',
        subjectName: 'Mathematics',
        classSection: '7-A',
        dueDate: DateTime.utc(2026, 8, 10),
      );

      final assignments = await repository
          .watchAssignments(assignmentType: HomeworkRepository.homeworkType)
          .first;
      expect(assignments.length, 1);
      final assignment = assignments.single;

      // Submit homework
      await repository.submitHomework(
        assignmentId: assignment.id,
        studentId: 'student_1',
        submissionText: 'Completed all 10 questions.',
      );

      final submissions = await repository
          .watchSubmissions(assignmentId: assignment.id)
          .first;
      expect(submissions.length, 1);
      expect(submissions.single.statusLabel, 'submitted');
      expect(submissions.single.studentId, 'student_1');
      expect(submissions.single.submissionText, 'Completed all 10 questions.');

      // Review submission
      await repository.reviewSubmission(
        submission: submissions.single,
        statusLabel: 'graded',
        teacherFeedback: 'Good work!',
        gradeScore: 9.5,
      );

      final reviewed = await repository
          .watchSubmissions(assignmentId: assignment.id)
          .first;
      expect(reviewed.single.statusLabel, 'graded');
      expect(reviewed.single.teacherFeedback, 'Good work!');
      expect(reviewed.single.gradeScore, 9.5);

      // Delete submission
      await repository.deleteSubmission(reviewed.single);

      final afterDelete = await repository
          .watchSubmissions(assignmentId: assignment.id)
          .first;
      expect(afterDelete, isEmpty);

      // Verify sync queue has all operations
      final queue = await database.getSyncQueueDispatchBatch(
        limit: 50,
        tenantId: tenantId,
      );
      final submissionOps = queue
          .where((e) => e.entityType == 'homework_submission')
          .toList();
      expect(submissionOps.length, 3); // submit, review, delete
      expect(
        submissionOps.where((e) => e.operation == 'upsert').length,
        2,
      );
      expect(
        submissionOps.where((e) => e.operation == 'delete').length,
        1,
      );
    });
  });
}
