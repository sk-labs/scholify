import 'package:pocketbase/pocketbase.dart';

import '../auth/auth_session.dart';

class PocketbaseGateway {
  PocketbaseGateway({required String baseUrl}) : _client = PocketBase(baseUrl);

  static const String tenantsCollection = 'tenants';
  static const String tenantLicensesCollection = 'tenant_licenses';
  static const String tenantUsageMetricsCollection = 'tenant_usage_metrics';
  static const String tenantFeatureFlagsCollection = 'tenant_feature_flags';
  static const String noticeBoardsCollection = 'notice_boards';
  static const String timetableSlotsCollection = 'timetable_slots';
  static const String transportRoutesCollection = 'transport_routes';
  static const String homeworkAssignmentsCollection = 'homework_assignments';
  static const String homeworkSubmissionsCollection = 'homework_submissions';
  static const String onlineLearningItemsCollection = 'online_learning_items';
  static const String onlineLearningAttemptsCollection = 'online_learning_attempts';
  static const String feeGroupsCollection = 'fee_groups';
  static const String cbseExamResultsCollection = 'cbse_exam_results';
  static const String onlineExamsCollection = 'online_exams';
  static const String studentBehaviourCollection = 'student_behaviour';
  static const String behaviourCommentsCollection = 'behaviour_comments';
  static const String teachersCollection = 'teachers';
  static const String onlineLessonsCollection = 'online_lessons';
  static const String lessonsCollection = 'lessons';
  static const String lessonPlansCollection = 'lesson_plans';
  static const String subjectsCollection = 'subjects';
  static const String syllabusCollection = 'syllabus_items';
  static const String libraryItemsCollection = 'library_items';
  static const String documentCenterCollection = 'document_center_items';
  static const String visitorCommunicationCollection =
      'visitor_communication_entries';
  static const String notificationsCollection = 'notification_entries';
  static const String liveClassesCollection = 'live_class_items';
  static const String schoolOwnersCollection = 'school_owners';
  static const String studentProfilesCollection = 'student_profiles';
  static const String studentGuardiansCollection = 'student_guardians';
  static const String studentEnrollmentsCollection = 'student_enrollments';
  static const String studentClassRollsCollection = 'student_class_rolls';
  static const String studentAttendanceCollection = 'student_attendance';
  static const String leaveRequestsCollection = 'leave_requests';
  static const String pendingTasksCollection = 'pending_tasks';
  static const String hostelRoomsCollection = 'hostel_rooms';
  static const String feeInvoicesCollection = 'fee_invoices';
  static const String feePaymentsCollection = 'fee_payments';
  static const String examSchedulesCollection = 'exam_schedules';
  static const String studentExamMarksCollection = 'student_exam_marks';

  final PocketBase _client;

  PocketBase get client => _client;

  bool get isAuthenticated => _client.authStore.isValid;
  String? get currentAuthToken => _client.authStore.token;
  Map<String, dynamic>? get currentAuthModelJson =>
      _recordToMap(_client.authStore.model);

  void restoreAuthSnapshot({
    required String token,
    required Map<String, dynamic> modelJson,
  }) {
    _client.authStore.save(token, modelJson);
  }

  Future<bool> signInWithPassword({
    required String identity,
    required String password,
  }) async {
    final session = await signInAndResolveSession(
      identity: identity,
      password: password,
    );
    return session != null;
  }

  Future<AuthSession?> signInAndResolveSession({
    required String identity,
    required String password,
  }) async {
    try {
      await _client.collection('users').authWithPassword(identity, password);
      return currentSession();
    } catch (_) {
      return null;
    }
  }

  AuthSession? currentSession() {
    if (!_client.authStore.isValid) {
      return null;
    }

    final authModel = _recordToMap(_client.authStore.model);
    if (authModel == null) {
      return null;
    }

    return _sessionFromModel(authModel);
  }

  void signOut() {
    _client.authStore.clear();
  }

