class ScholifyModuleFeature {
  static const String students = 'students';
  static const String guardians = 'guardians';
  static const String enrollment = 'enrollment';
  static const String classRoll = 'class_roll';
  static const String leaveRequests = 'leave_requests';
  static const String pendingTasks = 'pending_tasks';
  static const String hostel = 'hostel';
  static const String fees = 'fees';
  static const String attendance = 'attendance';
  static const String exams = 'exams';
  static const String notices = 'notices';
  static const String timetable = 'timetable';
  static const String transport = 'transport';
  static const String homework = 'homework';
  static const String onlineLearning = 'online_learning';
  static const String curriculum = 'curriculum';
  static const String library = 'library';
  static const String documentCenter = 'document_center';
  static const String visitorCommunication = 'visitor_communication';
  static const String notifications = 'notifications';
  static const String liveClasses = 'live_classes';
  static const String studentBehaviour = 'student_behaviour';
  static const String teachers = 'teachers';

  static const List<String> all = [
    students,
    guardians,
    enrollment,
    classRoll,
    leaveRequests,
    pendingTasks,
    hostel,
    fees,
    attendance,
    exams,
    notices,
    timetable,
    transport,
    homework,
    onlineLearning,
    curriculum,
    library,
    documentCenter,
    visitorCommunication,
    notifications,
    liveClasses,
    studentBehaviour,
    teachers,
  ];
}

class ModuleAccessPolicy {
  static String normalizePlanCode(String? planCode) {
    final normalized = (planCode ?? '').trim().toLowerCase();
    if (normalized.isEmpty) {
      return 'starter';
    }
    if (normalized == 'enterprise') {
      return 'enterprise';
    }
    if (normalized == 'professional') {
      return 'professional';
    }
    return 'starter';
  }

  static Map<String, bool> defaultsForPlan(String? planCode) {
    final plan = normalizePlanCode(planCode);

    switch (plan) {
      case 'enterprise':
        return {for (final feature in ScholifyModuleFeature.all) feature: true};
      case 'professional':
        return {
          ScholifyModuleFeature.students: true,
          ScholifyModuleFeature.guardians: true,
          ScholifyModuleFeature.enrollment: true,
          ScholifyModuleFeature.classRoll: true,
          ScholifyModuleFeature.leaveRequests: true,
          ScholifyModuleFeature.pendingTasks: true,
          ScholifyModuleFeature.hostel: true,
          ScholifyModuleFeature.fees: true,
          ScholifyModuleFeature.attendance: true,
          ScholifyModuleFeature.exams: true,
          ScholifyModuleFeature.notices: true,
          ScholifyModuleFeature.timetable: true,
          ScholifyModuleFeature.transport: true,
          ScholifyModuleFeature.homework: true,
          ScholifyModuleFeature.onlineLearning: true,
          ScholifyModuleFeature.curriculum: true,
          ScholifyModuleFeature.library: true,
          ScholifyModuleFeature.documentCenter: true,
          ScholifyModuleFeature.visitorCommunication: true,
          ScholifyModuleFeature.notifications: true,
          ScholifyModuleFeature.liveClasses: true,
          ScholifyModuleFeature.studentBehaviour: true,
          ScholifyModuleFeature.teachers: true,
        };
      case 'starter':
      default:
        return {
          ScholifyModuleFeature.students: true,
          ScholifyModuleFeature.guardians: true,
          ScholifyModuleFeature.enrollment: false,
          ScholifyModuleFeature.classRoll: false,
          ScholifyModuleFeature.leaveRequests: false,
          ScholifyModuleFeature.pendingTasks: false,
          ScholifyModuleFeature.hostel: false,
          ScholifyModuleFeature.fees: false,
          ScholifyModuleFeature.attendance: true,
          ScholifyModuleFeature.exams: false,
          ScholifyModuleFeature.notices: true,
          ScholifyModuleFeature.timetable: true,
          ScholifyModuleFeature.transport: true,
          ScholifyModuleFeature.homework: true,
          ScholifyModuleFeature.onlineLearning: false,
          ScholifyModuleFeature.curriculum: false,
          ScholifyModuleFeature.library: false,
          ScholifyModuleFeature.documentCenter: false,
          ScholifyModuleFeature.visitorCommunication: false,
          ScholifyModuleFeature.notifications: false,
          ScholifyModuleFeature.liveClasses: false,
          ScholifyModuleFeature.studentBehaviour: false,
          ScholifyModuleFeature.teachers: true,
        };
    }
  }

  static Map<String, bool> resolve({
    required String? planCode,
    required Map<String, bool> overrides,
    required bool isSuperAdmin,
    String? role,
  }) {
    if (isSuperAdmin) {
      return {for (final feature in ScholifyModuleFeature.all) feature: true};
    }

    final resolved = defaultsForPlan(planCode);
    for (final entry in overrides.entries) {
      if (resolved.containsKey(entry.key)) {
        resolved[entry.key] = entry.value;
      }
    }

    final normalizedRole = (role ?? '').toLowerCase();
    if (normalizedRole == 'guardian') {
      const allowedForGuardian = {
        ScholifyModuleFeature.attendance,
        ScholifyModuleFeature.homework,
        ScholifyModuleFeature.timetable,
        ScholifyModuleFeature.fees,
        ScholifyModuleFeature.exams,
        ScholifyModuleFeature.notices,
        ScholifyModuleFeature.notifications,
      };
      for (final feature in resolved.keys.toList()) {
        if (!allowedForGuardian.contains(feature)) {
          resolved[feature] = false;
        }
      }
    } else if (normalizedRole == 'student') {
      const allowedForStudent = {
        ScholifyModuleFeature.attendance,
        ScholifyModuleFeature.homework,
        ScholifyModuleFeature.timetable,
        ScholifyModuleFeature.fees,
        ScholifyModuleFeature.exams,
        ScholifyModuleFeature.notices,
        ScholifyModuleFeature.notifications,
      };
      for (final feature in resolved.keys.toList()) {
        if (!allowedForStudent.contains(feature)) {
          resolved[feature] = false;
        }
      }
    } else if (normalizedRole == 'teacher') {
      // Teachers get their teaching workflow: classes, attendance, homework,
      // grading, and student/guardian lookups. Management modules
      // (staff directory, admissions, billing, operations) are excluded.
      const allowedForTeacher = {
        ScholifyModuleFeature.attendance,
        ScholifyModuleFeature.homework,
        ScholifyModuleFeature.timetable,
        ScholifyModuleFeature.notices,
        ScholifyModuleFeature.notifications,
        ScholifyModuleFeature.students,
        ScholifyModuleFeature.guardians,
        ScholifyModuleFeature.exams,
        ScholifyModuleFeature.liveClasses,
        ScholifyModuleFeature.onlineLearning,
        ScholifyModuleFeature.curriculum,
        ScholifyModuleFeature.library,
        ScholifyModuleFeature.studentBehaviour,
      };
      for (final feature in resolved.keys.toList()) {
        if (!allowedForTeacher.contains(feature)) {
          resolved[feature] = false;
        }
      }
    }

    return resolved;
  }
}
