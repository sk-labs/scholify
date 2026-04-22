import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';
import 'package:scholify/features/students/data/student_repository.dart';

void main() {
  group('StudentRepository', () {
    late AppLocalDatabase database;
    late TenantContext tenantContext;
    late SyncEngine syncEngine;
    late StudentRepository repository;

    const tenantId = 'tenant_alpha';

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

      repository = StudentRepository(
        database: database,
        syncEngine: syncEngine,
        tenantContext: tenantContext,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'creates student and guardian, then toggles guardian status',
      () async {
        await repository.createOrUpdateStudent(
          studentId: 'stu_1',
          admissionNo: 'ADM-001',
          fullName: 'Asha Malik',
          classSection: '6-A',
        );

        await repository.createOrUpdateGuardian(
          studentId: 'stu_1',
          fullName: 'Ravi Malik',
          relation: 'father',
          phone: '9999999999',
          isPrimary: true,
        );

        final students = await repository.watchStudents().first;
        expect(students.length, 1);
        expect(students.single.id, 'stu_1');

        var guardians = await repository
            .watchStudentGuardians(studentId: 'stu_1')
            .first;
        expect(guardians.length, 1);
        expect(guardians.single.fullName, 'Ravi Malik');
        expect(guardians.single.isActive, isTrue);

        await repository.setGuardianStatus(
          guardian: guardians.single,
          isActive: false,
        );

        guardians = await repository
            .watchStudentGuardians(studentId: 'stu_1')
            .first;
        expect(guardians.single.isActive, isFalse);

        final queue = await database.getSyncQueueDispatchBatch(
          limit: 50,
          tenantId: tenantId,
        );

        expect(
          queue.any((entry) => entry.entityType == 'student_profile'),
          isTrue,
        );
        expect(
          queue.where((entry) => entry.entityType == 'student_guardian').length,
          greaterThanOrEqualTo(2),
        );
      },
    );

    test(
      'creates enrollment and class roll and queues both entities',
      () async {
        await repository.createOrUpdateStudent(
          studentId: 'stu_2',
          admissionNo: 'ADM-002',
          fullName: 'Ishita Rao',
          classSection: '7-B',
        );

        await repository.createOrUpdateEnrollment(
          studentId: 'stu_2',
          academicSession: '2026-2027',
          enrollmentStatus: 'enrolled',
          enrolledOn: DateTime.utc(2026, 4, 5),
          remarks: 'Transferred from section A',
        );

        await repository.createOrUpdateClassRoll(
          studentId: 'stu_2',
          academicSession: '2026-2027',
          className: '7',
          sectionName: 'B',
          rollNo: '17',
          isActive: true,
        );

        final enrollmentRows = await repository
            .watchStudentEnrollments(studentId: 'stu_2')
            .first;
        expect(enrollmentRows.length, 1);
        expect(enrollmentRows.single.academicSession, '2026-2027');
        expect(enrollmentRows.single.enrollmentStatus, 'enrolled');

        final classRollRows = await repository
            .watchStudentClassRolls(studentId: 'stu_2')
            .first;
        expect(classRollRows.length, 1);
        expect(classRollRows.single.className, '7');
        expect(classRollRows.single.sectionName, 'B');
        expect(classRollRows.single.rollNo, '17');

        final queue = await database.getSyncQueueDispatchBatch(
          limit: 50,
          tenantId: tenantId,
        );

        expect(
          queue.any((entry) => entry.entityType == 'student_enrollment'),
          isTrue,
        );
        expect(
          queue.any((entry) => entry.entityType == 'student_class_roll'),
          isTrue,
        );
      },
    );
  });
}