  Future<bool> pushTenantLicense({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      if (tenantId.isEmpty) return false;

      final tenantName = _stringFrom(payload, [
        'tenantName',
        'tenant_name',
      ], fallback: 'Unknown School');
      final licenseId = _stringFrom(payload, [
        'licenseId',
        'license_id',
      ], fallback: 'lic_$tenantId');

      final schoolOwnerEmail = _stringFrom(payload, [
        'ownerEmail',
        'schoolOwnerEmail',
        'school_owner_email',
      ]);
      final planCode = _stringFrom(payload, ['planCode', 'plan_code']);
      final seatLimit = _intFrom(payload, ['seatLimit', 'seat_limit']) ?? 100;
      final isActive =
          _boolFrom(payload, ['isActive', 'is_active']) ??
          operation != 'suspend';
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: tenantsCollection,
        externalId: tenantId,
        body: {
          'tenant_id': tenantId,
          'name': tenantName,
          'is_active': isActive,
          'updated_at': updatedAt,
        },
      );

      await _upsertByExternalId(
        collection: tenantLicensesCollection,
        externalId: licenseId,
        body: {
          'tenant_id': tenantId,
          'tenant_name': tenantName,
          'school_owner_email': schoolOwnerEmail,
          'plan_code': planCode,
          'seat_limit': seatLimit,
          'is_active': isActive,
          'updated_at': updatedAt,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> pushSchoolOwner({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final ownerId = _stringFrom(payload, ['ownerId', 'owner_id']);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      if (ownerId.isEmpty || tenantId.isEmpty) return false;

      final fullName = _stringFrom(payload, ['fullName', 'full_name']);
      final email = _stringFrom(payload, ['email']);
      final phone = _stringFrom(payload, ['phone']);
      final tenantName = _stringFrom(payload, [
        'tenantName',
        'tenant_name',
      ], fallback: 'Unknown School');
      final isActive =
          _boolFrom(payload, ['isActive', 'is_active']) ??
          operation != 'suspend';
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: tenantsCollection,
        externalId: tenantId,
        body: {
          'tenant_id': tenantId,
          'name': tenantName,
          'is_active': isActive,
          'updated_at': updatedAt,
        },
      );

      await _upsertByExternalId(
        collection: schoolOwnersCollection,
        externalId: ownerId,
        body: {
          'owner_id': ownerId,
          'tenant_id': tenantId,
          'tenant_name': tenantName,
          'full_name': fullName,
          'email': email,
          'phone': phone,
          'is_active': isActive,
          'updated_at': updatedAt,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullTenantLicenses({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      tenantLicensesCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  Future<List<Map<String, dynamic>>> pullSchoolOwners({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      schoolOwnersCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  Future<List<Map<String, dynamic>>> pullTenantUsageMetrics({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      tenantUsageMetricsCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  Future<bool> pushTenantFeatureFlag({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final flagId = _stringFrom(payload, ['flagId', 'flag_id', 'id']);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      final featureKey = _stringFrom(payload, ['featureKey', 'feature_key']);

      if (flagId.isEmpty || tenantId.isEmpty || featureKey.isEmpty) {
        return false;
      }

      final isEnabled =
          _boolFrom(payload, ['isEnabled', 'is_enabled']) ??
          operation != 'disable';
      final source = _stringFrom(payload, ['source'], fallback: 'local');
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: tenantFeatureFlagsCollection,
        externalId: flagId,
        body: {
          'flag_id': flagId,
          'tenant_id': tenantId,
          'feature_key': featureKey,
          'is_enabled': isEnabled,
          'source': source,
          'updated_at': updatedAt,
          'operation': operation,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullTenantFeatureFlags({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      tenantFeatureFlagsCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  Future<bool> pushNoticeBoard({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final noticeId = _stringFrom(payload, ['noticeId', 'notice_id', 'id']);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);

      if (noticeId.isEmpty || tenantId.isEmpty) {
        return false;
      }

      if (operation == 'delete') {
        return _deleteByExternalId(
          collection: noticeBoardsCollection,
          externalId: noticeId,
        );
      }

      final title = _stringFrom(payload, ['title'], fallback: 'Notice');
      final message = _stringFrom(payload, ['message']);
      final audience = _stringFrom(payload, ['audience'], fallback: 'all');
      final publishAt = _stringFrom(payload, [
        'publishAt',
        'publish_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());
      final expiresAt = _stringFrom(payload, ['expiresAt', 'expires_at']);
      final isPublished =
          _boolFrom(payload, ['isPublished', 'is_published']) ?? true;
      final source = _stringFrom(payload, ['source'], fallback: 'local');
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: noticeBoardsCollection,
        externalId: noticeId,
        body: {
          'notice_id': noticeId,
          'tenant_id': tenantId,
          'title': title,
          'message': message,
          'audience': audience,
          'publish_at': publishAt,
          'expires_at': expiresAt,
          'is_published': isPublished,
          'source': source,
          'updated_at': updatedAt,
          'operation': operation,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullNoticeBoards({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      noticeBoardsCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  Future<bool> pushTimetableSlot({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final slotId = _stringFrom(payload, ['slotId', 'slot_id', 'id']);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      if (slotId.isEmpty || tenantId.isEmpty) {
        return false;
      }

      if (operation == 'delete') {
        return _deleteByExternalId(
          collection: timetableSlotsCollection,
          externalId: slotId,
        );
      }

      final dayOfWeek = _stringFrom(payload, [
        'dayOfWeek',
        'day_of_week',
      ], fallback: 'Monday');
      final periodIndex =
          _intFrom(payload, ['periodIndex', 'period_index']) ?? 1;
      final subjectName = _stringFrom(payload, [
        'subjectName',
        'subject_name',
      ], fallback: 'General');
      final teacherName = _stringFrom(payload, ['teacherName', 'teacher_name']);
      final roomNo = _stringFrom(payload, ['roomNo', 'room_no']);
      final timeFrom = _stringFrom(payload, ['timeFrom', 'time_from']);
      final timeTo = _stringFrom(payload, ['timeTo', 'time_to']);
      final classSection = _stringFrom(payload, [
        'classSection',
        'class_section',
      ]);
      final isActive = _boolFrom(payload, ['isActive', 'is_active']) ?? true;
      final source = _stringFrom(payload, ['source'], fallback: 'local');
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: timetableSlotsCollection,
        externalId: slotId,
        body: {
          'slot_id': slotId,
          'tenant_id': tenantId,
          'day_of_week': dayOfWeek,
          'period_index': periodIndex,
          'subject_name': subjectName,
          'teacher_name': teacherName,
          'room_no': roomNo,
          'time_from': timeFrom,
          'time_to': timeTo,
          'class_section': classSection,
          'is_active': isActive,
          'source': source,
          'updated_at': updatedAt,
          'operation': operation,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullTimetableSlots({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      timetableSlotsCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  Future<bool> pushTransportRoute({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final routeId = _stringFrom(payload, ['routeId', 'route_id', 'id']);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      if (routeId.isEmpty || tenantId.isEmpty) {
        return false;
      }

      if (operation == 'delete') {
        return _deleteByExternalId(
          collection: transportRoutesCollection,
          externalId: routeId,
        );
      }

      final routeTitle = _stringFrom(payload, [
        'routeTitle',
        'route_title',
      ], fallback: 'Route');
      final vehicleNo = _stringFrom(payload, ['vehicleNo', 'vehicle_no']);
      final vehicleModel = _stringFrom(payload, [
        'vehicleModel',
        'vehicle_model',
      ]);
      final driverName = _stringFrom(payload, ['driverName', 'driver_name']);
      final driverContact = _stringFrom(payload, [
        'driverContact',
        'driver_contact',
      ]);
      final pickupPoint = _stringFrom(payload, ['pickupPoint', 'pickup_point']);
      final destinationPoint = _stringFrom(payload, [
        'destinationPoint',
        'destination_point',
      ]);
      final pickupTime = _stringFrom(payload, ['pickupTime', 'pickup_time']);
      final dropTime = _stringFrom(payload, ['dropTime', 'drop_time']);
      final monthlyFare =
          _doubleFrom(payload, ['monthlyFare', 'monthly_fare']) ?? 0;
      final isActive = _boolFrom(payload, ['isActive', 'is_active']) ?? true;
      final source = _stringFrom(payload, ['source'], fallback: 'local');
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: transportRoutesCollection,
        externalId: routeId,
        body: {
          'route_id': routeId,
          'tenant_id': tenantId,
          'route_title': routeTitle,
          'vehicle_no': vehicleNo,
          'vehicle_model': vehicleModel,
          'driver_name': driverName,
          'driver_contact': driverContact,
          'pickup_point': pickupPoint,
          'destination_point': destinationPoint,
          'pickup_time': pickupTime,
          'drop_time': dropTime,
          'monthly_fare': monthlyFare,
          'is_active': isActive,
          'source': source,
          'updated_at': updatedAt,
          'operation': operation,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullTransportRoutes({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      transportRoutesCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  Future<bool> pushHomeworkAssignment({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final assignmentId = _stringFrom(payload, [
        'assignmentId',
        'assignment_id',
        'id',
      ]);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      if (assignmentId.isEmpty || tenantId.isEmpty) {
        return false;
      }

      if (operation == 'delete') {
        return _deleteByExternalId(
          collection: homeworkAssignmentsCollection,
          externalId: assignmentId,
        );
      }

      final assignmentType = _stringFrom(payload, [
        'assignmentType',
        'assignment_type',
      ], fallback: 'homework');
      final title = _stringFrom(payload, ['title'], fallback: 'Assignment');
      final subjectName = _stringFrom(payload, ['subjectName', 'subject_name']);
      final classSection = _stringFrom(payload, [
        'classSection',
        'class_section',
      ]);
      final details = _stringFrom(payload, ['details', 'description']);
      final assignedOn = _stringFrom(payload, ['assignedOn', 'assigned_on']);
      final dueDate = _stringFrom(payload, ['dueDate', 'due_date']);
      final attachmentUrl = _stringFrom(payload, [
        'attachmentUrl',
        'attachment_url',
      ]);
      final isPublished =
          _boolFrom(payload, ['isPublished', 'is_published']) ?? true;
      final isActive = _boolFrom(payload, ['isActive', 'is_active']) ?? true;
      final source = _stringFrom(payload, ['source'], fallback: 'local');
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: homeworkAssignmentsCollection,
        externalId: assignmentId,
        body: {
          'assignment_id': assignmentId,
          'tenant_id': tenantId,
          'assignment_type': assignmentType,
          'title': title,
          'subject_name': subjectName,
          'class_section': classSection,
          'details': details,
          'assigned_on': assignedOn,
          'due_date': dueDate,
          'attachment_url': attachmentUrl,
          'is_published': isPublished,
          'is_active': isActive,
          'source': source,
          'updated_at': updatedAt,
          'operation': operation,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullHomeworkAssignments({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      homeworkAssignmentsCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  Future<bool> pushOnlineLearningItem({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final itemId = _stringFrom(payload, ['itemId', 'item_id', 'id']);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      if (itemId.isEmpty || tenantId.isEmpty) {
        return false;
      }

      if (operation == 'delete') {
        return _deleteByExternalId(
          collection: onlineLearningItemsCollection,
          externalId: itemId,
        );
      }

      final itemType = _stringFrom(payload, [
        'itemType',
        'item_type',
      ], fallback: 'course');
      final title = _stringFrom(payload, ['title'], fallback: 'Learning Item');
      final summary = _stringFrom(payload, ['summary', 'description']);
      final instructorName = _stringFrom(payload, [
        'instructorName',
        'instructor_name',
      ]);
      final durationLabel = _stringFrom(payload, [
        'durationLabel',
        'duration_label',
      ]);
      final accessLevel = _stringFrom(payload, [
        'accessLevel',
        'access_level',
      ], fallback: 'open');
      final priceAmount =
          _doubleFrom(payload, ['priceAmount', 'price_amount']) ?? 0;
      final publishedAt = _stringFrom(payload, ['publishedAt', 'published_at']);
      final isPublished =
          _boolFrom(payload, ['isPublished', 'is_published']) ?? true;
      final isActive = _boolFrom(payload, ['isActive', 'is_active']) ?? true;
      final source = _stringFrom(payload, ['source'], fallback: 'local');
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: onlineLearningItemsCollection,
        externalId: itemId,
        body: {
          'item_id': itemId,
          'tenant_id': tenantId,
          'item_type': itemType,
          'title': title,
          'summary': summary,
          'instructor_name': instructorName,
          'duration_label': durationLabel,
          'access_level': accessLevel,
          'price_amount': priceAmount,
          'published_at': publishedAt,
          'is_published': isPublished,
          'is_active': isActive,
          'source': source,
          'updated_at': updatedAt,
          'operation': operation,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullOnlineLearningItems({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      onlineLearningItemsCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  Future<bool> pushLesson({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final lessonId = _stringFrom(payload, ['lessonId', 'lesson_id', 'id']);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      if (lessonId.isEmpty || tenantId.isEmpty) {
        return false;
      }

      if (operation == 'delete') {
        return _deleteByExternalId(
          collection: lessonsCollection,
          externalId: lessonId,
        );
      }

      final title = _stringFrom(payload, ['title'], fallback: 'Lesson');
      final classSection = _stringFrom(payload, [
        'classSection',
        'class_section',
      ]);
      final subjectName = _stringFrom(payload, ['subjectName', 'subject_name']);
      final topicName = _stringFrom(payload, ['topicName', 'topic_name']);
      final lessonDateLabel = _stringFrom(payload, [
        'lessonDateLabel',
        'lesson_date_label',
      ]);
      final attachmentUrl = _stringFrom(payload, [
        'attachmentUrl',
        'attachment_url',
      ]);
      final isActive = _boolFrom(payload, ['isActive', 'is_active']) ?? true;
      final source = _stringFrom(payload, ['source'], fallback: 'local');
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: lessonsCollection,
        externalId: lessonId,
        body: {
          'lesson_id': lessonId,
          'tenant_id': tenantId,
          'title': title,
          'class_section': classSection,
          'subject_name': subjectName,
          'topic_name': topicName,
          'lesson_date_label': lessonDateLabel,
          'attachment_url': attachmentUrl,
          'is_active': isActive,
          'source': source,
          'updated_at': updatedAt,
          'operation': operation,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullLessons({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(lessonsCollection, since: since, tenantId: tenantId);
  }

  Future<bool> pushLessonPlan({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final planId = _stringFrom(payload, ['planId', 'plan_id', 'id']);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      if (planId.isEmpty || tenantId.isEmpty) {
        return false;
      }

      if (operation == 'delete') {
        return _deleteByExternalId(
          collection: lessonPlansCollection,
          externalId: planId,
        );
      }

      final title = _stringFrom(payload, ['title'], fallback: 'Lesson Plan');
      final classSection = _stringFrom(payload, [
        'classSection',
        'class_section',
      ]);
      final subjectName = _stringFrom(payload, ['subjectName', 'subject_name']);
      final objective = _stringFrom(payload, ['objective']);
      final periodLabel = _stringFrom(payload, ['periodLabel', 'period_label']);
      final activities = _stringFrom(payload, ['activities']);
      final isActive = _boolFrom(payload, ['isActive', 'is_active']) ?? true;
      final source = _stringFrom(payload, ['source'], fallback: 'local');
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: lessonPlansCollection,
        externalId: planId,
        body: {
          'plan_id': planId,
          'tenant_id': tenantId,
          'title': title,
          'class_section': classSection,
          'subject_name': subjectName,
          'objective': objective,
          'period_label': periodLabel,
          'activities': activities,
          'is_active': isActive,
          'source': source,
          'updated_at': updatedAt,
          'operation': operation,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullLessonPlans({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      lessonPlansCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  Future<bool> pushSubject({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final subjectId = _stringFrom(payload, ['subjectId', 'subject_id', 'id']);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      if (subjectId.isEmpty || tenantId.isEmpty) {
        return false;
      }

      if (operation == 'delete') {
        return _deleteByExternalId(
          collection: subjectsCollection,
          externalId: subjectId,
        );
      }

      final subjectName = _stringFrom(payload, [
        'subjectName',
        'subject_name',
      ], fallback: 'Subject');
      final subjectCode = _stringFrom(payload, ['subjectCode', 'subject_code']);
      final subjectType = _stringFrom(payload, [
        'subjectType',
        'subject_type',
      ], fallback: 'theory');
      final classSection = _stringFrom(payload, [
        'classSection',
        'class_section',
      ]);
      final teacherName = _stringFrom(payload, ['teacherName', 'teacher_name']);
      final isActive = _boolFrom(payload, ['isActive', 'is_active']) ?? true;
      final source = _stringFrom(payload, ['source'], fallback: 'local');
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: subjectsCollection,
        externalId: subjectId,
        body: {
          'subject_id': subjectId,
          'tenant_id': tenantId,
          'subject_name': subjectName,
          'subject_code': subjectCode,
          'subject_type': subjectType,
          'class_section': classSection,
          'teacher_name': teacherName,
          'is_active': isActive,
          'source': source,
          'updated_at': updatedAt,
          'operation': operation,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullSubjects({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      subjectsCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  Future<bool> pushSyllabus({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final syllabusId = _stringFrom(payload, [
        'syllabusId',
        'syllabus_id',
        'id',
      ]);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      if (syllabusId.isEmpty || tenantId.isEmpty) {
        return false;
      }

      if (operation == 'delete') {
        return _deleteByExternalId(
          collection: syllabusCollection,
          externalId: syllabusId,
        );
      }

      final title = _stringFrom(payload, ['title'], fallback: 'Syllabus');
      final classSection = _stringFrom(payload, [
        'classSection',
        'class_section',
      ]);
      final subjectName = _stringFrom(payload, ['subjectName', 'subject_name']);
      final statusLabel = _stringFrom(payload, [
        'statusLabel',
        'status_label',
      ], fallback: 'pending');
      final completionPercent = _stringFrom(payload, [
        'completionPercent',
        'completion_percent',
      ]);
      final targetDate = _stringFrom(payload, ['targetDate', 'target_date']);
      final notes = _stringFrom(payload, ['notes']);
      final isActive = _boolFrom(payload, ['isActive', 'is_active']) ?? true;
      final source = _stringFrom(payload, ['source'], fallback: 'local');
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: syllabusCollection,
        externalId: syllabusId,
        body: {
          'syllabus_id': syllabusId,
          'tenant_id': tenantId,
          'title': title,
          'class_section': classSection,
          'subject_name': subjectName,
          'status_label': statusLabel,
          'completion_percent': completionPercent,
          'target_date': targetDate,
          'notes': notes,
          'is_active': isActive,
          'source': source,
          'updated_at': updatedAt,
          'operation': operation,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullSyllabusItems({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      syllabusCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  Future<bool> pushLibraryItem({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final bookId = _stringFrom(payload, ['bookId', 'book_id', 'id']);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      if (bookId.isEmpty || tenantId.isEmpty) {
        return false;
      }

      if (operation == 'delete') {
        return _deleteByExternalId(
          collection: libraryItemsCollection,
          externalId: bookId,
        );
      }

      final bookType = _stringFrom(payload, [
        'bookType',
        'book_type',
      ], fallback: 'general');
      final title = _stringFrom(payload, ['title'], fallback: 'Book');
      final authorName = _stringFrom(payload, ['authorName', 'author_name']);
      final categoryName = _stringFrom(payload, [
        'categoryName',
        'category_name',
      ]);
      final issuedOn = _stringFrom(payload, ['issuedOn', 'issued_on']);
      final dueDate = _stringFrom(payload, ['dueDate', 'due_date']);
      final returnDate = _stringFrom(payload, ['returnDate', 'return_date']);
      final ratingScore =
          _doubleFrom(payload, ['ratingScore', 'rating_score']) ?? 0;
      final issueCount = _intFrom(payload, ['issueCount', 'issue_count']) ?? 0;
      final isIssued = _boolFrom(payload, ['isIssued', 'is_issued']) ?? false;
      final isActive = _boolFrom(payload, ['isActive', 'is_active']) ?? true;
      final source = _stringFrom(payload, ['source'], fallback: 'local');
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: libraryItemsCollection,
        externalId: bookId,
        body: {
          'book_id': bookId,
          'tenant_id': tenantId,
          'book_type': bookType,
          'title': title,
          'author_name': authorName,
          'category_name': categoryName,
          'issued_on': issuedOn,
          'due_date': dueDate,
          'return_date': returnDate,
          'rating_score': ratingScore,
          'issue_count': issueCount,
          'is_issued': isIssued,
          'is_active': isActive,
          'source': source,
          'updated_at': updatedAt,
          'operation': operation,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullLibraryItems({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      libraryItemsCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  Future<bool> pushDocumentCenterItem({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final itemId = _stringFrom(payload, ['itemId', 'item_id', 'id']);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      if (itemId.isEmpty || tenantId.isEmpty) {
        return false;
      }

      if (operation == 'delete') {
        return _deleteByExternalId(
          collection: documentCenterCollection,
          externalId: itemId,
        );
      }

      final contentType = _stringFrom(payload, [
        'contentType',
        'content_type',
      ], fallback: 'download_content');
      final title = _stringFrom(payload, ['title'], fallback: 'Document');
      final description = _stringFrom(payload, ['description']);
      final fileUrl = _stringFrom(payload, ['fileUrl', 'file_url']);
      final thumbnailUrl = _stringFrom(payload, [
        'thumbnailUrl',
        'thumbnail_url',
      ]);
      final categoryLabel = _stringFrom(payload, [
        'categoryLabel',
        'category_label',
      ]);
      final uploadState = _stringFrom(payload, [
        'uploadState',
        'upload_state',
      ], fallback: 'uploaded');
      final publishedAt = _stringFrom(payload, ['publishedAt', 'published_at']);
      final isActive = _boolFrom(payload, ['isActive', 'is_active']) ?? true;
      final source = _stringFrom(payload, ['source'], fallback: 'local');
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: documentCenterCollection,
        externalId: itemId,
        body: {
          'item_id': itemId,
          'tenant_id': tenantId,
          'content_type': contentType,
          'title': title,
          'description': description,
          'file_url': fileUrl,
          'thumbnail_url': thumbnailUrl,
          'category_label': categoryLabel,
          'upload_state': uploadState,
          'published_at': publishedAt,
          'is_active': isActive,
          'source': source,
          'updated_at': updatedAt,
          'operation': operation,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullDocumentCenterItems({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      documentCenterCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  Future<bool> pushVisitorCommunication({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final entryId = _stringFrom(payload, ['entryId', 'entry_id', 'id']);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      if (entryId.isEmpty || tenantId.isEmpty) {
        return false;
      }

      if (operation == 'delete') {
        return _deleteByExternalId(
          collection: visitorCommunicationCollection,
          externalId: entryId,
        );
      }

      final entryType = _stringFrom(payload, [
        'entryType',
        'entry_type',
      ], fallback: 'visitor');
      final visitorName = _stringFrom(payload, ['visitorName', 'visitor_name']);
      final purpose = _stringFrom(payload, ['purpose']);
      final phone = _stringFrom(payload, ['phone']);
      final checkInAt = _stringFrom(payload, ['checkInAt', 'check_in_at']);
      final checkOutAt = _stringFrom(payload, ['checkOutAt', 'check_out_at']);
      final statusLabel = _stringFrom(payload, [
        'statusLabel',
        'status_label',
      ], fallback: 'open');
      final note = _stringFrom(payload, ['note']);
      final isActive = _boolFrom(payload, ['isActive', 'is_active']) ?? true;
      final source = _stringFrom(payload, ['source'], fallback: 'local');
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: visitorCommunicationCollection,
        externalId: entryId,
        body: {
          'entry_id': entryId,
          'tenant_id': tenantId,
          'entry_type': entryType,
          'visitor_name': visitorName,
          'purpose': purpose,
          'phone': phone,
          'check_in_at': checkInAt,
          'check_out_at': checkOutAt,
          'status_label': statusLabel,
          'note': note,
          'is_active': isActive,
          'source': source,
          'updated_at': updatedAt,
          'operation': operation,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullVisitorCommunicationEntries({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      visitorCommunicationCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  Future<bool> pushNotification({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final notificationId = _stringFrom(payload, [
        'notificationId',
        'notification_id',
        'id',
      ]);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      if (notificationId.isEmpty || tenantId.isEmpty) {
        return false;
      }

      if (operation == 'delete') {
        return _deleteByExternalId(
          collection: notificationsCollection,
          externalId: notificationId,
        );
      }

      final notificationType = _stringFrom(payload, [
        'notificationType',
        'notification_type',
      ], fallback: 'general');
      final title = _stringFrom(payload, ['title'], fallback: 'Notification');
      final body = _stringFrom(payload, ['body', 'message']);
      final audience = _stringFrom(payload, ['audience'], fallback: 'all');
      final isRead = _boolFrom(payload, ['isRead', 'is_read']) ?? false;
      final deliveryStatus = _stringFrom(payload, [
        'deliveryStatus',
        'delivery_status',
      ], fallback: 'queued');
      final sentAt = _stringFrom(payload, ['sentAt', 'sent_at']);
      final readAt = _stringFrom(payload, ['readAt', 'read_at']);
      final payloadJson = _stringFrom(payload, ['payloadJson', 'payload_json']);
      final isActive = _boolFrom(payload, ['isActive', 'is_active']) ?? true;
      final source = _stringFrom(payload, ['source'], fallback: 'local');
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: notificationsCollection,
        externalId: notificationId,
        body: {
          'notification_id': notificationId,
          'tenant_id': tenantId,
          'notification_type': notificationType,
          'title': title,
          'body': body,
          'audience': audience,
          'is_read': isRead,
          'delivery_status': deliveryStatus,
          'sent_at': sentAt,
          'read_at': readAt,
          'payload_json': payloadJson,
          'is_active': isActive,
          'source': source,
          'updated_at': updatedAt,
          'operation': operation,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullNotifications({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      notificationsCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  Future<bool> pushLiveClass({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final classId = _stringFrom(payload, ['classId', 'class_id', 'id']);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      if (classId.isEmpty || tenantId.isEmpty) {
        return false;
      }

      if (operation == 'delete') {
        return _deleteByExternalId(
          collection: liveClassesCollection,
          externalId: classId,
        );
      }

      final providerType = _stringFrom(payload, [
        'providerType',
        'provider_type',
      ], fallback: 'zoom');
      final title = _stringFrom(payload, ['title'], fallback: 'Live Class');
      final classSection = _stringFrom(payload, [
        'classSection',
        'class_section',
      ]);
      final hostName = _stringFrom(payload, ['hostName', 'host_name']);
      final startAt = _stringFrom(payload, ['startAt', 'start_at']);
      final endAt = _stringFrom(payload, ['endAt', 'end_at']);
      final joinUrl = _stringFrom(payload, ['joinUrl', 'join_url']);
      final meetingId = _stringFrom(payload, ['meetingId', 'meeting_id']);
      final meetingPassword = _stringFrom(payload, [
        'meetingPassword',
        'meeting_password',
      ]);
      final statusLabel = _stringFrom(payload, [
        'statusLabel',
        'status_label',
      ], fallback: 'scheduled');
      final isActive = _boolFrom(payload, ['isActive', 'is_active']) ?? true;
      final source = _stringFrom(payload, ['source'], fallback: 'local');
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: liveClassesCollection,
        externalId: classId,
        body: {
          'class_id': classId,
          'tenant_id': tenantId,
          'provider_type': providerType,
          'title': title,
          'class_section': classSection,
          'host_name': hostName,
          'start_at': startAt,
          'end_at': endAt,
          'join_url': joinUrl,
          'meeting_id': meetingId,
          'meeting_password': meetingPassword,
          'status_label': statusLabel,
          'is_active': isActive,
          'source': source,
          'updated_at': updatedAt,
          'operation': operation,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullLiveClasses({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      liveClassesCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  Future<bool> pushStudentAttendance({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final recordId = _stringFrom(payload, ['recordId', 'record_id', 'id']);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      final studentId = _stringFrom(payload, ['studentId', 'student_id']);

      if (recordId.isEmpty || tenantId.isEmpty || studentId.isEmpty) {
        return false;
      }

      final status = _stringFrom(payload, ['status'], fallback: 'present');
      final source = _stringFrom(payload, ['source'], fallback: 'local');
      final attendanceDate = _stringFrom(payload, [
        'attendanceDate',
        'attendance_date',
      ], fallback: DateTime.now().toUtc().toIso8601String());
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: studentAttendanceCollection,
        externalId: recordId,
        body: {
          'record_id': recordId,
          'tenant_id': tenantId,
          'student_id': studentId,
          'status': status,
          'source': source,
          'attendance_date': attendanceDate,
          'updated_at': updatedAt,
          'operation': operation,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullStudentAttendance({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      studentAttendanceCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  Future<bool> pushStudentProfile({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final studentId = _stringFrom(payload, ['studentId', 'student_id', 'id']);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);

      if (studentId.isEmpty || tenantId.isEmpty) {
        return false;
      }

      final admissionNo = _stringFrom(payload, [
        'admissionNo',
        'admission_no',
      ], fallback: studentId);
      final fullName = _stringFrom(payload, [
        'fullName',
        'full_name',
        'name',
      ], fallback: 'Unnamed Student');
      final classSection = _stringFrom(payload, [
        'classSection',
        'class_section',
      ]);
      final isActive =
          _boolFrom(payload, ['isActive', 'is_active']) ??
          operation != 'archive';
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: studentProfilesCollection,
        externalId: studentId,
        body: {
          'student_id': studentId,
          'tenant_id': tenantId,
          'admission_no': admissionNo,
          'full_name': fullName,
          'class_section': classSection,
          'is_active': isActive,
          'updated_at': updatedAt,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullStudentProfiles({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      studentProfilesCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  Future<bool> pushStudentGuardian({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final guardianId = _stringFrom(payload, [
        'guardianId',
        'guardian_id',
        'id',
      ]);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      final studentId = _stringFrom(payload, ['studentId', 'student_id']);

      if (guardianId.isEmpty || tenantId.isEmpty || studentId.isEmpty) {
        return false;
      }

      final fullName = _stringFrom(payload, ['fullName', 'full_name', 'name']);
      final relation = _stringFrom(payload, ['relation'], fallback: 'guardian');
      final phone = _stringFrom(payload, ['phone']);
      final email = _stringFrom(payload, ['email']);
      final isPrimary =
          _boolFrom(payload, ['isPrimary', 'is_primary']) ?? false;
      final isActive =
          _boolFrom(payload, ['isActive', 'is_active']) ??
          operation != 'archive';
      final source = _stringFrom(payload, ['source'], fallback: 'local');
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: studentGuardiansCollection,
        externalId: guardianId,
        body: {
          'guardian_id': guardianId,
          'tenant_id': tenantId,
          'student_id': studentId,
          'full_name': fullName,
          'relation': relation,
          'phone': phone,
          'email': email,
          'is_primary': isPrimary,
          'is_active': isActive,
          'source': source,
          'updated_at': updatedAt,
          'operation': operation,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullStudentGuardians({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      studentGuardiansCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  Future<bool> pushStudentEnrollment({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final enrollmentId = _stringFrom(payload, [
        'enrollmentId',
        'enrollment_id',
        'id',
      ]);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      final studentId = _stringFrom(payload, ['studentId', 'student_id']);

      if (enrollmentId.isEmpty || tenantId.isEmpty || studentId.isEmpty) {
        return false;
      }

      final academicSession = _stringFrom(payload, [
        'academicSession',
        'academic_session',
      ]);
      final enrollmentStatus = _stringFrom(payload, [
        'enrollmentStatus',
        'enrollment_status',
      ], fallback: 'enrolled');
      final enrolledOn = _stringFrom(payload, ['enrolledOn', 'enrolled_on']);
      final leftOn = _stringFrom(payload, ['leftOn', 'left_on']);
      final remarks = _stringFrom(payload, ['remarks']);
      final source = _stringFrom(payload, ['source'], fallback: 'local');
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: studentEnrollmentsCollection,
        externalId: enrollmentId,
        body: {
          'enrollment_id': enrollmentId,
          'tenant_id': tenantId,
          'student_id': studentId,
          'academic_session': academicSession,
          'enrollment_status': enrollmentStatus,
          'enrolled_on': enrolledOn,
          'left_on': leftOn,
          'remarks': remarks,
          'source': source,
          'updated_at': updatedAt,
          'operation': operation,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullStudentEnrollments({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      studentEnrollmentsCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  Future<bool> pushStudentClassRoll({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final classRollId = _stringFrom(payload, [
        'classRollId',
        'class_roll_id',
        'id',
      ]);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      final studentId = _stringFrom(payload, ['studentId', 'student_id']);

      if (classRollId.isEmpty || tenantId.isEmpty || studentId.isEmpty) {
        return false;
      }

      final academicSession = _stringFrom(payload, [
        'academicSession',
        'academic_session',
      ]);
      final className = _stringFrom(payload, ['className', 'class_name']);
      final sectionName = _stringFrom(payload, ['sectionName', 'section_name']);
      final rollNo = _stringFrom(payload, ['rollNo', 'roll_no']);
      final isActive = _boolFrom(payload, ['isActive', 'is_active']) ?? true;
      final source = _stringFrom(payload, ['source'], fallback: 'local');
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: studentClassRollsCollection,
        externalId: classRollId,
        body: {
          'class_roll_id': classRollId,
          'tenant_id': tenantId,
          'student_id': studentId,
          'academic_session': academicSession,
          'class_name': className,
          'section_name': sectionName,
          'roll_no': rollNo,
          'is_active': isActive,
          'source': source,
          'updated_at': updatedAt,
          'operation': operation,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullStudentClassRolls({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      studentClassRollsCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  Future<bool> pushFeeInvoice({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final recordId = _stringFrom(payload, ['recordId', 'record_id', 'id']);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      final studentId = _stringFrom(payload, ['studentId', 'student_id']);
      if (recordId.isEmpty || tenantId.isEmpty || studentId.isEmpty) {
        return false;
      }

      final invoiceNo = _stringFrom(payload, [
        'invoiceNo',
        'invoice_no',
      ], fallback: recordId);
      final amountDue = _doubleFrom(payload, ['amountDue', 'amount_due']) ?? 0;
      final amountPaid =
          _doubleFrom(payload, ['amountPaid', 'amount_paid']) ?? 0;
      final status = _stringFrom(payload, ['status'], fallback: 'due');
      final dueDate = _stringFrom(payload, ['dueDate', 'due_date']);
      final source = _stringFrom(payload, ['source'], fallback: 'local');
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: feeInvoicesCollection,
        externalId: recordId,
        body: {
          'record_id': recordId,
          'tenant_id': tenantId,
          'student_id': studentId,
          'invoice_no': invoiceNo,
          'amount_due': amountDue,
          'amount_paid': amountPaid,
          'status': status,
          'due_date': dueDate,
          'source': source,
          'updated_at': updatedAt,
          'operation': operation,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullFeeInvoices({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      feeInvoicesCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  Future<bool> pushFeePayment({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final paymentId = _stringFrom(payload, ['paymentId', 'payment_id', 'id']);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      final invoiceId = _stringFrom(payload, ['invoiceId', 'invoice_id']);
      final studentId = _stringFrom(payload, ['studentId', 'student_id']);

      if (paymentId.isEmpty ||
          tenantId.isEmpty ||
          invoiceId.isEmpty ||
          studentId.isEmpty) {
        return false;
      }

      final amount = _doubleFrom(payload, ['amount']) ?? 0;
      final paidAt = _stringFrom(payload, [
        'paidAt',
        'paid_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());
      final paymentMethod = _stringFrom(payload, [
        'paymentMethod',
        'payment_method',
      ], fallback: 'cash');
      final referenceNo = _stringFrom(payload, ['referenceNo', 'reference_no']);
      final source = _stringFrom(payload, ['source'], fallback: 'local');
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: feePaymentsCollection,
        externalId: paymentId,
        body: {
          'payment_id': paymentId,
          'tenant_id': tenantId,
          'invoice_id': invoiceId,
          'student_id': studentId,
          'amount': amount,
          'paid_at': paidAt,
          'payment_method': paymentMethod,
          'reference_no': referenceNo,
          'source': source,
          'updated_at': updatedAt,
          'operation': operation,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullFeePayments({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      feePaymentsCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  Future<bool> pushLeaveRequest({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final leaveId = _stringFrom(payload, ['leaveId', 'leave_id', 'id']);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      if (leaveId.isEmpty || tenantId.isEmpty) {
        return false;
      }

      if (operation == 'delete') {
        return _deleteByExternalId(
          collection: leaveRequestsCollection,
          externalId: leaveId,
        );
      }

      final requesterId = _stringFrom(payload, ['requesterId', 'requester_id']);
      final leaveFrom = _stringFrom(payload, ['leaveFrom', 'leave_from']);
      final leaveTo = _stringFrom(payload, ['leaveTo', 'leave_to']);
      final appliedAt = _stringFrom(payload, ['appliedAt', 'applied_at']);
      final reason = _stringFrom(payload, ['reason']);
      final statusLabel = _stringFrom(payload, [
        'statusLabel',
        'status_label',
      ], fallback: 'pending');
      final approverName = _stringFrom(payload, [
        'approverName',
        'approver_name',
      ]);
      final approvedAt = _stringFrom(payload, ['approvedAt', 'approved_at']);
      final attachmentUrl = _stringFrom(payload, [
        'attachmentUrl',
        'attachment_url',
      ]);
      final isActive = _boolFrom(payload, ['isActive', 'is_active']) ?? true;
      final source = _stringFrom(payload, ['source'], fallback: 'local');
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: leaveRequestsCollection,
        externalId: leaveId,
        body: {
          'leave_id': leaveId,
          'tenant_id': tenantId,
          'requester_id': requesterId,
          'leave_from': leaveFrom,
          'leave_to': leaveTo,
          'applied_at': appliedAt,
          'reason': reason,
          'status_label': statusLabel,
          'approver_name': approverName,
          'approved_at': approvedAt,
          'attachment_url': attachmentUrl,
          'is_active': isActive,
          'source': source,
          'updated_at': updatedAt,
          'operation': operation,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullLeaveRequests({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      leaveRequestsCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  Future<bool> pushPendingTask({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final taskId = _stringFrom(payload, ['taskId', 'task_id', 'id']);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      if (taskId.isEmpty || tenantId.isEmpty) {
        return false;
      }

      if (operation == 'delete') {
        return _deleteByExternalId(
          collection: pendingTasksCollection,
          externalId: taskId,
        );
      }

      final userId = _stringFrom(payload, ['userId', 'user_id']);
      final title = _stringFrom(payload, ['title'], fallback: 'Task');
      final dueDate = _stringFrom(payload, ['dueDate', 'due_date']);
      final statusLabel = _stringFrom(payload, [
        'statusLabel',
        'status_label',
      ], fallback: 'pending');
      final isCompleted =
          _boolFrom(payload, ['isCompleted', 'is_completed']) ?? false;
      final priority = _stringFrom(payload, ['priority'], fallback: 'medium');
      final isActive = _boolFrom(payload, ['isActive', 'is_active']) ?? true;
      final source = _stringFrom(payload, ['source'], fallback: 'local');
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: pendingTasksCollection,
        externalId: taskId,
        body: {
          'task_id': taskId,
          'tenant_id': tenantId,
          'user_id': userId,
          'title': title,
          'due_date': dueDate,
          'status_label': statusLabel,
          'is_completed': isCompleted,
          'priority': priority,
          'is_active': isActive,
          'source': source,
          'updated_at': updatedAt,
          'operation': operation,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullPendingTasks({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      pendingTasksCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  Future<bool> pushHostelRoom({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final roomId = _stringFrom(payload, ['roomId', 'room_id', 'id']);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      if (roomId.isEmpty || tenantId.isEmpty) {
        return false;
      }

      if (operation == 'delete') {
        return _deleteByExternalId(
          collection: hostelRoomsCollection,
          externalId: roomId,
        );
      }

      final studentId = _stringFrom(payload, ['studentId', 'student_id']);
      final hostelName = _stringFrom(payload, ['hostelName', 'hostel_name']);
      final roomNo = _stringFrom(payload, ['roomNo', 'room_no']);
      final roomType = _stringFrom(payload, ['roomType', 'room_type']);
      final floorNo = _stringFrom(payload, ['floorNo', 'floor_no']);
      final bedNo = _stringFrom(payload, ['bedNo', 'bed_no']);
      final wardenName = _stringFrom(payload, ['wardenName', 'warden_name']);
      final wardenContact = _stringFrom(payload, [
        'wardenContact',
        'warden_contact',
      ]);
      final monthlyFees =
          _doubleFrom(payload, ['monthlyFees', 'monthly_fees']) ?? 0;
      final isActive = _boolFrom(payload, ['isActive', 'is_active']) ?? true;
      final source = _stringFrom(payload, ['source'], fallback: 'local');
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: hostelRoomsCollection,
        externalId: roomId,
        body: {
          'room_id': roomId,
          'tenant_id': tenantId,
          'student_id': studentId,
          'hostel_name': hostelName,
          'room_no': roomNo,
          'room_type': roomType,
          'floor_no': floorNo,
          'bed_no': bedNo,
          'warden_name': wardenName,
          'warden_contact': wardenContact,
          'monthly_fees': monthlyFees,
          'is_active': isActive,
          'source': source,
          'updated_at': updatedAt,
          'operation': operation,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullHostelRooms({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      hostelRoomsCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  Future<bool> pushExamSchedule({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final scheduleId = _stringFrom(payload, [
        'scheduleId',
        'schedule_id',
        'id',
      ]);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      if (scheduleId.isEmpty || tenantId.isEmpty) {
        return false;
      }

      if (operation == 'delete') {
        return _deleteByExternalId(
          collection: examSchedulesCollection,
          externalId: scheduleId,
        );
      }

      final examName = _stringFrom(payload, [
        'examName',
        'exam_name',
      ], fallback: 'Untitled Exam');
      final subjectName = _stringFrom(payload, [
        'subjectName',
        'subject_name',
      ], fallback: 'General');
      final maxMarks = _doubleFrom(payload, ['maxMarks', 'max_marks']) ?? 100;
      final examDate = _stringFrom(payload, [
        'examDate',
        'exam_date',
      ], fallback: DateTime.now().toUtc().toIso8601String());
      final source = _stringFrom(payload, ['source'], fallback: 'local');
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: examSchedulesCollection,
        externalId: scheduleId,
        body: {
          'schedule_id': scheduleId,
          'tenant_id': tenantId,
          'exam_name': examName,
          'subject_name': subjectName,
          'max_marks': maxMarks,
          'exam_date': examDate,
          'source': source,
          'updated_at': updatedAt,
          'operation': operation,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullExamSchedules({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      examSchedulesCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  Future<bool> pushStudentExamMark({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final markId = _stringFrom(payload, ['markId', 'mark_id', 'id']);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);

      if (markId.isEmpty || tenantId.isEmpty) {
        return false;
      }

      if (operation == 'delete') {
        return _deleteByExternalId(
          collection: studentExamMarksCollection,
          externalId: markId,
        );
      }

      final studentId = _stringFrom(payload, ['studentId', 'student_id']);
      final scheduleId = _stringFrom(payload, ['scheduleId', 'schedule_id']);

      if (studentId.isEmpty || scheduleId.isEmpty) {
        return false;
      }

      final marksObtained =
          _doubleFrom(payload, ['marksObtained', 'marks_obtained']) ?? 0;
      final grade = _stringFrom(payload, ['grade']);
      final source = _stringFrom(payload, ['source'], fallback: 'local');
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: studentExamMarksCollection,
        externalId: markId,
        body: {
          'mark_id': markId,
          'tenant_id': tenantId,
          'student_id': studentId,
          'schedule_id': scheduleId,
          'marks_obtained': marksObtained,
          'grade': grade,
          'source': source,
          'updated_at': updatedAt,
          'operation': operation,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullStudentExamMarks({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      studentExamMarksCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  Future<bool> _deleteByExternalId({
    required String collection,
    required String externalId,
  }) async {
    var attemptedRequest = false;
    final escapedId = externalId.replaceAll('"', r'\"');
    final filter = 'external_id = "$escapedId"';

    try {
      attemptedRequest = true;
      final existing = await _client
          .collection(collection)
          .getList(page: 1, perPage: 1, filter: filter);

      if (existing.items.isNotEmpty) {
        await _client.collection(collection).delete(existing.items.first.id);
        return true;
      }
    } catch (_) {
      // Fall through to direct-id deletion fallback.
    }

    try {
      attemptedRequest = true;
      await _client.collection(collection).delete(externalId);
      return true;
    } catch (_) {
      // If a request was attempted and still failed, propagate failure.
    }

    return !attemptedRequest;
  }

  // ── Homework Submissions ──────────────────────────────────────────────────

  Future<bool> pushHomeworkSubmission({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final submissionId = _stringFrom(payload, [
        'submissionId',
        'submission_id',
        'id',
      ]);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      if (submissionId.isEmpty || tenantId.isEmpty) return false;

      if (operation == 'delete') {
        return _deleteByExternalId(
          collection: homeworkSubmissionsCollection,
          externalId: submissionId,
        );
      }

      final assignmentId = _stringFrom(payload, [
        'assignmentId',
        'assignment_id',
      ]);
      final studentId = _stringFrom(payload, ['studentId', 'student_id']);
      final submissionText = _stringFrom(payload, [
        'submissionText',
        'submission_text',
      ]);
      final attachmentUrl = _stringFrom(payload, [
        'attachmentUrl',
        'attachment_url',
      ]);
      final statusLabel = _stringFrom(payload, [
        'statusLabel',
        'status_label',
      ], fallback: 'submitted');
      final teacherFeedback = _stringFrom(payload, [
        'teacherFeedback',
        'teacher_feedback',
      ]);
      final gradeScore = _doubleFrom(payload, ['gradeScore', 'grade_score']);
      final submittedAt = _stringFrom(payload, ['submittedAt', 'submitted_at']);
      final reviewedAt = _stringFrom(payload, ['reviewedAt', 'reviewed_at']);
      final isActive = _boolFrom(payload, ['isActive', 'is_active']) ?? true;
      final source = _stringFrom(payload, ['source'], fallback: 'local');
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: homeworkSubmissionsCollection,
        externalId: submissionId,
        body: {
          'submission_id': submissionId,
          'tenant_id': tenantId,
          'assignment_id': assignmentId,
          'student_id': studentId,
          'submission_text': submissionText,
          'attachment_url': attachmentUrl,
          'status_label': statusLabel,
          'teacher_feedback': teacherFeedback,
          'grade_score': gradeScore,
          'submitted_at': submittedAt,
          'reviewed_at': reviewedAt,
          'is_active': isActive,
          'source': source,
          'updated_at': updatedAt,
          'operation': operation,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullHomeworkSubmissions({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      homeworkSubmissionsCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  // ── Online Learning Attempts ──────────────────────────────────────────────

  Future<bool> pushOnlineLearningAttempt({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final attemptId = _stringFrom(payload, [
        'attemptId',
        'attempt_id',
        'id',
      ]);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      if (attemptId.isEmpty || tenantId.isEmpty) return false;

      if (operation == 'delete') {
        return _deleteByExternalId(
          collection: onlineLearningAttemptsCollection,
          externalId: attemptId,
        );
      }

      final itemId = _stringFrom(payload, ['itemId', 'item_id']);
      final studentId = _stringFrom(payload, ['studentId', 'student_id']);
      final attemptStatus = _stringFrom(payload, [
        'attemptStatus',
        'attempt_status',
      ], fallback: 'in_progress');
      final scorePercent = _doubleFrom(payload, [
        'scorePercent',
        'score_percent',
      ]);
      final durationSeconds = _intFrom(payload, [
        'durationSeconds',
        'duration_seconds',
      ]);
      final startedAt = _stringFrom(payload, ['startedAt', 'started_at']);
      final completedAt = _stringFrom(payload, ['completedAt', 'completed_at']);
      final isPassed = _boolFrom(payload, ['isPassed', 'is_passed']) ?? false;
      final isActive = _boolFrom(payload, ['isActive', 'is_active']) ?? true;
      final source = _stringFrom(payload, ['source'], fallback: 'local');
      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: onlineLearningAttemptsCollection,
        externalId: attemptId,
        body: {
          'attempt_id': attemptId,
          'tenant_id': tenantId,
          'item_id': itemId,
          'student_id': studentId,
          'attempt_status': attemptStatus,
          'score_percent': scorePercent,
          'duration_seconds': durationSeconds,
          'started_at': startedAt,
          'completed_at': completedAt,
          'is_passed': isPassed,
          'is_active': isActive,
          'source': source,
          'updated_at': updatedAt,
          'operation': operation,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullOnlineLearningAttempts({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(
      onlineLearningAttemptsCollection,
      since: since,
      tenantId: tenantId,
    );
  }

  Future<void> _upsertByExternalId({
    required String collection,
    required String externalId,
    required Map<String, dynamic> body,
  }) async {
    final escapedId = externalId.replaceAll('"', r'\"');
    final filter = 'external_id = "$escapedId"';

    try {
      final existing = await _client
          .collection(collection)
          .getList(page: 1, perPage: 1, filter: filter);

      if (existing.items.isNotEmpty) {
        await _client
            .collection(collection)
            .update(existing.items.first.id, body: body);
        return;
      }
    } catch (_) {
      // Best-effort path: some collections may not expose external_id filters yet.
    }

    try {
      await _client
          .collection(collection)
          .create(body: {...body, 'external_id': externalId});
      return;
    } catch (_) {
      // Fallback: if external_id is not configured as a field, try update/create by id.
    }

    try {
      await _client.collection(collection).update(externalId, body: body);
    } catch (_) {
      await _client.collection(collection).create(body: body);
    }
  }

  Future<List<Map<String, dynamic>>> _pullCollection(
    String collection, {
    DateTime? since,
    String? tenantId,
  }) async {
    try {
      final filters = <String>[];
      if (since != null) {
        filters.add('updated_at > "${since.toUtc().toIso8601String()}"');
      }
      if (tenantId != null && tenantId.trim().isNotEmpty) {
        final escapedTenantId = tenantId.replaceAll('"', r'\"');
        filters.add('tenant_id = "$escapedTenantId"');
      }

      final filter = filters.isEmpty ? null : filters.join(' && ');

      final records = await _client
          .collection(collection)
          .getFullList(filter: filter, sort: '+updated_at');

      return records.map((record) => record.toJson()).toList();
    } catch (_) {
      return const [];
    }
  }

  String _stringFrom(
    Map<String, dynamic> source,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final raw = source[key];
      if (raw == null) continue;
      final text = raw.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return fallback;
  }

  int? _intFrom(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final raw = source[key];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw == null) continue;
      final parsed = int.tryParse(raw.toString());
      if (parsed != null) return parsed;
    }
    return null;
  }

  double? _doubleFrom(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final raw = source[key];
      if (raw is double) return raw;
      if (raw is num) return raw.toDouble();
      if (raw == null) continue;
      final parsed = double.tryParse(raw.toString());
      if (parsed != null) return parsed;
    }
    return null;
  }

  bool? _boolFrom(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final raw = source[key];
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      if (raw == null) continue;

      final normalized = raw.toString().trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return null;
  }

  // ── Fee Groups ────────────────────────────────────────────────────────────

  Future<bool> pushFeeGroup({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final feeId = _stringFrom(payload, ['feeId', 'fee_id', 'id']);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      if (feeId.isEmpty || tenantId.isEmpty) return false;

      if (operation == 'delete') {
        return _deleteByExternalId(
          collection: feeGroupsCollection,
          externalId: feeId,
        );
      }

      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: feeGroupsCollection,
        externalId: feeId,
        body: {
          'fee_id': feeId,
          'tenant_id': tenantId,
          'student_id': _stringFrom(payload, ['studentId', 'student_id']),
          'fee_title': _stringFrom(payload, ['feeTitle', 'fee_title'], fallback: 'Fee'),
          'fee_code': _stringFrom(payload, ['feeCode', 'fee_code']),
          'amount': _doubleFrom(payload, ['amount']) ?? 0,
          'discount': _doubleFrom(payload, ['discount']) ?? 0,
          'fine': _doubleFrom(payload, ['fine']) ?? 0,
          'paid': _doubleFrom(payload, ['paid']) ?? 0,
          'balance': _doubleFrom(payload, ['balance']) ?? 0,
          'status': _stringFrom(payload, ['status'], fallback: 'unpaid'),
          'due_date': _stringFrom(payload, ['dueDate', 'due_date']),
          'is_payable': _boolFrom(payload, ['isPayable', 'is_payable']) ?? false,
          'fee_type': _stringFrom(payload, ['feeType', 'fee_type'], fallback: 'fee'),
          'updated_at': updatedAt,
          'operation': operation,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullFeeGroups({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(feeGroupsCollection, since: since, tenantId: tenantId);
  }

  // ── CBSE Exam Results ─────────────────────────────────────────────────────

  Future<bool> pushCbseExamResult({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final resultId = _stringFrom(payload, ['resultId', 'result_id', 'id']);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      if (resultId.isEmpty || tenantId.isEmpty) return false;

      if (operation == 'delete') {
        return _deleteByExternalId(
          collection: cbseExamResultsCollection,
          externalId: resultId,
        );
      }

      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: cbseExamResultsCollection,
        externalId: resultId,
        body: {
          'result_id': resultId,
          'tenant_id': tenantId,
          'student_id': _stringFrom(payload, ['studentId', 'student_id']),
          'exam_name': _stringFrom(payload, ['examName', 'exam_name'], fallback: 'Exam'),
          'subject_name': _stringFrom(payload, ['subjectName', 'subject_name']),
          'subject_code': _stringFrom(payload, ['subjectCode', 'subject_code']),
          'assessment_name': _stringFrom(payload, ['assessmentName', 'assessment_name']),
          'marks_obtained': _doubleFrom(payload, ['marksObtained', 'marks_obtained']),
          'max_marks': _doubleFrom(payload, ['maxMarks', 'max_marks']),
          'exam_date': _stringFrom(payload, ['examDate', 'exam_date']),
          'grade': _stringFrom(payload, ['grade']),
          'rank': _stringFrom(payload, ['rank']),
          'percentage': _stringFrom(payload, ['percentage']),
          'result_type': _stringFrom(payload, ['resultType', 'result_type'], fallback: 'result'),
          'updated_at': updatedAt,
          'operation': operation,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullCbseExamResults({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(cbseExamResultsCollection, since: since, tenantId: tenantId);
  }

  // ── Online Exams ──────────────────────────────────────────────────────────

  Future<bool> pushOnlineExam({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final examId = _stringFrom(payload, ['examId', 'exam_id', 'id']);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      if (examId.isEmpty || tenantId.isEmpty) return false;

      if (operation == 'delete') {
        return _deleteByExternalId(
          collection: onlineExamsCollection,
          externalId: examId,
        );
      }

      final updatedAt = _stringFrom(payload, [
        'updatedAt',
        'updated_at',
      ], fallback: DateTime.now().toUtc().toIso8601String());

      await _upsertByExternalId(
        collection: onlineExamsCollection,
        externalId: examId,
        body: {
          'exam_id': examId,
          'tenant_id': tenantId,
          'exam_title': _stringFrom(payload, ['examTitle', 'exam_title'], fallback: 'Exam'),
          'description': _stringFrom(payload, ['description']),
          'exam_from': _stringFrom(payload, ['examFrom', 'exam_from']),
          'exam_to': _stringFrom(payload, ['examTo', 'exam_to']),
          'total_questions': _intFrom(payload, ['totalQuestions', 'total_questions']) ?? 0,
          'total_attempt': _intFrom(payload, ['totalAttempt', 'total_attempt']) ?? 1,
          'duration_minutes': _intFrom(payload, ['durationMinutes', 'duration_minutes']) ?? 0,
          'passing_percent': _doubleFrom(payload, ['passingPercent', 'passing_percent']) ?? 35,
          'is_quiz': _boolFrom(payload, ['isQuiz', 'is_quiz']) ?? false,
          'status_label': _stringFrom(payload, ['statusLabel', 'status_label'], fallback: 'upcoming'),
          'attempt_count': _intFrom(payload, ['attemptCount', 'attempt_count']) ?? 0,
          'is_submitted': _boolFrom(payload, ['isSubmitted', 'is_submitted']) ?? false,
          'last_score_percent': _doubleFrom(payload, ['lastScorePercent', 'last_score_percent']),
          'is_passed': _boolFrom(payload, ['isPassed', 'is_passed']) ?? false,
          'is_active': _boolFrom(payload, ['isActive', 'is_active']) ?? true,
          'updated_at': updatedAt,
          'operation': operation,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullOnlineExams({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(onlineExamsCollection, since: since, tenantId: tenantId);
  }

  // ── Student Behaviour ─────────────────────────────────────────────────────

  Future<bool> pushStudentBehaviour({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final incidentId = _stringFrom(payload, ['incidentId', 'incident_id', 'id']);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      if (incidentId.isEmpty || tenantId.isEmpty) return false;
      if (operation == 'delete') {
        return _deleteByExternalId(collection: studentBehaviourCollection, externalId: incidentId);
      }
      await _upsertByExternalId(
        collection: studentBehaviourCollection,
        externalId: incidentId,
        body: {
          'incident_id': incidentId,
          'tenant_id': tenantId,
          'student_id': _stringFrom(payload, ['studentId', 'student_id']),
          'title': _stringFrom(payload, ['title'], fallback: 'Incident'),
          'description': _stringFrom(payload, ['description']),
          'point': _stringFrom(payload, ['point'], fallback: '0'),
          'is_positive': _boolFrom(payload, ['isPositive', 'is_positive']) ?? true,
          'assigned_by': _stringFrom(payload, ['assignedBy', 'assigned_by']),
          'incident_date': _stringFrom(payload, ['incidentDate', 'incident_date']),
          'updated_at': _stringFrom(payload, ['updatedAt', 'updated_at'],
              fallback: DateTime.now().toUtc().toIso8601String()),
          'operation': operation,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullStudentBehaviour({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(studentBehaviourCollection, since: since, tenantId: tenantId);
  }

  Future<bool> pushBehaviourComment({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final commentId = _stringFrom(payload, ['commentId', 'comment_id', 'id']);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      if (commentId.isEmpty || tenantId.isEmpty) return false;
      if (operation == 'delete') {
        return _deleteByExternalId(collection: behaviourCommentsCollection, externalId: commentId);
      }
      await _upsertByExternalId(
        collection: behaviourCommentsCollection,
        externalId: commentId,
        body: {
          'comment_id': commentId,
          'tenant_id': tenantId,
          'incident_id': _stringFrom(payload, ['incidentId', 'incident_id']),
          'comment_text': _stringFrom(payload, ['commentText', 'comment_text']),
          'commented_by': _stringFrom(payload, ['commentedBy', 'commented_by']),
          'comment_date': _stringFrom(payload, ['commentDate', 'comment_date']),
          'updated_at': _stringFrom(payload, ['updatedAt', 'updated_at'],
              fallback: DateTime.now().toUtc().toIso8601String()),
          'operation': operation,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullBehaviourComments({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(behaviourCommentsCollection, since: since, tenantId: tenantId);
  }

  // ── Teachers ──────────────────────────────────────────────────────────────

  Future<bool> pushTeacher({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final teacherId = _stringFrom(payload, ['teacherId', 'teacher_id', 'id']);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      if (teacherId.isEmpty || tenantId.isEmpty) return false;
      if (operation == 'delete') {
        return _deleteByExternalId(collection: teachersCollection, externalId: teacherId);
      }
      await _upsertByExternalId(
        collection: teachersCollection,
        externalId: teacherId,
        body: {
          'teacher_id': teacherId,
          'tenant_id': tenantId,
          'full_name': _stringFrom(payload, ['fullName', 'full_name'], fallback: 'Teacher'),
          'employee_no': _stringFrom(payload, ['employeeNo', 'employee_no']),
          'subject_name': _stringFrom(payload, ['subjectName', 'subject_name']),
          'qualification': _stringFrom(payload, ['qualification']),
          'email': _stringFrom(payload, ['email']),
          'phone': _stringFrom(payload, ['phone']),
          'designation': _stringFrom(payload, ['designation']),
          'is_class_teacher': _boolFrom(payload, ['isClassTeacher', 'is_class_teacher']) ?? false,
          'image_url': _stringFrom(payload, ['imageUrl', 'image_url']),
          'rating_score': _intFrom(payload, ['ratingScore', 'rating_score']) ?? 0,
          'review_comment': _stringFrom(payload, ['reviewComment', 'review_comment']),
          'has_reviewed': _boolFrom(payload, ['hasReviewed', 'has_reviewed']) ?? false,
          'is_active': _boolFrom(payload, ['isActive', 'is_active']) ?? true,
          'updated_at': _stringFrom(payload, ['updatedAt', 'updated_at'],
              fallback: DateTime.now().toUtc().toIso8601String()),
          'operation': operation,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullTeachers({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(teachersCollection, since: since, tenantId: tenantId);
  }

  // ── Online Lessons ────────────────────────────────────────────────────────

  Future<bool> pushOnlineLesson({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final lessonId = _stringFrom(payload, ['lessonId', 'lesson_id', 'id']);
      final tenantId = _stringFrom(payload, ['tenantId', 'tenant_id']);
      if (lessonId.isEmpty || tenantId.isEmpty) return false;
      if (operation == 'delete') {
        return _deleteByExternalId(collection: onlineLessonsCollection, externalId: lessonId);
      }
      await _upsertByExternalId(
        collection: onlineLessonsCollection,
        externalId: lessonId,
        body: {
          'lesson_id': lessonId,
          'tenant_id': tenantId,
          'item_id': _stringFrom(payload, ['itemId', 'item_id']),
          'title': _stringFrom(payload, ['title'], fallback: 'Lesson'),
          'content_type': _stringFrom(payload, ['contentType', 'content_type'], fallback: 'video'),
          'content_url': _stringFrom(payload, ['contentUrl', 'content_url']),
          'description': _stringFrom(payload, ['description']),
          'sort_order': _intFrom(payload, ['sortOrder', 'sort_order']) ?? 0,
          'duration_seconds': _intFrom(payload, ['durationSeconds', 'duration_seconds']) ?? 0,
          'is_completed': _boolFrom(payload, ['isCompleted', 'is_completed']) ?? false,
          'is_active': _boolFrom(payload, ['isActive', 'is_active']) ?? true,
          'updated_at': _stringFrom(payload, ['updatedAt', 'updated_at'],
              fallback: DateTime.now().toUtc().toIso8601String()),
          'operation': operation,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullOnlineLessons({
    DateTime? since,
    String? tenantId,
  }) {
    return _pullCollection(onlineLessonsCollection, since: since, tenantId: tenantId);
  }

  AuthSession? _sessionFromModel(Map<String, dynamic> authModel) {
    final merged = Map<String, dynamic>.from(authModel);
    final nestedData = authModel['data'];
    if (nestedData is Map<String, dynamic>) {
      merged.addAll(nestedData);
    } else if (nestedData is Map) {
      merged.addAll(
        nestedData.map((key, value) => MapEntry(key.toString(), value)),
      );
    }

    final userId = _stringFrom(merged, ['id', 'user_id']);
    final email = _stringFrom(merged, ['email', 'username', 'identity']);
    final isSuperAdmin =
        _boolFrom(merged, ['is_superadmin', 'isSuperAdmin']) ?? false;

    var tenantId = _stringFrom(merged, ['tenant_id', 'tenantId']);
    if (tenantId.isEmpty && isSuperAdmin) {
      tenantId = 'global';
    }

    if (tenantId.isEmpty) {
      return null;
    }

    var tenantName = _stringFrom(merged, [
      'tenant_name',
      'tenantName',
      'school_name',
      'schoolName',
    ]);
    if (tenantName.isEmpty) {
      tenantName = isSuperAdmin ? 'Global Superadmin' : tenantId;
    }

    var role = _stringFrom(merged, ['role']);
    if (role.isEmpty) {
      role = isSuperAdmin ? 'superadmin' : 'school_owner';
    }

    return AuthSession(
      userId: userId,
      email: email,
      tenantId: tenantId,
      tenantName: tenantName,
      role: role,
      isSuperAdmin: isSuperAdmin,
    );
  }

  Map<String, dynamic>? _recordToMap(dynamic model) {
    if (model == null) {
      return null;
    }

    if (model is Map<String, dynamic>) {
      return Map<String, dynamic>.from(model);
    }

    if (model is Map) {
      return model.map((key, value) => MapEntry(key.toString(), value));
    }

    try {
      final dynamic json = (model as dynamic).toJson();
      if (json is Map<String, dynamic>) {
        return Map<String, dynamic>.from(json);
      }
      if (json is Map) {
        return json.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      return null;
    }

    return null;
  }
}
