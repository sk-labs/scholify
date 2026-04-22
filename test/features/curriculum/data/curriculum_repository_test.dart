import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';
import 'package:scholify/features/curriculum/data/curriculum_repository.dart';

void main() {
  group('CurriculumRepository', () {
    const tenantId = 'tenant_alpha';

    late AppLocalDatabase database;
    late TenantContext tenantContext;
    late SyncEngine syncEngine;
    late CurriculumRepository repository;

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

      repository = CurriculumRepository(
        database: database,
        syncEngine: syncEngine,
        tenantContext: tenantContext,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'creates and deletes lesson/plan/subject/syllabus with queued sync',
      () async {
        await repository.saveLesson(
          title: 'Fractions Basics',
          classSection: '6-A',
          subjectName: 'Math',
        );
        await repository.saveLessonPlan(
          title: 'Fractions Week 1',
          classSection: '6-A',
          subjectName: 'Math',
        );
        await repository.saveSubject(
          subjectName: 'Mathematics',
          subjectCode: 'MATH-06',
        );
        await repository.saveSyllabus(
          title: 'Term 1 Math Coverage',
          classSection: '6-A',
          subjectName: 'Math',
        );

        final lessons = await repository.watchLessons().first;
        final plans = await repository.watchLessonPlans().first;
        final subjects = await repository.watchSubjects().first;
        final syllabus = await repository.watchSyllabusItems().first;

        expect(lessons.length, 1);
        expect(plans.length, 1);
        expect(subjects.length, 1);
        expect(syllabus.length, 1);

        await repository.deleteLesson(lessons.single);
        await repository.deleteLessonPlan(plans.single);
        await repository.deleteSubject(subjects.single);
        await repository.deleteSyllabus(syllabus.single);

        final queue = await database.getSyncQueueDispatchBatch(
          limit: 100,
          tenantId: tenantId,
        );
        final lessonOps = queue.where((q) => q.entityType == 'lesson').toList();
        final planOps = queue
            .where((q) => q.entityType == 'lesson_plan')
            .toList();
        final subjectOps = queue
            .where((q) => q.entityType == 'subject')
            .toList();
        final syllabusOps = queue
            .where((q) => q.entityType == 'syllabus')
            .toList();

        expect(lessonOps.length, 2);
        expect(planOps.length, 2);
        expect(subjectOps.length, 2);
        expect(syllabusOps.length, 2);
      },
    );

    test('attaches lesson resources and computes syllabus analytics', () async {
      await repository.saveLesson(
        title: 'Cells Intro',
        classSection: '8-A',
        subjectName: 'Science',
        attachmentUrl: 'https://example.com/slide-1.pdf',
      );

      final lesson = (await repository.watchLessons().first).single;
      await repository.attachLessonResource(
        lesson: lesson,
        attachmentUrl: 'https://example.com/worksheet-1.pdf',
      );

      final updatedLesson = (await repository.watchLessons().first).single;
      expect(updatedLesson.attachmentUrl, contains('slide-1.pdf'));
      expect(updatedLesson.attachmentUrl, contains('worksheet-1.pdf'));

      await repository.saveSyllabus(
        title: 'Science Term 1',
        statusLabel: 'completed',
        completionPercent: '100%',
      );
      await repository.saveSyllabus(
        title: 'Science Term 2',
        statusLabel: 'in_progress',
        completionPercent: '40%',
      );

      final analytics = await repository.watchSyllabusProgressAnalytics().first;
      expect(analytics.totalItems, 2);
      expect(analytics.completedItems, 1);
      expect(analytics.inProgressItems, 1);
      expect(analytics.averageCompletionPercent, 70);
    });
  });
}
