import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/access/module_access_policy.dart';

void main() {
  group('ModuleAccessPolicy', () {
    test('starter plan defaults restrict premium modules', () {
      final resolved = ModuleAccessPolicy.resolve(
        planCode: 'starter',
        overrides: const <String, bool>{},
        isSuperAdmin: false,
      );

      expect(resolved[ScholifyModuleFeature.students], isTrue);
      expect(resolved[ScholifyModuleFeature.guardians], isTrue);
      expect(resolved[ScholifyModuleFeature.attendance], isTrue);
      expect(resolved[ScholifyModuleFeature.fees], isFalse);
      expect(resolved[ScholifyModuleFeature.exams], isFalse);
      expect(resolved[ScholifyModuleFeature.enrollment], isFalse);
      expect(resolved[ScholifyModuleFeature.classRoll], isFalse);
      expect(resolved[ScholifyModuleFeature.leaveRequests], isFalse);
      expect(resolved[ScholifyModuleFeature.pendingTasks], isFalse);
      expect(resolved[ScholifyModuleFeature.hostel], isFalse);
      expect(resolved[ScholifyModuleFeature.notices], isTrue);
      expect(resolved[ScholifyModuleFeature.timetable], isTrue);
      expect(resolved[ScholifyModuleFeature.transport], isTrue);
      expect(resolved[ScholifyModuleFeature.homework], isTrue);
      expect(resolved[ScholifyModuleFeature.onlineLearning], isFalse);
      expect(resolved[ScholifyModuleFeature.curriculum], isFalse);
      expect(resolved[ScholifyModuleFeature.library], isFalse);
      expect(resolved[ScholifyModuleFeature.documentCenter], isFalse);
      expect(resolved[ScholifyModuleFeature.visitorCommunication], isFalse);
      expect(resolved[ScholifyModuleFeature.notifications], isFalse);
      expect(resolved[ScholifyModuleFeature.liveClasses], isFalse);
    });

    test('explicit override can enable premium module for starter tenant', () {
      final resolved = ModuleAccessPolicy.resolve(
        planCode: 'starter',
        overrides: const <String, bool>{ScholifyModuleFeature.exams: true},
        isSuperAdmin: false,
      );

      expect(resolved[ScholifyModuleFeature.exams], isTrue);
    });

    test('superadmin bypass enables all modules', () {
      final resolved = ModuleAccessPolicy.resolve(
        planCode: 'starter',
        overrides: const <String, bool>{
          ScholifyModuleFeature.students: false,
          ScholifyModuleFeature.exams: false,
        },
        isSuperAdmin: true,
      );

      for (final key in ScholifyModuleFeature.all) {
        expect(resolved[key], isTrue);
      }
    });
  });
}
