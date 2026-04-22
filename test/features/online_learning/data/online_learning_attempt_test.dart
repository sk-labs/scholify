import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';
import 'package:scholify/features/online_learning/data/online_learning_repository.dart';

void main() {
  group('OnlineLearningRepository – attempt lifecycle', () {
    const tenantId = 'tenant_alpha';

    late AppLocalDatabase database;
    late TenantContext tenantContext;
    late SyncEngine syncEngine;
    late OnlineLearningRepository repository;

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
      repository = OnlineLearningRepository(
        database: database,
        syncEngine: syncEngine,
        tenantContext: tenantContext,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('start, complete, and delete an attempt', () async {
      // Create a quiz item
      await repository.saveItem(
        itemType: OnlineLearningRepository.quizType,
        title: 'Science Quiz 1',
        instructorName: 'Dr. Smith',
      );

      final items = await repository
          .watchItems(itemType: OnlineLearningRepository.quizType)
          .first;
      expect(items.length, 1);
      final item = items.single;

      // Start attempt
      await repository.startAttempt(
        itemId: item.id,
        studentId: 'student_1',
      );

      final attempts = await repository
          .watchItemAttempts(itemId: item.id)
          .first;
      expect(attempts.length, 1);
      expect(attempts.single.attemptStatus, 'in_progress');
      expect(attempts.single.isPassed, false);

      // Complete attempt
      await repository.completeAttempt(
        attempt: attempts.single,
        scorePercent: 85.0,
        durationSeconds: 420,
        isPassed: true,
      );

      final completed = await repository
          .watchItemAttempts(itemId: item.id)
          .first;
      expect(completed.single.attemptStatus, 'completed');
      expect(completed.single.scorePercent, 85.0);
      expect(completed.single.durationSeconds, 420);
      expect(completed.single.isPassed, true);

      // Delete attempt
      await repository.deleteAttempt(completed.single);

      final afterDelete = await repository
          .watchItemAttempts(itemId: item.id)
          .first;
      expect(afterDelete, isEmpty);

      // Verify sync queue
      final queue = await database.getSyncQueueDispatchBatch(
        limit: 50,
        tenantId: tenantId,
      );
      final attemptOps = queue
          .where((e) => e.entityType == 'online_learning_attempt')
          .toList();
      expect(attemptOps.length, 3); // start, complete, delete
      expect(
        attemptOps.where((e) => e.operation == 'upsert').length,
        2,
      );
      expect(
        attemptOps.where((e) => e.operation == 'delete').length,
        1,
      );
    });

    test('watchStudentAttempts returns attempts across items for a student',
        () async {
      await repository.saveItem(
        itemType: OnlineLearningRepository.courseType,
        title: 'Flutter Basics',
      );
      await repository.saveItem(
        itemType: OnlineLearningRepository.quizType,
        title: 'Dart Quiz',
      );

      final allItems = await repository.watchItems().first;
      expect(allItems.length, 2);

      for (final item in allItems) {
        await repository.startAttempt(
          itemId: item.id,
          studentId: 'student_2',
        );
      }

      final studentAttempts = await repository
          .watchStudentAttempts(studentId: 'student_2')
          .first;
      expect(studentAttempts.length, 2);
    });
  });
}
