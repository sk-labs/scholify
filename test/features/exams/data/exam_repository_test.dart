import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';
import 'package:scholify/features/exams/data/exam_repository.dart';

void main() {
  group('ExamRepository', () {
    late AppLocalDatabase database;
    late TenantContext tenantContext;
    late SyncEngine syncEngine;
    late ExamRepository repository;

    const tenantId = 'tenant_alpha';
    final month = DateTime(2026, 4, 1);

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

      repository = ExamRepository(
        database: database,
        syncEngine: syncEngine,
        tenantContext: tenantContext,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'creates, updates, and deletes exam schedule with queue operations',
      () async {
        await repository.createExamSchedule(
          examName: 'Unit Test 1',
          subjectName: 'Mathematics',
          maxMarks: 100,
          examDate: DateTime(2026, 4, 12),
        );

        var schedules = await repository.watchExamSchedules(month: month).first;
        expect(schedules.length, 1);

        final created = schedules.single;
        expect(created.examName, 'Unit Test 1');

        await repository.updateExamSchedule(
          schedule: created,
          examName: 'Unit Test 1 - Updated',
          subjectName: 'Physics',
          maxMarks: 80,
          examDate: DateTime(2026, 4, 14),
        );

        schedules = await repository.watchExamSchedules(month: month).first;
        final updated = schedules.single;
        expect(updated.id, created.id);
        expect(updated.examName, 'Unit Test 1 - Updated');
        expect(updated.subjectName, 'Physics');
        expect(updated.maxMarks, 80);

        await repository.upsertStudentMark(
          studentId: 'stu_1',
          scheduleId: updated.id,
          scheduleMaxMarks: updated.maxMarks,
          marksObtained: 70,
        );

        await repository.deleteExamSchedule(schedule: updated);

        schedules = await repository.watchExamSchedules(month: month).first;
        expect(schedules, isEmpty);

        final marks = await repository
            .watchStudentMonthMarks(studentId: 'stu_1', month: month)
            .first;
        expect(marks, isEmpty);

        final queue = await database.getSyncQueueDispatchBatch(
          limit: 50,
          tenantId: tenantId,
        );

        expect(
          queue.any(
            (entry) =>
                entry.entityType == 'exam_schedule' &&
                entry.operation == 'upsert',
          ),
          isTrue,
        );
        expect(
          queue.any(
            (entry) =>
                entry.entityType == 'exam_schedule' &&
                entry.operation == 'delete',
          ),
          isTrue,
        );
        expect(
          queue.any(
            (entry) =>
                entry.entityType == 'exam_mark' && entry.operation == 'delete',
          ),
          isTrue,
        );
      },
    );

    test(
      'creates, updates, and deletes student marks for a schedule',
      () async {
        await repository.createExamSchedule(
          examName: 'Terminal',
          subjectName: 'Biology',
          maxMarks: 100,
          examDate: DateTime(2026, 4, 18),
        );

        final schedule =
            (await repository.watchExamSchedules(month: month).first).single;

        await repository.upsertStudentMark(
          studentId: 'stu_1',
          scheduleId: schedule.id,
          scheduleMaxMarks: schedule.maxMarks,
          marksObtained: 44,
        );

        var marks = await repository
            .watchStudentMonthMarks(studentId: 'stu_1', month: month)
            .first;
        expect(marks.length, 1);
        expect(marks.single.grade, 'D');

        await repository.upsertStudentMark(
          studentId: 'stu_1',
          scheduleId: schedule.id,
          scheduleMaxMarks: schedule.maxMarks,
          marksObtained: 93,
        );

        marks = await repository
            .watchStudentMonthMarks(studentId: 'stu_1', month: month)
            .first;
        expect(marks.single.marksObtained, 93);
        expect(marks.single.grade, 'A+');

        await repository.deleteStudentMark(
          markId: marks.single.markId,
          scheduleId: marks.single.scheduleId,
          studentId: 'stu_1',
        );

        marks = await repository
            .watchStudentMonthMarks(studentId: 'stu_1', month: month)
            .first;
        expect(marks, isEmpty);

        final queue = await database.getSyncQueueDispatchBatch(
          limit: 50,
          tenantId: tenantId,
        );
        expect(
          queue.where((entry) => entry.entityType == 'exam_mark').length,
          greaterThanOrEqualTo(3),
        );
        expect(
          queue.any(
            (entry) =>
                entry.entityType == 'exam_mark' && entry.operation == 'delete',
          ),
          isTrue,
        );
      },
    );

    test('builds analytics snapshot with subject and topper metrics', () async {
      await database.createOrUpdateStudentProfile(
        studentId: 'stu_1',
        tenantId: tenantId,
        admissionNo: 'ADM-001',
        fullName: 'Asha Malik',
        classSection: '6-A',
      );
      await database.createOrUpdateStudentProfile(
        studentId: 'stu_2',
        tenantId: tenantId,
        admissionNo: 'ADM-002',
        fullName: 'Ishita Rao',
        classSection: '6-A',
      );

      await repository.createExamSchedule(
        examName: 'Unit Test',
        subjectName: 'Mathematics',
        maxMarks: 100,
        examDate: DateTime(2026, 4, 11),
      );
      await repository.createExamSchedule(
        examName: 'Unit Test',
        subjectName: 'Science',
        maxMarks: 100,
        examDate: DateTime(2026, 4, 14),
      );

      final schedules = await repository.watchExamSchedules(month: month).first;
      final mathSchedule = schedules.firstWhere(
        (row) => row.subjectName == 'Mathematics',
      );
      final scienceSchedule = schedules.firstWhere(
        (row) => row.subjectName == 'Science',
      );

      await repository.upsertStudentMark(
        studentId: 'stu_1',
        scheduleId: mathSchedule.id,
        scheduleMaxMarks: 100,
        marksObtained: 90,
      );
      await repository.upsertStudentMark(
        studentId: 'stu_2',
        scheduleId: mathSchedule.id,
        scheduleMaxMarks: 100,
        marksObtained: 40,
      );
      await repository.upsertStudentMark(
        studentId: 'stu_1',
        scheduleId: scienceSchedule.id,
        scheduleMaxMarks: 100,
        marksObtained: 80,
      );
      await repository.upsertStudentMark(
        studentId: 'stu_2',
        scheduleId: scienceSchedule.id,
        scheduleMaxMarks: 100,
        marksObtained: 20,
      );

      final analytics = await repository.watchExamAnalytics(month: month).first;
      expect(analytics.totalAttempts, 4);
      expect(analytics.uniqueStudents, 2);
      expect(analytics.averagePercent, closeTo(57.5, 0.01));
      expect(analytics.passRate, closeTo(75.0, 0.01));
      expect(
        analytics.availableSubjects,
        containsAll(['Mathematics', 'Science']),
      );
      expect(analytics.subjectPerformance.length, 2);
      expect(analytics.topperList.first.studentId, 'stu_1');
      expect(analytics.gradeDistribution['A+'], 1);
      expect(analytics.gradeDistribution['A'], 1);
      expect(analytics.gradeDistribution['F'], 1);

      final subjectFiltered = await repository
          .watchExamAnalytics(month: month, subjectName: 'Science')
          .first;
      expect(subjectFiltered.totalAttempts, 2);
      expect(subjectFiltered.averagePercent, closeTo(50.0, 0.01));
      expect(subjectFiltered.topperList.first.studentId, 'stu_1');
    });
  });
}
