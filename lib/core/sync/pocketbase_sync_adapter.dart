import 'dart:convert';

import '../database/local_database.dart';
import '../remote/pocketbase_gateway.dart';

class PocketbaseSyncAdapter {
  PocketbaseSyncAdapter({
    required this.database,
    required this.pocketbaseGateway,
  });

  static const String _tenantLicenseCheckpointKey = 'tenant_license';
  static const String _tenantUsageMetricCheckpointKey = 'tenant_usage_metric';
  static const String _tenantFeatureFlagCheckpointKey = 'tenant_feature_flag';
  static const String _noticeBoardCheckpointKey = 'notice_board';
  static const String _timetableSlotCheckpointKey = 'timetable_slot';
  static const String _transportRouteCheckpointKey = 'transport_route';
  static const String _homeworkAssignmentCheckpointKey = 'homework_assignment';
  static const String _onlineLearningItemCheckpointKey = 'online_learning_item';
  static const String _lessonCheckpointKey = 'lesson';
  static const String _lessonPlanCheckpointKey = 'lesson_plan';
  static const String _subjectCheckpointKey = 'subject';
  static const String _syllabusCheckpointKey = 'syllabus';
  static const String _libraryItemCheckpointKey = 'library_item';
  static const String _documentCenterItemCheckpointKey = 'document_center_item';
  static const String _visitorCommunicationCheckpointKey =
      'visitor_communication';
  static const String _notificationCheckpointKey = 'notification';
  static const String _liveClassCheckpointKey = 'live_class';
  static const String _schoolOwnerCheckpointKey = 'school_owner';
  static const String _studentProfileCheckpointKey = 'student_profile';
  static const String _studentGuardianCheckpointKey = 'student_guardian';
  static const String _studentEnrollmentCheckpointKey = 'student_enrollment';
  static const String _studentClassRollCheckpointKey = 'student_class_roll';
  static const String _studentAttendanceCheckpointKey = 'student_attendance';
  static const String _leaveRequestCheckpointKey = 'leave_request';
  static const String _pendingTaskCheckpointKey = 'pending_task';
  static const String _hostelRoomCheckpointKey = 'hostel_room';
  static const String _feeInvoiceCheckpointKey = 'fee_invoice';
  static const String _feePaymentCheckpointKey = 'fee_payment';
  static const String _examScheduleCheckpointKey = 'exam_schedule';
  static const String _examMarkCheckpointKey = 'exam_mark';
  static const String _homeworkSubmissionCheckpointKey = 'homework_submission';
  static const String _onlineLearningAttemptCheckpointKey = 'online_learning_attempt';
  static const String _feeGroupCheckpointKey = 'fee_group';
  static const String _cbseExamResultCheckpointKey = 'cbse_exam_result';
  static const String _onlineExamCheckpointKey = 'online_exam';
  static const String _studentBehaviourCheckpointKey = 'student_behaviour';
  static const String _behaviourCommentCheckpointKey = 'behaviour_comment';
  static const String _teacherCheckpointKey = 'teacher';
  static const String _onlineLessonCheckpointKey = 'online_lesson';

  final AppLocalDatabase database;
  final PocketbaseGateway pocketbaseGateway;

  Future<int> pushPendingQueue({int limit = 25, String? scopedTenantId}) async {
    final pendingRows = await database.getSyncQueueDispatchBatch(
      limit: limit,
      tenantId: scopedTenantId,
    );
    int successCount = 0;

    for (final row in pendingRows) {
      bool success = false;

      try {
        final payloadRaw = jsonDecode(row.payload);
        final payload = payloadRaw is Map<String, dynamic>
            ? payloadRaw
            : Map<String, dynamic>.from(payloadRaw as Map);

        if (await _isStaleQueueRow(row, payload)) {
          await database.markSyncQueueEntrySynced(entryId: row.id);
          successCount++;
          continue;
        }

        success = await _pushQueueRow(row, payload);
      } catch (_) {
        success = false;
      }

      if (success) {
        await database.markSyncQueueEntrySynced(entryId: row.id);
        successCount++;
      } else {
        await database.markSyncQueueEntryFailed(
          entryId: row.id,
          currentRetryCount: row.retryCount,
        );
      }
    }

    return successCount;
  }

  Future<int> pullLatest({String? scopedTenantId}) async {
    int upsertCount = 0;
    upsertCount += await _pullTenantLicenses(scopedTenantId: scopedTenantId);
    upsertCount += await _pullTenantUsageMetrics(
      scopedTenantId: scopedTenantId,
    );
    upsertCount += await _pullTenantFeatureFlags(
      scopedTenantId: scopedTenantId,
    );
    upsertCount += await _pullNoticeBoards(scopedTenantId: scopedTenantId);
    upsertCount += await _pullTimetableSlots(scopedTenantId: scopedTenantId);
    upsertCount += await _pullTransportRoutes(scopedTenantId: scopedTenantId);
    upsertCount += await _pullHomeworkAssignments(
      scopedTenantId: scopedTenantId,
    );
    upsertCount += await _pullOnlineLearningItems(
      scopedTenantId: scopedTenantId,
    );
    upsertCount += await _pullLessons(scopedTenantId: scopedTenantId);
    upsertCount += await _pullLessonPlans(scopedTenantId: scopedTenantId);
    upsertCount += await _pullSubjects(scopedTenantId: scopedTenantId);
    upsertCount += await _pullSyllabusItems(scopedTenantId: scopedTenantId);
    upsertCount += await _pullLibraryItems(scopedTenantId: scopedTenantId);
    upsertCount += await _pullDocumentCenterItems(
      scopedTenantId: scopedTenantId,
    );
    upsertCount += await _pullVisitorCommunicationEntries(
      scopedTenantId: scopedTenantId,
    );
    upsertCount += await _pullNotifications(scopedTenantId: scopedTenantId);
    upsertCount += await _pullLiveClasses(scopedTenantId: scopedTenantId);
    upsertCount += await _pullSchoolOwners(scopedTenantId: scopedTenantId);
    upsertCount += await _pullStudentProfiles(scopedTenantId: scopedTenantId);
    upsertCount += await _pullStudentGuardians(scopedTenantId: scopedTenantId);
    upsertCount += await _pullStudentEnrollments(
      scopedTenantId: scopedTenantId,
    );
    upsertCount += await _pullStudentClassRolls(scopedTenantId: scopedTenantId);
    upsertCount += await _pullStudentAttendance(scopedTenantId: scopedTenantId);
    upsertCount += await _pullLeaveRequests(scopedTenantId: scopedTenantId);
    upsertCount += await _pullPendingTasks(scopedTenantId: scopedTenantId);
    upsertCount += await _pullHostelRooms(scopedTenantId: scopedTenantId);
    upsertCount += await _pullFeeInvoices(scopedTenantId: scopedTenantId);
    upsertCount += await _pullFeePayments(scopedTenantId: scopedTenantId);
    upsertCount += await _pullExamSchedules(scopedTenantId: scopedTenantId);
    upsertCount += await _pullExamMarks(scopedTenantId: scopedTenantId);
    upsertCount += await _pullHomeworkSubmissions(scopedTenantId: scopedTenantId);
    upsertCount += await _pullOnlineLearningAttempts(scopedTenantId: scopedTenantId);
    upsertCount += await _pullFeeGroups(scopedTenantId: scopedTenantId);
    upsertCount += await _pullCbseExamResults(scopedTenantId: scopedTenantId);
    upsertCount += await _pullOnlineExams(scopedTenantId: scopedTenantId);
    upsertCount += await _pullStudentBehaviour(scopedTenantId: scopedTenantId);
    upsertCount += await _pullBehaviourComments(scopedTenantId: scopedTenantId);
    upsertCount += await _pullTeachers(scopedTenantId: scopedTenantId);
    upsertCount += await _pullOnlineLessons(scopedTenantId: scopedTenantId);
    return upsertCount;
  }

  Future<bool> _pushQueueRow(
    SyncQueueEntry row,
    Map<String, dynamic> payload,
  ) async {
    switch (row.entityType) {
      case 'tenant_license':
        return pocketbaseGateway.pushTenantLicense(
          operation: row.operation,
          payload: payload,
        );
      case 'tenant_feature_flag':
        return pocketbaseGateway.pushTenantFeatureFlag(
          operation: row.operation,
          payload: payload,
        );
      case 'notice_board':
        return pocketbaseGateway.pushNoticeBoard(
          operation: row.operation,
          payload: payload,
        );
      case 'timetable_slot':
        return pocketbaseGateway.pushTimetableSlot(
          operation: row.operation,
          payload: payload,
        );
      case 'transport_route':
        return pocketbaseGateway.pushTransportRoute(
          operation: row.operation,
          payload: payload,
        );
      case 'homework_assignment':
        return pocketbaseGateway.pushHomeworkAssignment(
          operation: row.operation,
          payload: payload,
        );
      case 'online_learning_item':
        return pocketbaseGateway.pushOnlineLearningItem(
          operation: row.operation,
          payload: payload,
        );
      case 'lesson':
        return pocketbaseGateway.pushLesson(
          operation: row.operation,
          payload: payload,
        );
      case 'lesson_plan':
        return pocketbaseGateway.pushLessonPlan(
          operation: row.operation,
          payload: payload,
        );
      case 'subject':
        return pocketbaseGateway.pushSubject(
          operation: row.operation,
          payload: payload,
        );
      case 'syllabus':
        return pocketbaseGateway.pushSyllabus(
          operation: row.operation,
          payload: payload,
        );
      case 'library_item':
        return pocketbaseGateway.pushLibraryItem(
          operation: row.operation,
          payload: payload,
        );
      case 'document_center_item':
        return pocketbaseGateway.pushDocumentCenterItem(
          operation: row.operation,
          payload: payload,
        );
      case 'visitor_communication':
        return pocketbaseGateway.pushVisitorCommunication(
          operation: row.operation,
          payload: payload,
        );
      case 'notification':
        return pocketbaseGateway.pushNotification(
          operation: row.operation,
          payload: payload,
        );
      case 'live_class':
        return pocketbaseGateway.pushLiveClass(
          operation: row.operation,
          payload: payload,
        );
      case 'school_owner':
        return pocketbaseGateway.pushSchoolOwner(
          operation: row.operation,
          payload: payload,
        );
      case 'student_attendance':
        return pocketbaseGateway.pushStudentAttendance(
          operation: row.operation,
          payload: payload,
        );
      case 'student_profile':
        return pocketbaseGateway.pushStudentProfile(
          operation: row.operation,
          payload: payload,
        );
      case 'student_guardian':
        return pocketbaseGateway.pushStudentGuardian(
          operation: row.operation,
          payload: payload,
        );
      case 'student_enrollment':
        return pocketbaseGateway.pushStudentEnrollment(
          operation: row.operation,
          payload: payload,
        );
      case 'student_class_roll':
        return pocketbaseGateway.pushStudentClassRoll(
          operation: row.operation,
          payload: payload,
        );
      case 'leave_request':
        return pocketbaseGateway.pushLeaveRequest(
          operation: row.operation,
          payload: payload,
        );
      case 'pending_task':
        return pocketbaseGateway.pushPendingTask(
          operation: row.operation,
          payload: payload,
        );
      case 'hostel_room':
        return pocketbaseGateway.pushHostelRoom(
          operation: row.operation,
          payload: payload,
        );
      case 'fee_invoice':
        return pocketbaseGateway.pushFeeInvoice(
          operation: row.operation,
          payload: payload,
        );
      case 'fee_payment':
        return pocketbaseGateway.pushFeePayment(
          operation: row.operation,
          payload: payload,
        );
      case 'exam_schedule':
        return pocketbaseGateway.pushExamSchedule(
          operation: row.operation,
          payload: payload,
        );
      case 'exam_mark':
        return pocketbaseGateway.pushStudentExamMark(
          operation: row.operation,
          payload: payload,
        );
      case 'homework_submission':
        return pocketbaseGateway.pushHomeworkSubmission(
          operation: row.operation,
          payload: payload,
        );
      case 'online_learning_attempt':
        return pocketbaseGateway.pushOnlineLearningAttempt(
          operation: row.operation,
          payload: payload,
        );
      case 'fee_group':
        return pocketbaseGateway.pushFeeGroup(
          operation: row.operation,
          payload: payload,
        );
      case 'cbse_exam_result':
        return pocketbaseGateway.pushCbseExamResult(
          operation: row.operation,
          payload: payload,
        );
      case 'online_exam':
        return pocketbaseGateway.pushOnlineExam(
          operation: row.operation,
          payload: payload,
        );
      case 'student_behaviour':
        return pocketbaseGateway.pushStudentBehaviour(
          operation: row.operation,
          payload: payload,
        );
      case 'behaviour_comment':
        return pocketbaseGateway.pushBehaviourComment(
          operation: row.operation,
          payload: payload,
        );
      case 'teacher':
        return pocketbaseGateway.pushTeacher(
          operation: row.operation,
          payload: payload,
        );
      case 'online_lesson':
        return pocketbaseGateway.pushOnlineLesson(
          operation: row.operation,
          payload: payload,
        );
      default:
        // Unknown queue entries are treated as non-dispatchable.
        return false;
    }
  }

  Future<bool> _isStaleQueueRow(
    SyncQueueEntry row,
    Map<String, dynamic> payload,
  ) async {
    final queuedUpdatedAt = _readDate(payload, ['updatedAt', 'updated_at']);
    if (queuedUpdatedAt == null) {
      return false;
    }

    final localUpdatedAt = await database.getEntityUpdatedAt(
      entityType: row.entityType,
      tenantId: row.tenantId,
      entityId: row.entityId,
    );

    if (localUpdatedAt == null) {
      return false;
    }

    return localUpdatedAt.isAfter(queuedUpdatedAt);
  }

  Future<bool> _shouldApplyRemoteRecord({
    required String entityType,
    required String tenantId,
    required String entityId,
    required DateTime remoteUpdatedAt,
  }) async {
    final localUpdatedAt = await database.getEntityUpdatedAt(
      entityType: entityType,
      tenantId: tenantId,
      entityId: entityId,
    );

    if (localUpdatedAt == null) {
      return true;
    }

    // Timestamp policy: keep whichever side has the latest update.
    return !localUpdatedAt.isAfter(remoteUpdatedAt);
  }

  Future<int> _pullExamSchedules({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(
      _examScheduleCheckpointKey,
    );
    final records = await pocketbaseGateway.pullExamSchedules(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapExamScheduleRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'exam_schedule',
        tenantId: mapped.tenantId,
        entityId: mapped.scheduleId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null ||
            mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      if (mapped.isDeleted) {
        await database.deleteExamScheduleCascade(
          tenantId: mapped.tenantId,
          scheduleId: mapped.scheduleId,
        );
      } else {
        await database.upsertExamScheduleRecord(
          scheduleId: mapped.scheduleId,
          tenantId: mapped.tenantId,
          examName: mapped.examName,
          subjectName: mapped.subjectName,
          maxMarks: mapped.maxMarks,
          examDate: mapped.examDate,
          source: mapped.source,
          updatedAt: mapped.updatedAt,
        );
      }

      if (latestTimestamp == null ||
          mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }

      upserts++;
    }

    if (latestTimestamp != null &&
        (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _examScheduleCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  Future<int> _pullExamMarks({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(_examMarkCheckpointKey);
    final records = await pocketbaseGateway.pullStudentExamMarks(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapExamMarkRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'exam_mark',
        tenantId: mapped.tenantId,
        entityId: mapped.markId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null ||
            mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      if (mapped.isDeleted) {
        await database.deleteStudentExamMarkRecord(
          tenantId: mapped.tenantId,
          markId: mapped.markId,
        );
      } else {
        await database.upsertStudentExamMarkRecord(
          markId: mapped.markId,
          tenantId: mapped.tenantId,
          studentId: mapped.studentId,
          scheduleId: mapped.scheduleId,
          marksObtained: mapped.marksObtained,
          grade: mapped.grade,
          source: mapped.source,
          updatedAt: mapped.updatedAt,
        );
      }

      if (latestTimestamp == null ||
          mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }

      upserts++;
    }

    if (latestTimestamp != null &&
        (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _examMarkCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  Future<int> _pullFeePayments({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(
      _feePaymentCheckpointKey,
    );
    final records = await pocketbaseGateway.pullFeePayments(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapFeePaymentRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'fee_payment',
        tenantId: mapped.tenantId,
        entityId: mapped.paymentId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null ||
            mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      await database.upsertFeePaymentRecord(
        paymentId: mapped.paymentId,
        tenantId: mapped.tenantId,
        invoiceId: mapped.invoiceId,
        studentId: mapped.studentId,
        amount: mapped.amount,
        paidAt: mapped.paidAt,
        paymentMethod: mapped.paymentMethod,
        referenceNo: mapped.referenceNo,
        source: mapped.source,
        updatedAt: mapped.updatedAt,
      );

      if (latestTimestamp == null ||
          mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }

      upserts++;
    }

    if (latestTimestamp != null &&
        (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _feePaymentCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  Future<int> _pullFeeInvoices({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(
      _feeInvoiceCheckpointKey,
    );
    final records = await pocketbaseGateway.pullFeeInvoices(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapFeeInvoiceRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'fee_invoice',
        tenantId: mapped.tenantId,
        entityId: mapped.recordId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null ||
            mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      await database.upsertFeeInvoiceRecord(
        recordId: mapped.recordId,
        tenantId: mapped.tenantId,
        studentId: mapped.studentId,
        invoiceNo: mapped.invoiceNo,
        amountDue: mapped.amountDue,
        amountPaid: mapped.amountPaid,
        status: mapped.status,
        dueDate: mapped.dueDate,
        source: mapped.source,
        updatedAt: mapped.updatedAt,
      );

      if (latestTimestamp == null ||
          mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }

      upserts++;
    }

    if (latestTimestamp != null &&
        (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _feeInvoiceCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  Future<int> _pullStudentProfiles({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(
      _studentProfileCheckpointKey,
    );
    final records = await pocketbaseGateway.pullStudentProfiles(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapStudentProfileRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'student_profile',
        tenantId: mapped.tenantId,
        entityId: mapped.studentId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null ||
            mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      await database.upsertStudentProfileFromRemote(
        studentId: mapped.studentId,
        tenantId: mapped.tenantId,
        admissionNo: mapped.admissionNo,
        fullName: mapped.fullName,
        classSection: mapped.classSection,
        isActive: mapped.isActive,
        updatedAt: mapped.updatedAt,
      );

      if (latestTimestamp == null ||
          mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }

      upserts++;
    }

    if (latestTimestamp != null &&
        (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _studentProfileCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  Future<int> _pullStudentGuardians({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(
      _studentGuardianCheckpointKey,
    );
    final records = await pocketbaseGateway.pullStudentGuardians(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapStudentGuardianRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'student_guardian',
        tenantId: mapped.tenantId,
        entityId: mapped.guardianId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null ||
            mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      await database.upsertStudentGuardianRecord(
        guardianId: mapped.guardianId,
        tenantId: mapped.tenantId,
        studentId: mapped.studentId,
        fullName: mapped.fullName,
        relation: mapped.relation,
        phone: mapped.phone,
        email: mapped.email,
        isPrimary: mapped.isPrimary,
        isActive: mapped.isActive,
        source: mapped.source,
        updatedAt: mapped.updatedAt,
      );

      if (latestTimestamp == null ||
          mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }

      upserts++;
    }

    if (latestTimestamp != null &&
        (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _studentGuardianCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  Future<int> _pullStudentEnrollments({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(
      _studentEnrollmentCheckpointKey,
    );
    final records = await pocketbaseGateway.pullStudentEnrollments(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapStudentEnrollmentRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'student_enrollment',
        tenantId: mapped.tenantId,
        entityId: mapped.enrollmentId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null ||
            mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      await database.upsertStudentEnrollmentRecord(
        enrollmentId: mapped.enrollmentId,
        tenantId: mapped.tenantId,
        studentId: mapped.studentId,
        academicSession: mapped.academicSession,
        enrollmentStatus: mapped.enrollmentStatus,
        enrolledOn: mapped.enrolledOn,
        leftOn: mapped.leftOn,
        remarks: mapped.remarks,
        source: mapped.source,
        updatedAt: mapped.updatedAt,
      );

      if (latestTimestamp == null ||
          mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }

      upserts++;
    }

    if (latestTimestamp != null &&
        (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _studentEnrollmentCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  Future<int> _pullStudentClassRolls({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(
      _studentClassRollCheckpointKey,
    );
    final records = await pocketbaseGateway.pullStudentClassRolls(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapStudentClassRollRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'student_class_roll',
        tenantId: mapped.tenantId,
        entityId: mapped.classRollId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null ||
            mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      await database.upsertStudentClassRollRecord(
        classRollId: mapped.classRollId,
        tenantId: mapped.tenantId,
        studentId: mapped.studentId,
        academicSession: mapped.academicSession,
        className: mapped.className,
        sectionName: mapped.sectionName,
        rollNo: mapped.rollNo,
        isActive: mapped.isActive,
        source: mapped.source,
        updatedAt: mapped.updatedAt,
      );

      if (latestTimestamp == null ||
          mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }

      upserts++;
    }

    if (latestTimestamp != null &&
        (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _studentClassRollCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  Future<int> _pullTenantLicenses({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(
      _tenantLicenseCheckpointKey,
    );
    final records = await pocketbaseGateway.pullTenantLicenses(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapTenantLicenseRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'tenant_license',
        tenantId: mapped.tenantId,
        entityId: mapped.licenseId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null ||
            mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      await database.upsertTenantLicenseFromRemote(
        licenseId: mapped.licenseId,
        tenantId: mapped.tenantId,
        tenantName: mapped.tenantName,
        schoolOwnerEmail: mapped.schoolOwnerEmail,
        planCode: mapped.planCode,
        seatLimit: mapped.seatLimit,
        isActive: mapped.isActive,
        issuedAt: mapped.issuedAt,
        updatedAt: mapped.updatedAt,
        expiresAt: mapped.expiresAt,
      );

      if (latestTimestamp == null ||
          mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }

      upserts++;
    }

    if (latestTimestamp != null &&
        (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _tenantLicenseCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  Future<int> _pullTenantUsageMetrics({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(
      _tenantUsageMetricCheckpointKey,
    );
    final records = await pocketbaseGateway.pullTenantUsageMetrics(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapTenantUsageMetricRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'tenant_usage_metric',
        tenantId: mapped.tenantId,
        entityId: mapped.metricId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null ||
            mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      await database.upsertTenantUsageMetricFromRemote(
        metricId: mapped.metricId,
        tenantId: mapped.tenantId,
        periodKey: mapped.periodKey,
        activeStudents: mapped.activeStudents,
        activeStaff: mapped.activeStaff,
        monthlyActiveUsers: mapped.monthlyActiveUsers,
        storageGb: mapped.storageGb,
        outstandingAmount: mapped.outstandingAmount,
        collectedAmount: mapped.collectedAmount,
        overdueInvoices: mapped.overdueInvoices,
        nextBillingAt: mapped.nextBillingAt,
        billingStatus: mapped.billingStatus,
        source: mapped.source,
        updatedAt: mapped.updatedAt,
      );

      if (latestTimestamp == null ||
          mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }

      upserts++;
    }

    if (latestTimestamp != null &&
        (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _tenantUsageMetricCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  Future<int> _pullTenantFeatureFlags({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(
      _tenantFeatureFlagCheckpointKey,
    );
    final records = await pocketbaseGateway.pullTenantFeatureFlags(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapTenantFeatureFlagRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'tenant_feature_flag',
        tenantId: mapped.tenantId,
        entityId: mapped.flagId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null ||
            mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      await database.upsertTenantFeatureFlagFromRemote(
        flagId: mapped.flagId,
        tenantId: mapped.tenantId,
        featureKey: mapped.featureKey,
        isEnabled: mapped.isEnabled,
        source: mapped.source,
        updatedAt: mapped.updatedAt,
      );

      if (latestTimestamp == null ||
          mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }

      upserts++;
    }

    if (latestTimestamp != null &&
        (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _tenantFeatureFlagCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  Future<int> _pullNoticeBoards({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(
      _noticeBoardCheckpointKey,
    );
    final records = await pocketbaseGateway.pullNoticeBoards(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapNoticeBoardRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'notice_board',
        tenantId: mapped.tenantId,
        entityId: mapped.noticeId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null ||
            mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      if (mapped.isDeleted) {
        await database.deleteNoticeBoardRecord(
          tenantId: mapped.tenantId,
          noticeId: mapped.noticeId,
        );
      } else {
        await database.upsertNoticeBoardRecord(
          noticeId: mapped.noticeId,
          tenantId: mapped.tenantId,
          title: mapped.title,
          message: mapped.message,
          audience: mapped.audience,
          publishAt: mapped.publishAt,
          expiresAt: mapped.expiresAt,
          isPublished: mapped.isPublished,
          source: mapped.source,
          updatedAt: mapped.updatedAt,
        );
      }

      if (latestTimestamp == null ||
          mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }

      upserts++;
    }

    if (latestTimestamp != null &&
        (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _noticeBoardCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  Future<int> _pullTimetableSlots({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(
      _timetableSlotCheckpointKey,
    );
    final records = await pocketbaseGateway.pullTimetableSlots(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapTimetableSlotRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'timetable_slot',
        tenantId: mapped.tenantId,
        entityId: mapped.slotId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null ||
            mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      if (mapped.isDeleted) {
        await database.deleteTimetableSlotRecord(
          tenantId: mapped.tenantId,
          slotId: mapped.slotId,
        );
      } else {
        await database.upsertTimetableSlotRecord(
          slotId: mapped.slotId,
          tenantId: mapped.tenantId,
          dayOfWeek: mapped.dayOfWeek,
          periodIndex: mapped.periodIndex,
          subjectName: mapped.subjectName,
          teacherName: mapped.teacherName,
          roomNo: mapped.roomNo,
          timeFrom: mapped.timeFrom,
          timeTo: mapped.timeTo,
          classSection: mapped.classSection,
          isActive: mapped.isActive,
          source: mapped.source,
          updatedAt: mapped.updatedAt,
        );
      }

      if (latestTimestamp == null ||
          mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }

      upserts++;
    }

    if (latestTimestamp != null &&
        (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _timetableSlotCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  Future<int> _pullTransportRoutes({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(
      _transportRouteCheckpointKey,
    );
    final records = await pocketbaseGateway.pullTransportRoutes(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapTransportRouteRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'transport_route',
        tenantId: mapped.tenantId,
        entityId: mapped.routeId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null ||
            mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      if (mapped.isDeleted) {
        await database.deleteTransportRouteRecord(
          tenantId: mapped.tenantId,
          routeId: mapped.routeId,
        );
      } else {
        await database.upsertTransportRouteRecord(
          routeId: mapped.routeId,
          tenantId: mapped.tenantId,
          routeTitle: mapped.routeTitle,
          vehicleNo: mapped.vehicleNo,
          vehicleModel: mapped.vehicleModel,
          driverName: mapped.driverName,
          driverContact: mapped.driverContact,
          pickupPoint: mapped.pickupPoint,
          destinationPoint: mapped.destinationPoint,
          pickupTime: mapped.pickupTime,
          dropTime: mapped.dropTime,
          monthlyFare: mapped.monthlyFare,
          isActive: mapped.isActive,
          source: mapped.source,
          updatedAt: mapped.updatedAt,
        );
      }

      if (latestTimestamp == null ||
          mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }

      upserts++;
    }

    if (latestTimestamp != null &&
        (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _transportRouteCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  Future<int> _pullHomeworkAssignments({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(
      _homeworkAssignmentCheckpointKey,
    );
    final records = await pocketbaseGateway.pullHomeworkAssignments(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapHomeworkAssignmentRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'homework_assignment',
        tenantId: mapped.tenantId,
        entityId: mapped.assignmentId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null ||
            mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      if (mapped.isDeleted) {
        await database.deleteHomeworkAssignmentRecord(
          tenantId: mapped.tenantId,
          assignmentId: mapped.assignmentId,
        );
      } else {
        await database.upsertHomeworkAssignmentRecord(
          assignmentId: mapped.assignmentId,
          tenantId: mapped.tenantId,
          assignmentType: mapped.assignmentType,
          title: mapped.title,
          subjectName: mapped.subjectName,
          classSection: mapped.classSection,
          details: mapped.details,
          assignedOn: mapped.assignedOn,
          dueDate: mapped.dueDate,
          attachmentUrl: mapped.attachmentUrl,
          isPublished: mapped.isPublished,
          isActive: mapped.isActive,
          source: mapped.source,
          updatedAt: mapped.updatedAt,
        );
      }

      if (latestTimestamp == null ||
          mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }

      upserts++;
    }

    if (latestTimestamp != null &&
        (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _homeworkAssignmentCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  Future<int> _pullOnlineLearningItems({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(
      _onlineLearningItemCheckpointKey,
    );
    final records = await pocketbaseGateway.pullOnlineLearningItems(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapOnlineLearningItemRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'online_learning_item',
        tenantId: mapped.tenantId,
        entityId: mapped.itemId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null ||
            mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      if (mapped.isDeleted) {
        await database.deleteOnlineLearningItemRecord(
          tenantId: mapped.tenantId,
          itemId: mapped.itemId,
        );
      } else {
        await database.upsertOnlineLearningItemRecord(
          itemId: mapped.itemId,
          tenantId: mapped.tenantId,
          itemType: mapped.itemType,
          title: mapped.title,
          summary: mapped.summary,
          instructorName: mapped.instructorName,
          durationLabel: mapped.durationLabel,
          accessLevel: mapped.accessLevel,
          priceAmount: mapped.priceAmount,
          publishedAt: mapped.publishedAt,
          isPublished: mapped.isPublished,
          isActive: mapped.isActive,
          source: mapped.source,
          updatedAt: mapped.updatedAt,
        );
      }

      if (latestTimestamp == null ||
          mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }

      upserts++;
    }

    if (latestTimestamp != null &&
        (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _onlineLearningItemCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  Future<int> _pullLessons({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(_lessonCheckpointKey);
    final records = await pocketbaseGateway.pullLessons(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapLessonRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'lesson',
        tenantId: mapped.tenantId,
        entityId: mapped.lessonId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null ||
            mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      if (mapped.isDeleted) {
        await database.deleteLessonRecord(
          tenantId: mapped.tenantId,
          lessonId: mapped.lessonId,
        );
      } else {
        await database.upsertLessonRecord(
          lessonId: mapped.lessonId,
          tenantId: mapped.tenantId,
          title: mapped.title,
          classSection: mapped.classSection,
          subjectName: mapped.subjectName,
          topicName: mapped.topicName,
          lessonDateLabel: mapped.lessonDateLabel,
          attachmentUrl: mapped.attachmentUrl,
          isActive: mapped.isActive,
          source: mapped.source,
          updatedAt: mapped.updatedAt,
        );
      }

      if (latestTimestamp == null ||
          mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }

      upserts++;
    }

    if (latestTimestamp != null &&
        (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _lessonCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  Future<int> _pullLessonPlans({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(
      _lessonPlanCheckpointKey,
    );
    final records = await pocketbaseGateway.pullLessonPlans(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapLessonPlanRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'lesson_plan',
        tenantId: mapped.tenantId,
        entityId: mapped.planId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null ||
            mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      if (mapped.isDeleted) {
        await database.deleteLessonPlanRecord(
          tenantId: mapped.tenantId,
          planId: mapped.planId,
        );
      } else {
        await database.upsertLessonPlanRecord(
          planId: mapped.planId,
          tenantId: mapped.tenantId,
          title: mapped.title,
          classSection: mapped.classSection,
          subjectName: mapped.subjectName,
          objective: mapped.objective,
          periodLabel: mapped.periodLabel,
          activities: mapped.activities,
          isActive: mapped.isActive,
          source: mapped.source,
          updatedAt: mapped.updatedAt,
        );
      }

      if (latestTimestamp == null ||
          mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }

      upserts++;
    }

    if (latestTimestamp != null &&
        (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _lessonPlanCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  Future<int> _pullSubjects({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(_subjectCheckpointKey);
    final records = await pocketbaseGateway.pullSubjects(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapSubjectRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'subject',
        tenantId: mapped.tenantId,
        entityId: mapped.subjectId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null ||
            mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      if (mapped.isDeleted) {
        await database.deleteSubjectRecord(
          tenantId: mapped.tenantId,
          subjectId: mapped.subjectId,
        );
      } else {
        await database.upsertSubjectRecord(
          subjectId: mapped.subjectId,
          tenantId: mapped.tenantId,
          subjectName: mapped.subjectName,
          subjectCode: mapped.subjectCode,
          subjectType: mapped.subjectType,
          classSection: mapped.classSection,
          teacherName: mapped.teacherName,
          isActive: mapped.isActive,
          source: mapped.source,
          updatedAt: mapped.updatedAt,
        );
      }

      if (latestTimestamp == null ||
          mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }

      upserts++;
    }

    if (latestTimestamp != null &&
        (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _subjectCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  Future<int> _pullSyllabusItems({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(_syllabusCheckpointKey);
    final records = await pocketbaseGateway.pullSyllabusItems(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapSyllabusRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'syllabus',
        tenantId: mapped.tenantId,
        entityId: mapped.syllabusId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null ||
            mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      if (mapped.isDeleted) {
        await database.deleteSyllabusRecord(
          tenantId: mapped.tenantId,
          syllabusId: mapped.syllabusId,
        );
      } else {
        await database.upsertSyllabusRecord(
          syllabusId: mapped.syllabusId,
          tenantId: mapped.tenantId,
          title: mapped.title,
          classSection: mapped.classSection,
          subjectName: mapped.subjectName,
          statusLabel: mapped.statusLabel,
          completionPercent: mapped.completionPercent,
          targetDate: mapped.targetDate,
          notes: mapped.notes,
          isActive: mapped.isActive,
          source: mapped.source,
          updatedAt: mapped.updatedAt,
        );
      }

      if (latestTimestamp == null ||
          mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }

      upserts++;
    }

    if (latestTimestamp != null &&
        (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _syllabusCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  Future<int> _pullLibraryItems({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(
      _libraryItemCheckpointKey,
    );
    final records = await pocketbaseGateway.pullLibraryItems(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapLibraryItemRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'library_item',
        tenantId: mapped.tenantId,
        entityId: mapped.bookId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null ||
            mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      if (mapped.isDeleted) {
        await database.deleteLibraryBookRecord(
          tenantId: mapped.tenantId,
          bookId: mapped.bookId,
        );
      } else {
        await database.upsertLibraryBookRecord(
          bookId: mapped.bookId,
          tenantId: mapped.tenantId,
          bookType: mapped.bookType,
          title: mapped.title,
          authorName: mapped.authorName,
          categoryName: mapped.categoryName,
          issuedOn: mapped.issuedOn,
          dueDate: mapped.dueDate,
          returnDate: mapped.returnDate,
          ratingScore: mapped.ratingScore,
          issueCount: mapped.issueCount,
          isIssued: mapped.isIssued,
          isActive: mapped.isActive,
          source: mapped.source,
          updatedAt: mapped.updatedAt,
        );
      }

      if (latestTimestamp == null ||
          mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }

      upserts++;
    }

    if (latestTimestamp != null &&
        (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _libraryItemCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  Future<int> _pullDocumentCenterItems({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(
      _documentCenterItemCheckpointKey,
    );
    final records = await pocketbaseGateway.pullDocumentCenterItems(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapDocumentCenterRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'document_center_item',
        tenantId: mapped.tenantId,
        entityId: mapped.itemId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null ||
            mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      if (mapped.isDeleted) {
        await database.deleteDocumentCenterRecord(
          tenantId: mapped.tenantId,
          itemId: mapped.itemId,
        );
      } else {
        await database.upsertDocumentCenterRecord(
          itemId: mapped.itemId,
          tenantId: mapped.tenantId,
          contentType: mapped.contentType,
          title: mapped.title,
          description: mapped.description,
          fileUrl: mapped.fileUrl,
          thumbnailUrl: mapped.thumbnailUrl,
          categoryLabel: mapped.categoryLabel,
          uploadState: mapped.uploadState,
          publishedAt: mapped.publishedAt,
          isActive: mapped.isActive,
          source: mapped.source,
          updatedAt: mapped.updatedAt,
        );
      }

      if (latestTimestamp == null ||
          mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }

      upserts++;
    }

    if (latestTimestamp != null &&
        (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _documentCenterItemCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  Future<int> _pullVisitorCommunicationEntries({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(
      _visitorCommunicationCheckpointKey,
    );
    final records = await pocketbaseGateway.pullVisitorCommunicationEntries(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapVisitorCommunicationRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'visitor_communication',
        tenantId: mapped.tenantId,
        entityId: mapped.entryId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null ||
            mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      if (mapped.isDeleted) {
        await database.deleteVisitorCommunicationRecord(
          tenantId: mapped.tenantId,
          entryId: mapped.entryId,
        );
      } else {
        await database.upsertVisitorCommunicationRecord(
          entryId: mapped.entryId,
          tenantId: mapped.tenantId,
          entryType: mapped.entryType,
          visitorName: mapped.visitorName,
          purpose: mapped.purpose,
          phone: mapped.phone,
          checkInAt: mapped.checkInAt,
          checkOutAt: mapped.checkOutAt,
          statusLabel: mapped.statusLabel,
          note: mapped.note,
          isActive: mapped.isActive,
          source: mapped.source,
          updatedAt: mapped.updatedAt,
        );
      }

      if (latestTimestamp == null ||
          mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }

      upserts++;
    }

    if (latestTimestamp != null &&
        (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _visitorCommunicationCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  Future<int> _pullNotifications({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(
      _notificationCheckpointKey,
    );
    final records = await pocketbaseGateway.pullNotifications(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapNotificationRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'notification',
        tenantId: mapped.tenantId,
        entityId: mapped.notificationId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null ||
            mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      if (mapped.isDeleted) {
        await database.deleteNotificationRecord(
          tenantId: mapped.tenantId,
          notificationId: mapped.notificationId,
        );
      } else {
        await database.upsertNotificationRecord(
          notificationId: mapped.notificationId,
          tenantId: mapped.tenantId,
          notificationType: mapped.notificationType,
          title: mapped.title,
          body: mapped.body,
          audience: mapped.audience,
          isRead: mapped.isRead,
          deliveryStatus: mapped.deliveryStatus,
          sentAt: mapped.sentAt,
          readAt: mapped.readAt,
          payloadJson: mapped.payloadJson,
          isActive: mapped.isActive,
          source: mapped.source,
          updatedAt: mapped.updatedAt,
        );
      }

      if (latestTimestamp == null ||
          mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }

      upserts++;
    }

    if (latestTimestamp != null &&
        (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _notificationCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  Future<int> _pullLiveClasses({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(_liveClassCheckpointKey);
    final records = await pocketbaseGateway.pullLiveClasses(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapLiveClassRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'live_class',
        tenantId: mapped.tenantId,
        entityId: mapped.classId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null ||
            mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      if (mapped.isDeleted) {
        await database.deleteLiveClassRecord(
          tenantId: mapped.tenantId,
          classId: mapped.classId,
        );
      } else {
        await database.upsertLiveClassRecord(
          classId: mapped.classId,
          tenantId: mapped.tenantId,
          providerType: mapped.providerType,
          title: mapped.title,
          classSection: mapped.classSection,
          hostName: mapped.hostName,
          startAt: mapped.startAt,
          endAt: mapped.endAt,
          joinUrl: mapped.joinUrl,
          meetingId: mapped.meetingId,
          meetingPassword: mapped.meetingPassword,
          statusLabel: mapped.statusLabel,
          isActive: mapped.isActive,
          source: mapped.source,
          updatedAt: mapped.updatedAt,
        );
      }

      if (latestTimestamp == null ||
          mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }

      upserts++;
    }

    if (latestTimestamp != null &&
        (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _liveClassCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  Future<int> _pullSchoolOwners({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(
      _schoolOwnerCheckpointKey,
    );
    final records = await pocketbaseGateway.pullSchoolOwners(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapSchoolOwnerRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'school_owner',
        tenantId: mapped.tenantId,
        entityId: mapped.ownerId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null ||
            mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      await database.upsertSchoolOwnerFromRemote(
        ownerId: mapped.ownerId,
        tenantId: mapped.tenantId,
        tenantName: mapped.tenantName,
        fullName: mapped.fullName,
        email: mapped.email,
        phone: mapped.phone,
        isPrimary: mapped.isPrimary,
        isActive: mapped.isActive,
        provisioningStatus: mapped.provisioningStatus,
        createdAt: mapped.createdAt,
        updatedAt: mapped.updatedAt,
      );

      if (latestTimestamp == null ||
          mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }

      upserts++;
    }

    if (latestTimestamp != null &&
        (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _schoolOwnerCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  Future<int> _pullStudentAttendance({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(
      _studentAttendanceCheckpointKey,
    );
    final records = await pocketbaseGateway.pullStudentAttendance(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapStudentAttendanceRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'student_attendance',
        tenantId: mapped.tenantId,
        entityId: mapped.recordId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null ||
            mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      await database.upsertStudentAttendanceRecord(
        recordId: mapped.recordId,
        tenantId: mapped.tenantId,
        studentId: mapped.studentId,
        attendanceDate: mapped.attendanceDate,
        status: mapped.status,
        source: mapped.source,
        updatedAt: mapped.updatedAt,
      );

      if (latestTimestamp == null ||
          mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }

      upserts++;
    }

    if (latestTimestamp != null &&
        (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _studentAttendanceCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  Future<int> _pullLeaveRequests({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(
      _leaveRequestCheckpointKey,
    );
    final records = await pocketbaseGateway.pullLeaveRequests(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapLeaveRequestRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'leave_request',
        tenantId: mapped.tenantId,
        entityId: mapped.leaveId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null ||
            mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      if (mapped.isDeleted) {
        await database.deleteLeaveRequestRecord(
          tenantId: mapped.tenantId,
          leaveId: mapped.leaveId,
        );
      } else {
        await database.upsertLeaveRequestRecord(
          leaveId: mapped.leaveId,
          tenantId: mapped.tenantId,
          requesterId: mapped.requesterId,
          leaveFrom: mapped.leaveFrom,
          leaveTo: mapped.leaveTo,
          appliedAt: mapped.appliedAt,
          reason: mapped.reason,
          statusLabel: mapped.statusLabel,
          approverName: mapped.approverName,
          approvedAt: mapped.approvedAt,
          attachmentUrl: mapped.attachmentUrl,
          isActive: mapped.isActive,
          source: mapped.source,
          updatedAt: mapped.updatedAt,
        );
      }

      if (latestTimestamp == null ||
          mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }

      upserts++;
    }

    if (latestTimestamp != null &&
        (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _leaveRequestCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  Future<int> _pullPendingTasks({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(
      _pendingTaskCheckpointKey,
    );
    final records = await pocketbaseGateway.pullPendingTasks(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapPendingTaskRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'pending_task',
        tenantId: mapped.tenantId,
        entityId: mapped.taskId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null ||
            mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      if (mapped.isDeleted) {
        await database.deletePendingTaskRecord(
          tenantId: mapped.tenantId,
          taskId: mapped.taskId,
        );
      } else {
        await database.upsertPendingTaskRecord(
          taskId: mapped.taskId,
          tenantId: mapped.tenantId,
          userId: mapped.userId,
          title: mapped.title,
          dueDate: mapped.dueDate,
          statusLabel: mapped.statusLabel,
          isCompleted: mapped.isCompleted,
          priority: mapped.priority,
          isActive: mapped.isActive,
          source: mapped.source,
          updatedAt: mapped.updatedAt,
        );
      }

      if (latestTimestamp == null ||
          mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }

      upserts++;
    }

    if (latestTimestamp != null &&
        (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _pendingTaskCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  Future<int> _pullHostelRooms({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(
      _hostelRoomCheckpointKey,
    );
    final records = await pocketbaseGateway.pullHostelRooms(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapHostelRoomRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'hostel_room',
        tenantId: mapped.tenantId,
        entityId: mapped.roomId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null ||
            mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      if (mapped.isDeleted) {
        await database.deleteHostelRoomRecord(
          tenantId: mapped.tenantId,
          roomId: mapped.roomId,
        );
      } else {
        await database.upsertHostelRoomRecord(
          roomId: mapped.roomId,
          tenantId: mapped.tenantId,
          studentId: mapped.studentId,
          hostelName: mapped.hostelName,
          roomNo: mapped.roomNo,
          roomType: mapped.roomType,
          floorNo: mapped.floorNo,
          bedNo: mapped.bedNo,
          wardenName: mapped.wardenName,
          wardenContact: mapped.wardenContact,
          monthlyFees: mapped.monthlyFees,
          isActive: mapped.isActive,
          source: mapped.source,
          updatedAt: mapped.updatedAt,
        );
      }

      if (latestTimestamp == null ||
          mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }

      upserts++;
    }

    if (latestTimestamp != null &&
        (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _hostelRoomCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  _TenantLicenseRemote? _mapTenantLicenseRecord(Map<String, dynamic> source) {
    final tenantId = _readString(source, ['tenant_id', 'tenantId']);
    if (tenantId.isEmpty) return null;

    final licenseId = _readString(source, [
      'license_id',
      'licenseId',
      'id',
      'external_id',
    ], fallback: 'lic_$tenantId');

    final tenantName = _readString(source, [
      'tenant_name',
      'tenantName',
      'name',
    ], fallback: 'Unknown School');

    final schoolOwnerEmail = _readString(source, [
      'school_owner_email',
      'schoolOwnerEmail',
      'owner_email',
      'ownerEmail',
    ]);

    final planCode = _readString(source, [
      'plan_code',
      'planCode',
    ], fallback: 'starter');

    final seatLimit = _readInt(source, ['seat_limit', 'seatLimit']) ?? 100;
    final isActive = _readBool(source, ['is_active', 'isActive']) ?? true;
    final issuedAt =
        _readDate(source, ['issued_at', 'issuedAt', 'created', 'created_at']) ??
        DateTime.now().toUtc();
    final updatedAt =
        _readDate(source, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();
    final expiresAt = _readDate(source, ['expires_at', 'expiresAt']);

    return _TenantLicenseRemote(
      licenseId: licenseId,
      tenantId: tenantId,
      tenantName: tenantName,
      schoolOwnerEmail: schoolOwnerEmail,
      planCode: planCode,
      seatLimit: seatLimit,
      isActive: isActive,
      issuedAt: issuedAt,
      updatedAt: updatedAt,
      expiresAt: expiresAt,
    );
  }

  _SchoolOwnerRemote? _mapSchoolOwnerRecord(Map<String, dynamic> source) {
    final ownerId = _readString(source, [
      'owner_id',
      'ownerId',
      'id',
      'external_id',
    ]);
    final tenantId = _readString(source, ['tenant_id', 'tenantId']);

    if (ownerId.isEmpty || tenantId.isEmpty) return null;

    final tenantName = _readString(source, [
      'tenant_name',
      'tenantName',
    ], fallback: 'Unknown School');
    final fullName = _readString(source, ['full_name', 'fullName', 'name']);
    final email = _readString(source, ['email']);
    final phone = _readString(source, ['phone']);
    final isPrimary = _readBool(source, ['is_primary', 'isPrimary']) ?? true;
    final isActive = _readBool(source, ['is_active', 'isActive']) ?? true;
    final provisioningStatus = _readString(source, [
      'provisioning_status',
      'provisioningStatus',
    ], fallback: 'provisioned');
    final createdAt =
        _readDate(source, ['created_at', 'createdAt', 'created']) ??
        DateTime.now().toUtc();
    final updatedAt =
        _readDate(source, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    return _SchoolOwnerRemote(
      ownerId: ownerId,
      tenantId: tenantId,
      tenantName: tenantName,
      fullName: fullName,
      email: email,
      phone: phone.isEmpty ? null : phone,
      isPrimary: isPrimary,
      isActive: isActive,
      provisioningStatus: provisioningStatus,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  _TenantUsageMetricRemote? _mapTenantUsageMetricRecord(
    Map<String, dynamic> source,
  ) {
    final tenantId = _readString(source, ['tenant_id', 'tenantId']);
    if (tenantId.isEmpty) return null;

    final updatedAt =
        _readDate(source, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();
    final periodKey = _readString(
      source,
      ['period_key', 'periodKey', 'billing_period'],
      fallback:
          '${updatedAt.year}-${updatedAt.month.toString().padLeft(2, '0')}',
    );
    final metricId = _readString(source, [
      'metric_id',
      'usage_metric_id',
      'metricId',
      'id',
      'external_id',
    ], fallback: 'usage_${tenantId}_$periodKey');

    final activeStudents =
        _readInt(source, ['active_students', 'activeStudents']) ?? 0;
    final activeStaff = _readInt(source, ['active_staff', 'activeStaff']) ?? 0;
    final monthlyActiveUsers =
        _readInt(source, ['monthly_active_users', 'monthlyActiveUsers']) ?? 0;
    final storageGb = _readDouble(source, ['storage_gb', 'storageGb']) ?? 0;
    final outstandingAmount =
        _readDouble(source, ['outstanding_amount', 'outstandingAmount']) ?? 0;
    final collectedAmount =
        _readDouble(source, ['collected_amount', 'collectedAmount']) ?? 0;
    final overdueInvoices =
        _readInt(source, ['overdue_invoices', 'overdueInvoices']) ?? 0;
    final nextBillingAt = _readDate(source, [
      'next_billing_at',
      'nextBillingAt',
      'billing_date',
    ]);
    final billingStatus = _readString(source, [
      'billing_status',
      'billingStatus',
      'status',
    ], fallback: 'current');
    final sourceType = _readString(source, ['source'], fallback: 'remote');

    return _TenantUsageMetricRemote(
      metricId: metricId,
      tenantId: tenantId,
      periodKey: periodKey,
      activeStudents: activeStudents,
      activeStaff: activeStaff,
      monthlyActiveUsers: monthlyActiveUsers,
      storageGb: storageGb,
      outstandingAmount: outstandingAmount,
      collectedAmount: collectedAmount,
      overdueInvoices: overdueInvoices,
      nextBillingAt: nextBillingAt,
      billingStatus: billingStatus,
      source: sourceType,
      updatedAt: updatedAt,
    );
  }

  _TenantFeatureFlagRemote? _mapTenantFeatureFlagRecord(
    Map<String, dynamic> source,
  ) {
    final tenantId = _readString(source, ['tenant_id', 'tenantId']);
    if (tenantId.isEmpty) return null;

    final featureKey = _readString(source, ['feature_key', 'featureKey']);
    if (featureKey.isEmpty) return null;

    final flagId = _readString(source, [
      'flag_id',
      'flagId',
      'id',
      'external_id',
    ], fallback: 'ff_${tenantId}_$featureKey');
    final isEnabled = _readBool(source, ['is_enabled', 'isEnabled']) ?? true;
    final sourceType = _readString(source, ['source'], fallback: 'remote');
    final updatedAt =
        _readDate(source, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    return _TenantFeatureFlagRemote(
      flagId: flagId,
      tenantId: tenantId,
      featureKey: featureKey,
      isEnabled: isEnabled,
      source: sourceType,
      updatedAt: updatedAt,
    );
  }

  _NoticeBoardRemote? _mapNoticeBoardRecord(Map<String, dynamic> source) {
    final noticeId = _readString(source, [
      'notice_id',
      'noticeId',
      'id',
      'external_id',
    ]);
    final tenantId = _readString(source, ['tenant_id', 'tenantId']);

    if (noticeId.isEmpty || tenantId.isEmpty) {
      return null;
    }

    final operation = _readString(source, ['operation', 'op']);
    final isDeleted =
        (_readBool(source, ['is_deleted', 'isDeleted', 'deleted']) ?? false) ||
        operation.toLowerCase() == 'delete';

    final title = _readString(source, ['title'], fallback: 'Notice');
    final message = _readString(source, ['message']);
    final audience = _readString(source, ['audience'], fallback: 'all');
    final publishAt =
        _readDate(source, [
          'publish_at',
          'publishAt',
          'created_at',
          'created',
        ]) ??
        DateTime.now().toUtc();
    final expiresAt = _readDate(source, ['expires_at', 'expiresAt']);
    final isPublished =
        _readBool(source, ['is_published', 'isPublished']) ?? true;
    final sourceType = _readString(source, ['source'], fallback: 'remote');
    final updatedAt =
        _readDate(source, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    return _NoticeBoardRemote(
      noticeId: noticeId,
      tenantId: tenantId,
      title: title,
      message: message,
      audience: audience,
      publishAt: publishAt,
      expiresAt: expiresAt,
      isPublished: isPublished,
      source: sourceType,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
    );
  }

  _TimetableSlotRemote? _mapTimetableSlotRecord(Map<String, dynamic> source) {
    final slotId = _readString(source, [
      'slot_id',
      'slotId',
      'id',
      'external_id',
    ]);
    final tenantId = _readString(source, ['tenant_id', 'tenantId']);

    if (slotId.isEmpty || tenantId.isEmpty) {
      return null;
    }

    final operation = _readString(source, ['operation', 'op']);
    final isDeleted =
        (_readBool(source, ['is_deleted', 'isDeleted', 'deleted']) ?? false) ||
        operation.toLowerCase() == 'delete';

    final dayOfWeek = _readString(source, [
      'day_of_week',
      'dayOfWeek',
    ], fallback: 'Monday');
    final periodIndex = _readInt(source, ['period_index', 'periodIndex']) ?? 1;
    final subjectName = _readString(source, [
      'subject_name',
      'subjectName',
    ], fallback: 'General');
    final teacherName = _readString(source, ['teacher_name', 'teacherName']);
    final roomNo = _readString(source, ['room_no', 'roomNo']);
    final timeFrom = _readString(source, ['time_from', 'timeFrom']);
    final timeTo = _readString(source, ['time_to', 'timeTo']);
    final classSection = _readString(source, ['class_section', 'classSection']);
    final isActive = _readBool(source, ['is_active', 'isActive']) ?? true;
    final sourceType = _readString(source, ['source'], fallback: 'remote');
    final updatedAt =
        _readDate(source, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    return _TimetableSlotRemote(
      slotId: slotId,
      tenantId: tenantId,
      dayOfWeek: dayOfWeek,
      periodIndex: periodIndex,
      subjectName: subjectName,
      teacherName: teacherName.isEmpty ? null : teacherName,
      roomNo: roomNo.isEmpty ? null : roomNo,
      timeFrom: timeFrom.isEmpty ? null : timeFrom,
      timeTo: timeTo.isEmpty ? null : timeTo,
      classSection: classSection.isEmpty ? null : classSection,
      isActive: isActive,
      source: sourceType,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
    );
  }

  _TransportRouteRemote? _mapTransportRouteRecord(Map<String, dynamic> source) {
    final routeId = _readString(source, [
      'route_id',
      'routeId',
      'id',
      'external_id',
    ]);
    final tenantId = _readString(source, ['tenant_id', 'tenantId']);

    if (routeId.isEmpty || tenantId.isEmpty) {
      return null;
    }

    final operation = _readString(source, ['operation', 'op']);
    final isDeleted =
        (_readBool(source, ['is_deleted', 'isDeleted', 'deleted']) ?? false) ||
        operation.toLowerCase() == 'delete';

    final routeTitle = _readString(source, [
      'route_title',
      'routeTitle',
    ], fallback: 'Route');
    final vehicleNo = _readString(source, ['vehicle_no', 'vehicleNo']);
    final vehicleModel = _readString(source, ['vehicle_model', 'vehicleModel']);
    final driverName = _readString(source, ['driver_name', 'driverName']);
    final driverContact = _readString(source, [
      'driver_contact',
      'driverContact',
    ]);
    final pickupPoint = _readString(source, ['pickup_point', 'pickupPoint']);
    final destinationPoint = _readString(source, [
      'destination_point',
      'destinationPoint',
    ]);
    final pickupTime = _readString(source, ['pickup_time', 'pickupTime']);
    final dropTime = _readString(source, ['drop_time', 'dropTime']);
    final monthlyFare =
        _readDouble(source, ['monthly_fare', 'monthlyFare']) ?? 0;
    final isActive = _readBool(source, ['is_active', 'isActive']) ?? true;
    final sourceType = _readString(source, ['source'], fallback: 'remote');
    final updatedAt =
        _readDate(source, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    return _TransportRouteRemote(
      routeId: routeId,
      tenantId: tenantId,
      routeTitle: routeTitle,
      vehicleNo: vehicleNo.isEmpty ? null : vehicleNo,
      vehicleModel: vehicleModel.isEmpty ? null : vehicleModel,
      driverName: driverName.isEmpty ? null : driverName,
      driverContact: driverContact.isEmpty ? null : driverContact,
      pickupPoint: pickupPoint.isEmpty ? null : pickupPoint,
      destinationPoint: destinationPoint.isEmpty ? null : destinationPoint,
      pickupTime: pickupTime.isEmpty ? null : pickupTime,
      dropTime: dropTime.isEmpty ? null : dropTime,
      monthlyFare: monthlyFare,
      isActive: isActive,
      source: sourceType,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
    );
  }

  _HomeworkAssignmentRemote? _mapHomeworkAssignmentRecord(
    Map<String, dynamic> source,
  ) {
    final assignmentId = _readString(source, [
      'assignment_id',
      'assignmentId',
      'id',
      'external_id',
    ]);
    final tenantId = _readString(source, ['tenant_id', 'tenantId']);

    if (assignmentId.isEmpty || tenantId.isEmpty) {
      return null;
    }

    final operation = _readString(source, ['operation', 'op']);
    final isDeleted =
        (_readBool(source, ['is_deleted', 'isDeleted', 'deleted']) ?? false) ||
        operation.toLowerCase() == 'delete';

    final assignmentType = _readString(source, [
      'assignment_type',
      'assignmentType',
      'type',
    ], fallback: 'homework');
    final title = _readString(source, ['title'], fallback: 'Assignment');
    final subjectName = _readString(source, ['subject_name', 'subjectName']);
    final classSection = _readString(source, ['class_section', 'classSection']);
    final details = _readString(source, ['details', 'description']);
    final assignedOn = _readDate(source, ['assigned_on', 'assignedOn']);
    final dueDate = _readDate(source, ['due_date', 'dueDate']);
    final attachmentUrl = _readString(source, [
      'attachment_url',
      'attachmentUrl',
    ]);
    final isPublished =
        _readBool(source, ['is_published', 'isPublished']) ?? true;
    final isActive = _readBool(source, ['is_active', 'isActive']) ?? true;
    final sourceType = _readString(source, ['source'], fallback: 'remote');
    final updatedAt =
        _readDate(source, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    return _HomeworkAssignmentRemote(
      assignmentId: assignmentId,
      tenantId: tenantId,
      assignmentType: assignmentType,
      title: title,
      subjectName: subjectName.isEmpty ? null : subjectName,
      classSection: classSection.isEmpty ? null : classSection,
      details: details.isEmpty ? null : details,
      assignedOn: assignedOn,
      dueDate: dueDate,
      attachmentUrl: attachmentUrl.isEmpty ? null : attachmentUrl,
      isPublished: isPublished,
      isActive: isActive,
      source: sourceType,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
    );
  }

  _OnlineLearningItemRemote? _mapOnlineLearningItemRecord(
    Map<String, dynamic> source,
  ) {
    final itemId = _readString(source, [
      'item_id',
      'itemId',
      'id',
      'external_id',
    ]);
    final tenantId = _readString(source, ['tenant_id', 'tenantId']);

    if (itemId.isEmpty || tenantId.isEmpty) {
      return null;
    }

    final operation = _readString(source, ['operation', 'op']);
    final isDeleted =
        (_readBool(source, ['is_deleted', 'isDeleted', 'deleted']) ?? false) ||
        operation.toLowerCase() == 'delete';

    final itemType = _readString(source, [
      'item_type',
      'itemType',
      'type',
    ], fallback: 'course');
    final title = _readString(source, ['title'], fallback: 'Learning Item');
    final summary = _readString(source, ['summary', 'description']);
    final instructorName = _readString(source, [
      'instructor_name',
      'instructorName',
    ]);
    final durationLabel = _readString(source, [
      'duration_label',
      'durationLabel',
    ]);
    final accessLevel = _readString(source, [
      'access_level',
      'accessLevel',
    ], fallback: 'open');
    final priceAmount =
        _readDouble(source, ['price_amount', 'priceAmount']) ?? 0;
    final publishedAt = _readDate(source, ['published_at', 'publishedAt']);
    final isPublished =
        _readBool(source, ['is_published', 'isPublished']) ?? true;
    final isActive = _readBool(source, ['is_active', 'isActive']) ?? true;
    final sourceType = _readString(source, ['source'], fallback: 'remote');
    final updatedAt =
        _readDate(source, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    return _OnlineLearningItemRemote(
      itemId: itemId,
      tenantId: tenantId,
      itemType: itemType,
      title: title,
      summary: summary.isEmpty ? null : summary,
      instructorName: instructorName.isEmpty ? null : instructorName,
      durationLabel: durationLabel.isEmpty ? null : durationLabel,
      accessLevel: accessLevel,
      priceAmount: priceAmount,
      publishedAt: publishedAt,
      isPublished: isPublished,
      isActive: isActive,
      source: sourceType,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
    );
  }

  _LessonRemote? _mapLessonRecord(Map<String, dynamic> source) {
    final lessonId = _readString(source, [
      'lesson_id',
      'lessonId',
      'id',
      'external_id',
    ]);
    final tenantId = _readString(source, ['tenant_id', 'tenantId']);

    if (lessonId.isEmpty || tenantId.isEmpty) {
      return null;
    }

    final operation = _readString(source, ['operation', 'op']);
    final isDeleted =
        (_readBool(source, ['is_deleted', 'isDeleted', 'deleted']) ?? false) ||
        operation.toLowerCase() == 'delete';

    final title = _readString(source, ['title'], fallback: 'Lesson');
    final classSection = _readString(source, ['class_section', 'classSection']);
    final subjectName = _readString(source, ['subject_name', 'subjectName']);
    final topicName = _readString(source, ['topic_name', 'topicName']);
    final lessonDateLabel = _readString(source, [
      'lesson_date_label',
      'lessonDateLabel',
    ]);
    final attachmentUrl = _readString(source, [
      'attachment_url',
      'attachmentUrl',
    ]);
    final isActive = _readBool(source, ['is_active', 'isActive']) ?? true;
    final sourceType = _readString(source, ['source'], fallback: 'remote');
    final updatedAt =
        _readDate(source, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    return _LessonRemote(
      lessonId: lessonId,
      tenantId: tenantId,
      title: title,
      classSection: classSection.isEmpty ? null : classSection,
      subjectName: subjectName.isEmpty ? null : subjectName,
      topicName: topicName.isEmpty ? null : topicName,
      lessonDateLabel: lessonDateLabel.isEmpty ? null : lessonDateLabel,
      attachmentUrl: attachmentUrl.isEmpty ? null : attachmentUrl,
      isActive: isActive,
      source: sourceType,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
    );
  }

  _LessonPlanRemote? _mapLessonPlanRecord(Map<String, dynamic> source) {
    final planId = _readString(source, [
      'plan_id',
      'planId',
      'id',
      'external_id',
    ]);
    final tenantId = _readString(source, ['tenant_id', 'tenantId']);

    if (planId.isEmpty || tenantId.isEmpty) {
      return null;
    }

    final operation = _readString(source, ['operation', 'op']);
    final isDeleted =
        (_readBool(source, ['is_deleted', 'isDeleted', 'deleted']) ?? false) ||
        operation.toLowerCase() == 'delete';

    final title = _readString(source, ['title'], fallback: 'Lesson Plan');
    final classSection = _readString(source, ['class_section', 'classSection']);
    final subjectName = _readString(source, ['subject_name', 'subjectName']);
    final objective = _readString(source, ['objective']);
    final periodLabel = _readString(source, ['period_label', 'periodLabel']);
    final activities = _readString(source, ['activities']);
    final isActive = _readBool(source, ['is_active', 'isActive']) ?? true;
    final sourceType = _readString(source, ['source'], fallback: 'remote');
    final updatedAt =
        _readDate(source, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    return _LessonPlanRemote(
      planId: planId,
      tenantId: tenantId,
      title: title,
      classSection: classSection.isEmpty ? null : classSection,
      subjectName: subjectName.isEmpty ? null : subjectName,
      objective: objective.isEmpty ? null : objective,
      periodLabel: periodLabel.isEmpty ? null : periodLabel,
      activities: activities.isEmpty ? null : activities,
      isActive: isActive,
      source: sourceType,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
    );
  }

  _SubjectRemote? _mapSubjectRecord(Map<String, dynamic> source) {
    final subjectId = _readString(source, [
      'subject_id',
      'subjectId',
      'id',
      'external_id',
    ]);
    final tenantId = _readString(source, ['tenant_id', 'tenantId']);

    if (subjectId.isEmpty || tenantId.isEmpty) {
      return null;
    }

    final operation = _readString(source, ['operation', 'op']);
    final isDeleted =
        (_readBool(source, ['is_deleted', 'isDeleted', 'deleted']) ?? false) ||
        operation.toLowerCase() == 'delete';

    final subjectName = _readString(source, [
      'subject_name',
      'subjectName',
    ], fallback: 'Subject');
    final subjectCode = _readString(source, ['subject_code', 'subjectCode']);
    final subjectType = _readString(source, [
      'subject_type',
      'subjectType',
    ], fallback: 'theory');
    final classSection = _readString(source, ['class_section', 'classSection']);
    final teacherName = _readString(source, ['teacher_name', 'teacherName']);
    final isActive = _readBool(source, ['is_active', 'isActive']) ?? true;
    final sourceType = _readString(source, ['source'], fallback: 'remote');
    final updatedAt =
        _readDate(source, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    return _SubjectRemote(
      subjectId: subjectId,
      tenantId: tenantId,
      subjectName: subjectName,
      subjectCode: subjectCode.isEmpty ? null : subjectCode,
      subjectType: subjectType,
      classSection: classSection.isEmpty ? null : classSection,
      teacherName: teacherName.isEmpty ? null : teacherName,
      isActive: isActive,
      source: sourceType,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
    );
  }

  _SyllabusRemote? _mapSyllabusRecord(Map<String, dynamic> source) {
    final syllabusId = _readString(source, [
      'syllabus_id',
      'syllabusId',
      'id',
      'external_id',
    ]);
    final tenantId = _readString(source, ['tenant_id', 'tenantId']);

    if (syllabusId.isEmpty || tenantId.isEmpty) {
      return null;
    }

    final operation = _readString(source, ['operation', 'op']);
    final isDeleted =
        (_readBool(source, ['is_deleted', 'isDeleted', 'deleted']) ?? false) ||
        operation.toLowerCase() == 'delete';

    final title = _readString(source, ['title'], fallback: 'Syllabus');
    final classSection = _readString(source, ['class_section', 'classSection']);
    final subjectName = _readString(source, ['subject_name', 'subjectName']);
    final statusLabel = _readString(source, [
      'status_label',
      'statusLabel',
    ], fallback: 'pending');
    final completionPercent = _readString(source, [
      'completion_percent',
      'completionPercent',
    ]);
    final targetDate = _readDate(source, ['target_date', 'targetDate']);
    final notes = _readString(source, ['notes']);
    final isActive = _readBool(source, ['is_active', 'isActive']) ?? true;
    final sourceType = _readString(source, ['source'], fallback: 'remote');
    final updatedAt =
        _readDate(source, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    return _SyllabusRemote(
      syllabusId: syllabusId,
      tenantId: tenantId,
      title: title,
      classSection: classSection.isEmpty ? null : classSection,
      subjectName: subjectName.isEmpty ? null : subjectName,
      statusLabel: statusLabel,
      completionPercent: completionPercent.isEmpty ? null : completionPercent,
      targetDate: targetDate,
      notes: notes.isEmpty ? null : notes,
      isActive: isActive,
      source: sourceType,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
    );
  }

  _LibraryItemRemote? _mapLibraryItemRecord(Map<String, dynamic> source) {
    final bookId = _readString(source, [
      'book_id',
      'bookId',
      'id',
      'external_id',
    ]);
    final tenantId = _readString(source, ['tenant_id', 'tenantId']);

    if (bookId.isEmpty || tenantId.isEmpty) {
      return null;
    }

    final operation = _readString(source, ['operation', 'op']);
    final isDeleted =
        (_readBool(source, ['is_deleted', 'isDeleted', 'deleted']) ?? false) ||
        operation.toLowerCase() == 'delete';

    final bookType = _readString(source, [
      'book_type',
      'bookType',
    ], fallback: 'general');
    final title = _readString(source, ['title'], fallback: 'Book');
    final authorName = _readString(source, ['author_name', 'authorName']);
    final categoryName = _readString(source, ['category_name', 'categoryName']);
    final issuedOn = _readDate(source, ['issued_on', 'issuedOn']);
    final dueDate = _readDate(source, ['due_date', 'dueDate']);
    final returnDate = _readDate(source, ['return_date', 'returnDate']);
    final ratingScore =
        _readDouble(source, ['rating_score', 'ratingScore']) ?? 0;
    final issueCount = _readInt(source, ['issue_count', 'issueCount']) ?? 0;
    final isIssued = _readBool(source, ['is_issued', 'isIssued']) ?? false;
    final isActive = _readBool(source, ['is_active', 'isActive']) ?? true;
    final sourceType = _readString(source, ['source'], fallback: 'remote');
    final updatedAt =
        _readDate(source, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    return _LibraryItemRemote(
      bookId: bookId,
      tenantId: tenantId,
      bookType: bookType,
      title: title,
      authorName: authorName.isEmpty ? null : authorName,
      categoryName: categoryName.isEmpty ? null : categoryName,
      issuedOn: issuedOn,
      dueDate: dueDate,
      returnDate: returnDate,
      ratingScore: ratingScore,
      issueCount: issueCount,
      isIssued: isIssued,
      isActive: isActive,
      source: sourceType,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
    );
  }

  _DocumentCenterRemote? _mapDocumentCenterRecord(Map<String, dynamic> source) {
    final itemId = _readString(source, [
      'item_id',
      'itemId',
      'id',
      'external_id',
    ]);
    final tenantId = _readString(source, ['tenant_id', 'tenantId']);

    if (itemId.isEmpty || tenantId.isEmpty) {
      return null;
    }

    final operation = _readString(source, ['operation', 'op']);
    final isDeleted =
        (_readBool(source, ['is_deleted', 'isDeleted', 'deleted']) ?? false) ||
        operation.toLowerCase() == 'delete';

    final contentType = _readString(source, [
      'content_type',
      'contentType',
    ], fallback: 'download_content');
    final title = _readString(source, ['title'], fallback: 'Document');
    final description = _readString(source, ['description']);
    final fileUrl = _readString(source, ['file_url', 'fileUrl']);
    final thumbnailUrl = _readString(source, ['thumbnail_url', 'thumbnailUrl']);
    final categoryLabel = _readString(source, [
      'category_label',
      'categoryLabel',
    ]);
    final uploadState = _readString(source, [
      'upload_state',
      'uploadState',
    ], fallback: 'uploaded');
    final publishedAt = _readDate(source, ['published_at', 'publishedAt']);
    final isActive = _readBool(source, ['is_active', 'isActive']) ?? true;
    final sourceType = _readString(source, ['source'], fallback: 'remote');
    final updatedAt =
        _readDate(source, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    return _DocumentCenterRemote(
      itemId: itemId,
      tenantId: tenantId,
      contentType: contentType,
      title: title,
      description: description.isEmpty ? null : description,
      fileUrl: fileUrl.isEmpty ? null : fileUrl,
      thumbnailUrl: thumbnailUrl.isEmpty ? null : thumbnailUrl,
      categoryLabel: categoryLabel.isEmpty ? null : categoryLabel,
      uploadState: uploadState,
      publishedAt: publishedAt,
      isActive: isActive,
      source: sourceType,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
    );
  }

  _VisitorCommunicationRemote? _mapVisitorCommunicationRecord(
    Map<String, dynamic> source,
  ) {
    final entryId = _readString(source, [
      'entry_id',
      'entryId',
      'id',
      'external_id',
    ]);
    final tenantId = _readString(source, ['tenant_id', 'tenantId']);

    if (entryId.isEmpty || tenantId.isEmpty) {
      return null;
    }

    final operation = _readString(source, ['operation', 'op']);
    final isDeleted =
        (_readBool(source, ['is_deleted', 'isDeleted', 'deleted']) ?? false) ||
        operation.toLowerCase() == 'delete';

    final entryType = _readString(source, [
      'entry_type',
      'entryType',
    ], fallback: 'visitor');
    final visitorName = _readString(source, ['visitor_name', 'visitorName']);
    final purpose = _readString(source, ['purpose']);
    final phone = _readString(source, ['phone']);
    final checkInAt = _readDate(source, ['check_in_at', 'checkInAt']);
    final checkOutAt = _readDate(source, ['check_out_at', 'checkOutAt']);
    final statusLabel = _readString(source, [
      'status_label',
      'statusLabel',
    ], fallback: 'open');
    final note = _readString(source, ['note']);
    final isActive = _readBool(source, ['is_active', 'isActive']) ?? true;
    final sourceType = _readString(source, ['source'], fallback: 'remote');
    final updatedAt =
        _readDate(source, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    return _VisitorCommunicationRemote(
      entryId: entryId,
      tenantId: tenantId,
      entryType: entryType,
      visitorName: visitorName.isEmpty ? null : visitorName,
      purpose: purpose.isEmpty ? null : purpose,
      phone: phone.isEmpty ? null : phone,
      checkInAt: checkInAt,
      checkOutAt: checkOutAt,
      statusLabel: statusLabel,
      note: note.isEmpty ? null : note,
      isActive: isActive,
      source: sourceType,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
    );
  }

  _NotificationRemote? _mapNotificationRecord(Map<String, dynamic> source) {
    final notificationId = _readString(source, [
      'notification_id',
      'notificationId',
      'id',
      'external_id',
    ]);
    final tenantId = _readString(source, ['tenant_id', 'tenantId']);

    if (notificationId.isEmpty || tenantId.isEmpty) {
      return null;
    }

    final operation = _readString(source, ['operation', 'op']);
    final isDeleted =
        (_readBool(source, ['is_deleted', 'isDeleted', 'deleted']) ?? false) ||
        operation.toLowerCase() == 'delete';

    final notificationType = _readString(source, [
      'notification_type',
      'notificationType',
    ], fallback: 'general');
    final title = _readString(source, ['title'], fallback: 'Notification');
    final body = _readString(source, ['body', 'message']);
    final audience = _readString(source, ['audience'], fallback: 'all');
    final isRead = _readBool(source, ['is_read', 'isRead']) ?? false;
    final deliveryStatus = _readString(source, [
      'delivery_status',
      'deliveryStatus',
    ], fallback: 'queued');
    final sentAt = _readDate(source, ['sent_at', 'sentAt']);
    final readAt = _readDate(source, ['read_at', 'readAt']);
    final payloadJson = _readString(source, ['payload_json', 'payloadJson']);
    final isActive = _readBool(source, ['is_active', 'isActive']) ?? true;
    final sourceType = _readString(source, ['source'], fallback: 'remote');
    final updatedAt =
        _readDate(source, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    return _NotificationRemote(
      notificationId: notificationId,
      tenantId: tenantId,
      notificationType: notificationType,
      title: title,
      body: body.isEmpty ? null : body,
      audience: audience,
      isRead: isRead,
      deliveryStatus: deliveryStatus,
      sentAt: sentAt,
      readAt: readAt,
      payloadJson: payloadJson.isEmpty ? null : payloadJson,
      isActive: isActive,
      source: sourceType,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
    );
  }

  _LiveClassRemote? _mapLiveClassRecord(Map<String, dynamic> source) {
    final classId = _readString(source, [
      'class_id',
      'classId',
      'id',
      'external_id',
    ]);
    final tenantId = _readString(source, ['tenant_id', 'tenantId']);

    if (classId.isEmpty || tenantId.isEmpty) {
      return null;
    }

    final operation = _readString(source, ['operation', 'op']);
    final isDeleted =
        (_readBool(source, ['is_deleted', 'isDeleted', 'deleted']) ?? false) ||
        operation.toLowerCase() == 'delete';

    final providerType = _readString(source, [
      'provider_type',
      'providerType',
    ], fallback: 'zoom');
    final title = _readString(source, ['title'], fallback: 'Live Class');
    final classSection = _readString(source, ['class_section', 'classSection']);
    final hostName = _readString(source, ['host_name', 'hostName']);
    final startAt = _readDate(source, ['start_at', 'startAt']);
    final endAt = _readDate(source, ['end_at', 'endAt']);
    final joinUrl = _readString(source, ['join_url', 'joinUrl']);
    final meetingId = _readString(source, ['meeting_id', 'meetingId']);
    final meetingPassword = _readString(source, [
      'meeting_password',
      'meetingPassword',
    ]);
    final statusLabel = _readString(source, [
      'status_label',
      'statusLabel',
    ], fallback: 'scheduled');
    final isActive = _readBool(source, ['is_active', 'isActive']) ?? true;
    final sourceType = _readString(source, ['source'], fallback: 'remote');
    final updatedAt =
        _readDate(source, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    return _LiveClassRemote(
      classId: classId,
      tenantId: tenantId,
      providerType: providerType,
      title: title,
      classSection: classSection.isEmpty ? null : classSection,
      hostName: hostName.isEmpty ? null : hostName,
      startAt: startAt,
      endAt: endAt,
      joinUrl: joinUrl.isEmpty ? null : joinUrl,
      meetingId: meetingId.isEmpty ? null : meetingId,
      meetingPassword: meetingPassword.isEmpty ? null : meetingPassword,
      statusLabel: statusLabel,
      isActive: isActive,
      source: sourceType,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
    );
  }

  _StudentAttendanceRemote? _mapStudentAttendanceRecord(
    Map<String, dynamic> source,
  ) {
    final recordId = _readString(source, [
      'record_id',
      'recordId',
      'id',
      'external_id',
    ]);
    final tenantId = _readString(source, ['tenant_id', 'tenantId']);
    final studentId = _readString(source, ['student_id', 'studentId']);

    if (recordId.isEmpty || tenantId.isEmpty || studentId.isEmpty) {
      return null;
    }

    final status = _readString(source, ['status'], fallback: 'present');
    final sourceType = _readString(source, ['source'], fallback: 'remote');
    final attendanceDate =
        _readDate(source, [
          'attendance_date',
          'attendanceDate',
          'created_at',
          'created',
        ]) ??
        DateTime.now().toUtc();
    final updatedAt =
        _readDate(source, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    return _StudentAttendanceRemote(
      recordId: recordId,
      tenantId: tenantId,
      studentId: studentId,
      status: status,
      source: sourceType,
      attendanceDate: attendanceDate,
      updatedAt: updatedAt,
    );
  }

  _LeaveRequestRemote? _mapLeaveRequestRecord(Map<String, dynamic> source) {
    final leaveId = _readString(source, [
      'leave_id',
      'leaveId',
      'id',
      'external_id',
    ]);
    final tenantId = _readString(source, ['tenant_id', 'tenantId']);
    if (leaveId.isEmpty || tenantId.isEmpty) {
      return null;
    }

    final operation = _readString(source, ['operation', 'op']);
    final isDeleted =
        (_readBool(source, ['is_deleted', 'isDeleted', 'deleted']) ?? false) ||
        operation.toLowerCase() == 'delete';
    final requesterId = _readString(source, ['requester_id', 'requesterId']);
    final leaveFrom = _readDate(source, ['leave_from', 'leaveFrom']);
    final leaveTo = _readDate(source, ['leave_to', 'leaveTo']);
    final appliedAt = _readDate(source, ['applied_at', 'appliedAt']);
    final reason = _readString(source, ['reason']);
    final statusLabel = _readString(source, [
      'status_label',
      'statusLabel',
    ], fallback: 'pending');
    final approverName = _readString(source, ['approver_name', 'approverName']);
    final approvedAt = _readDate(source, ['approved_at', 'approvedAt']);
    final attachmentUrl = _readString(source, [
      'attachment_url',
      'attachmentUrl',
    ]);
    final isActive = _readBool(source, ['is_active', 'isActive']) ?? true;
    final sourceType = _readString(source, ['source'], fallback: 'remote');
    final updatedAt =
        _readDate(source, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    return _LeaveRequestRemote(
      leaveId: leaveId,
      tenantId: tenantId,
      requesterId: requesterId.isEmpty ? null : requesterId,
      leaveFrom: leaveFrom,
      leaveTo: leaveTo,
      appliedAt: appliedAt,
      reason: reason.isEmpty ? null : reason,
      statusLabel: statusLabel,
      approverName: approverName.isEmpty ? null : approverName,
      approvedAt: approvedAt,
      attachmentUrl: attachmentUrl.isEmpty ? null : attachmentUrl,
      isActive: isActive,
      source: sourceType,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
    );
  }

  _PendingTaskRemote? _mapPendingTaskRecord(Map<String, dynamic> source) {
    final taskId = _readString(source, [
      'task_id',
      'taskId',
      'id',
      'external_id',
    ]);
    final tenantId = _readString(source, ['tenant_id', 'tenantId']);
    if (taskId.isEmpty || tenantId.isEmpty) {
      return null;
    }

    final operation = _readString(source, ['operation', 'op']);
    final isDeleted =
        (_readBool(source, ['is_deleted', 'isDeleted', 'deleted']) ?? false) ||
        operation.toLowerCase() == 'delete';
    final userId = _readString(source, ['user_id', 'userId']);
    final title = _readString(source, ['title'], fallback: 'Task');
    final dueDate = _readDate(source, ['due_date', 'dueDate']);
    final statusLabel = _readString(source, [
      'status_label',
      'statusLabel',
    ], fallback: 'pending');
    final isCompleted =
        _readBool(source, ['is_completed', 'isCompleted']) ?? false;
    final priority = _readString(source, ['priority'], fallback: 'medium');
    final isActive = _readBool(source, ['is_active', 'isActive']) ?? true;
    final sourceType = _readString(source, ['source'], fallback: 'remote');
    final updatedAt =
        _readDate(source, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    return _PendingTaskRemote(
      taskId: taskId,
      tenantId: tenantId,
      userId: userId.isEmpty ? null : userId,
      title: title,
      dueDate: dueDate,
      statusLabel: statusLabel,
      isCompleted: isCompleted,
      priority: priority,
      isActive: isActive,
      source: sourceType,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
    );
  }

  _HostelRoomRemote? _mapHostelRoomRecord(Map<String, dynamic> source) {
    final roomId = _readString(source, [
      'room_id',
      'roomId',
      'id',
      'external_id',
    ]);
    final tenantId = _readString(source, ['tenant_id', 'tenantId']);
    if (roomId.isEmpty || tenantId.isEmpty) {
      return null;
    }

    final operation = _readString(source, ['operation', 'op']);
    final isDeleted =
        (_readBool(source, ['is_deleted', 'isDeleted', 'deleted']) ?? false) ||
        operation.toLowerCase() == 'delete';
    final studentId = _readString(source, ['student_id', 'studentId']);
    final hostelName = _readString(source, ['hostel_name', 'hostelName']);
    final roomNo = _readString(source, ['room_no', 'roomNo']);
    final roomType = _readString(source, ['room_type', 'roomType']);
    final floorNo = _readString(source, ['floor_no', 'floorNo']);
    final bedNo = _readString(source, ['bed_no', 'bedNo']);
    final wardenName = _readString(source, ['warden_name', 'wardenName']);
    final wardenContact = _readString(source, [
      'warden_contact',
      'wardenContact',
    ]);
    final monthlyFees =
        _readDouble(source, ['monthly_fees', 'monthlyFees']) ?? 0;
    final isActive = _readBool(source, ['is_active', 'isActive']) ?? true;
    final sourceType = _readString(source, ['source'], fallback: 'remote');
    final updatedAt =
        _readDate(source, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    return _HostelRoomRemote(
      roomId: roomId,
      tenantId: tenantId,
      studentId: studentId.isEmpty ? null : studentId,
      hostelName: hostelName.isEmpty ? null : hostelName,
      roomNo: roomNo.isEmpty ? null : roomNo,
      roomType: roomType.isEmpty ? null : roomType,
      floorNo: floorNo.isEmpty ? null : floorNo,
      bedNo: bedNo.isEmpty ? null : bedNo,
      wardenName: wardenName.isEmpty ? null : wardenName,
      wardenContact: wardenContact.isEmpty ? null : wardenContact,
      monthlyFees: monthlyFees,
      isActive: isActive,
      source: sourceType,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
    );
  }

  _StudentProfileRemote? _mapStudentProfileRecord(Map<String, dynamic> source) {
    final studentId = _readString(source, [
      'student_id',
      'studentId',
      'id',
      'external_id',
    ]);
    final tenantId = _readString(source, ['tenant_id', 'tenantId']);

    if (studentId.isEmpty || tenantId.isEmpty) {
      return null;
    }

    final admissionNo = _readString(source, [
      'admission_no',
      'admissionNo',
    ], fallback: studentId);
    final fullName = _readString(source, [
      'full_name',
      'fullName',
      'name',
    ], fallback: 'Unnamed Student');
    final classSection = _readString(source, ['class_section', 'classSection']);
    final isActive = _readBool(source, ['is_active', 'isActive']) ?? true;
    final updatedAt =
        _readDate(source, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    return _StudentProfileRemote(
      studentId: studentId,
      tenantId: tenantId,
      admissionNo: admissionNo,
      fullName: fullName,
      classSection: classSection.isEmpty ? null : classSection,
      isActive: isActive,
      updatedAt: updatedAt,
    );
  }

  _StudentGuardianRemote? _mapStudentGuardianRecord(
    Map<String, dynamic> source,
  ) {
    final guardianId = _readString(source, [
      'guardian_id',
      'guardianId',
      'id',
      'external_id',
    ]);
    final tenantId = _readString(source, ['tenant_id', 'tenantId']);
    final studentId = _readString(source, ['student_id', 'studentId']);

    if (guardianId.isEmpty || tenantId.isEmpty || studentId.isEmpty) {
      return null;
    }

    final fullName = _readString(source, ['full_name', 'fullName', 'name']);
    final relation = _readString(source, ['relation'], fallback: 'guardian');
    final phone = _readString(source, ['phone']);
    final email = _readString(source, ['email']);
    final isPrimary = _readBool(source, ['is_primary', 'isPrimary']) ?? false;
    final isActive = _readBool(source, ['is_active', 'isActive']) ?? true;
    final sourceType = _readString(source, ['source'], fallback: 'remote');
    final updatedAt =
        _readDate(source, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    return _StudentGuardianRemote(
      guardianId: guardianId,
      tenantId: tenantId,
      studentId: studentId,
      fullName: fullName,
      relation: relation,
      phone: phone.isEmpty ? null : phone,
      email: email.isEmpty ? null : email,
      isPrimary: isPrimary,
      isActive: isActive,
      source: sourceType,
      updatedAt: updatedAt,
    );
  }

  _StudentEnrollmentRemote? _mapStudentEnrollmentRecord(
    Map<String, dynamic> source,
  ) {
    final enrollmentId = _readString(source, [
      'enrollment_id',
      'enrollmentId',
      'id',
      'external_id',
    ]);
    final tenantId = _readString(source, ['tenant_id', 'tenantId']);
    final studentId = _readString(source, ['student_id', 'studentId']);

    if (enrollmentId.isEmpty || tenantId.isEmpty || studentId.isEmpty) {
      return null;
    }

    final academicSession = _readString(source, [
      'academic_session',
      'academicSession',
    ], fallback: 'current');
    final enrollmentStatus = _readString(source, [
      'enrollment_status',
      'enrollmentStatus',
      'status',
    ], fallback: 'enrolled');
    final enrolledOn = _readDate(source, ['enrolled_on', 'enrolledOn']);
    final leftOn = _readDate(source, ['left_on', 'leftOn']);
    final remarks = _readString(source, ['remarks']);
    final sourceType = _readString(source, ['source'], fallback: 'remote');
    final updatedAt =
        _readDate(source, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    return _StudentEnrollmentRemote(
      enrollmentId: enrollmentId,
      tenantId: tenantId,
      studentId: studentId,
      academicSession: academicSession,
      enrollmentStatus: enrollmentStatus,
      enrolledOn: enrolledOn,
      leftOn: leftOn,
      remarks: remarks.isEmpty ? null : remarks,
      source: sourceType,
      updatedAt: updatedAt,
    );
  }

  _StudentClassRollRemote? _mapStudentClassRollRecord(
    Map<String, dynamic> source,
  ) {
    final classRollId = _readString(source, [
      'class_roll_id',
      'classRollId',
      'id',
      'external_id',
    ]);
    final tenantId = _readString(source, ['tenant_id', 'tenantId']);
    final studentId = _readString(source, ['student_id', 'studentId']);

    if (classRollId.isEmpty || tenantId.isEmpty || studentId.isEmpty) {
      return null;
    }

    final academicSession = _readString(source, [
      'academic_session',
      'academicSession',
    ], fallback: 'current');
    final className = _readString(source, [
      'class_name',
      'className',
    ], fallback: 'Unknown');
    final sectionName = _readString(source, ['section_name', 'sectionName']);
    final rollNo = _readString(source, ['roll_no', 'rollNo']);
    final isActive = _readBool(source, ['is_active', 'isActive']) ?? true;
    final sourceType = _readString(source, ['source'], fallback: 'remote');
    final updatedAt =
        _readDate(source, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    return _StudentClassRollRemote(
      classRollId: classRollId,
      tenantId: tenantId,
      studentId: studentId,
      academicSession: academicSession,
      className: className,
      sectionName: sectionName.isEmpty ? null : sectionName,
      rollNo: rollNo.isEmpty ? null : rollNo,
      isActive: isActive,
      source: sourceType,
      updatedAt: updatedAt,
    );
  }

  _FeeInvoiceRemote? _mapFeeInvoiceRecord(Map<String, dynamic> source) {
    final recordId = _readString(source, [
      'record_id',
      'recordId',
      'id',
      'external_id',
    ]);
    final tenantId = _readString(source, ['tenant_id', 'tenantId']);
    final studentId = _readString(source, ['student_id', 'studentId']);

    if (recordId.isEmpty || tenantId.isEmpty || studentId.isEmpty) {
      return null;
    }

    final invoiceNo = _readString(source, [
      'invoice_no',
      'invoiceNo',
    ], fallback: recordId);
    final amountDue = _readDouble(source, ['amount_due', 'amountDue']) ?? 0;
    final amountPaid = _readDouble(source, ['amount_paid', 'amountPaid']) ?? 0;
    final status = _readString(source, ['status'], fallback: 'due');
    final dueDate = _readDate(source, ['due_date', 'dueDate']);
    final sourceType = _readString(source, ['source'], fallback: 'remote');
    final updatedAt =
        _readDate(source, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    return _FeeInvoiceRemote(
      recordId: recordId,
      tenantId: tenantId,
      studentId: studentId,
      invoiceNo: invoiceNo,
      amountDue: amountDue,
      amountPaid: amountPaid,
      status: status,
      dueDate: dueDate,
      source: sourceType,
      updatedAt: updatedAt,
    );
  }

  _FeePaymentRemote? _mapFeePaymentRecord(Map<String, dynamic> source) {
    final paymentId = _readString(source, [
      'payment_id',
      'paymentId',
      'id',
      'external_id',
    ]);
    final tenantId = _readString(source, ['tenant_id', 'tenantId']);
    final invoiceId = _readString(source, ['invoice_id', 'invoiceId']);
    final studentId = _readString(source, ['student_id', 'studentId']);

    if (paymentId.isEmpty ||
        tenantId.isEmpty ||
        invoiceId.isEmpty ||
        studentId.isEmpty) {
      return null;
    }

    final amount = _readDouble(source, ['amount']) ?? 0;
    final paidAt =
        _readDate(source, ['paid_at', 'paidAt', 'created_at', 'created']) ??
        DateTime.now().toUtc();
    final paymentMethod = _readString(source, [
      'payment_method',
      'paymentMethod',
    ], fallback: 'cash');
    final referenceNo = _readString(source, ['reference_no', 'referenceNo']);
    final sourceType = _readString(source, ['source'], fallback: 'remote');
    final updatedAt =
        _readDate(source, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    return _FeePaymentRemote(
      paymentId: paymentId,
      tenantId: tenantId,
      invoiceId: invoiceId,
      studentId: studentId,
      amount: amount,
      paidAt: paidAt,
      paymentMethod: paymentMethod,
      referenceNo: referenceNo.isEmpty ? null : referenceNo,
      source: sourceType,
      updatedAt: updatedAt,
    );
  }

  _ExamScheduleRemote? _mapExamScheduleRecord(Map<String, dynamic> source) {
    final scheduleId = _readString(source, [
      'schedule_id',
      'scheduleId',
      'id',
      'external_id',
    ]);
    final tenantId = _readString(source, ['tenant_id', 'tenantId']);
    if (scheduleId.isEmpty || tenantId.isEmpty) {
      return null;
    }

    final operation = _readString(source, ['operation', 'op']);
    final isDeleted =
        (_readBool(source, ['is_deleted', 'isDeleted', 'deleted']) ?? false) ||
        operation.toLowerCase() == 'delete';

    final examName = _readString(source, [
      'exam_name',
      'examName',
    ], fallback: 'Untitled Exam');
    final subjectName = _readString(source, [
      'subject_name',
      'subjectName',
    ], fallback: 'General');
    final maxMarks = _readDouble(source, ['max_marks', 'maxMarks']) ?? 100;
    final examDate =
        _readDate(source, ['exam_date', 'examDate', 'created_at', 'created']) ??
        DateTime.now().toUtc();
    final sourceType = _readString(source, ['source'], fallback: 'remote');
    final updatedAt =
        _readDate(source, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    return _ExamScheduleRemote(
      scheduleId: scheduleId,
      tenantId: tenantId,
      examName: examName,
      subjectName: subjectName,
      maxMarks: maxMarks,
      examDate: examDate,
      source: sourceType,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
    );
  }

  _ExamMarkRemote? _mapExamMarkRecord(Map<String, dynamic> source) {
    final markId = _readString(source, [
      'mark_id',
      'markId',
      'id',
      'external_id',
    ]);
    final tenantId = _readString(source, ['tenant_id', 'tenantId']);
    final studentId = _readString(source, ['student_id', 'studentId']);
    final scheduleId = _readString(source, ['schedule_id', 'scheduleId']);
    final operation = _readString(source, ['operation', 'op']);
    final isDeleted =
        (_readBool(source, ['is_deleted', 'isDeleted', 'deleted']) ?? false) ||
        operation.toLowerCase() == 'delete';

    if (markId.isEmpty || tenantId.isEmpty) {
      return null;
    }

    if (!isDeleted && (studentId.isEmpty || scheduleId.isEmpty)) {
      return null;
    }

    final marksObtained =
        _readDouble(source, ['marks_obtained', 'marksObtained']) ?? 0;
    final grade = _readString(source, ['grade']);
    final sourceType = _readString(source, ['source'], fallback: 'remote');
    final updatedAt =
        _readDate(source, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    return _ExamMarkRemote(
      markId: markId,
      tenantId: tenantId,
      studentId: studentId,
      scheduleId: scheduleId,
      marksObtained: marksObtained,
      grade: grade.isEmpty ? null : grade,
      source: sourceType,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
    );
  }

  String _readString(
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

  int? _readInt(Map<String, dynamic> source, List<String> keys) {
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

  double? _readDouble(Map<String, dynamic> source, List<String> keys) {
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

  bool? _readBool(Map<String, dynamic> source, List<String> keys) {
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

  DateTime? _readDate(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final raw = source[key];
      if (raw is DateTime) return raw.toUtc();
      if (raw == null) continue;

      final parsed = DateTime.tryParse(raw.toString());
      if (parsed != null) return parsed.toUtc();
    }
    return null;
  }

  // ── Homework Submissions ──────────────────────────────────────────────────

  Future<int> _pullHomeworkSubmissions({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(
      _homeworkSubmissionCheckpointKey,
    );
    final records = await pocketbaseGateway.pullHomeworkSubmissions(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapHomeworkSubmissionRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'homework_submission',
        tenantId: mapped.tenantId,
        entityId: mapped.submissionId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null || mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      if (mapped.isDeleted) {
        await database.deleteHomeworkSubmissionRecord(
          tenantId: mapped.tenantId,
          submissionId: mapped.submissionId,
        );
      } else {
        await database.upsertHomeworkSubmissionRecord(
          submissionId: mapped.submissionId,
          tenantId: mapped.tenantId,
          assignmentId: mapped.assignmentId,
          studentId: mapped.studentId,
          submissionText: mapped.submissionText,
          attachmentUrl: mapped.attachmentUrl,
          statusLabel: mapped.statusLabel,
          teacherFeedback: mapped.teacherFeedback,
          gradeScore: mapped.gradeScore,
          submittedAt: mapped.submittedAt,
          reviewedAt: mapped.reviewedAt,
          isActive: mapped.isActive,
          source: mapped.source,
          updatedAt: mapped.updatedAt,
        );
      }

      if (latestTimestamp == null || mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }
      upserts++;
    }

    if (latestTimestamp != null && (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _homeworkSubmissionCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  _HomeworkSubmissionRemote? _mapHomeworkSubmissionRecord(Map<String, dynamic> src) {
    final submissionId = _readString(src, ['submission_id', 'submissionId', 'id']);
    final tenantId = _readString(src, ['tenant_id', 'tenantId']);
    if (submissionId.isEmpty || tenantId.isEmpty) return null;

    final operation = _readString(src, ['operation', 'op']);
    final isDeleted =
        (_readBool(src, ['is_deleted', 'isDeleted', 'deleted']) ?? false) ||
        operation.toLowerCase() == 'delete';

    final updatedAt =
        _readDate(src, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    if (isDeleted) {
      return _HomeworkSubmissionRemote(
        submissionId: submissionId,
        tenantId: tenantId,
        assignmentId: '',
        studentId: '',
        statusLabel: 'submitted',
        isActive: false,
        source: 'remote',
        updatedAt: updatedAt,
        isDeleted: true,
      );
    }

    final assignmentId = _readString(src, ['assignment_id', 'assignmentId']);
    final studentId = _readString(src, ['student_id', 'studentId']);
    final submissionText = _readString(src, ['submission_text', 'submissionText']);
    final attachmentUrl = _readString(src, ['attachment_url', 'attachmentUrl']);
    final statusLabel = _readString(src, ['status_label', 'statusLabel'], fallback: 'submitted');
    final teacherFeedback = _readString(src, ['teacher_feedback', 'teacherFeedback']);
    final gradeScoreRaw = src['grade_score'] ?? src['gradeScore'];
    final gradeScore = gradeScoreRaw is num ? gradeScoreRaw.toDouble() : null;
    final submittedAt = _readDate(src, ['submitted_at', 'submittedAt']);
    final reviewedAt = _readDate(src, ['reviewed_at', 'reviewedAt']);
    final isActive = _readBool(src, ['is_active', 'isActive']) ?? true;
    final sourceType = _readString(src, ['source'], fallback: 'remote');

    return _HomeworkSubmissionRemote(
      submissionId: submissionId,
      tenantId: tenantId,
      assignmentId: assignmentId,
      studentId: studentId,
      submissionText: submissionText.isEmpty ? null : submissionText,
      attachmentUrl: attachmentUrl.isEmpty ? null : attachmentUrl,
      statusLabel: statusLabel,
      teacherFeedback: teacherFeedback.isEmpty ? null : teacherFeedback,
      gradeScore: gradeScore,
      submittedAt: submittedAt,
      reviewedAt: reviewedAt,
      isActive: isActive,
      source: sourceType,
      updatedAt: updatedAt,
      isDeleted: false,
    );
  }

  // ── Online Learning Attempts ──────────────────────────────────────────────

  Future<int> _pullOnlineLearningAttempts({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(
      _onlineLearningAttemptCheckpointKey,
    );
    final records = await pocketbaseGateway.pullOnlineLearningAttempts(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapOnlineLearningAttemptRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'online_learning_attempt',
        tenantId: mapped.tenantId,
        entityId: mapped.attemptId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null || mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      if (mapped.isDeleted) {
        await database.deleteOnlineLearningAttemptRecord(
          tenantId: mapped.tenantId,
          attemptId: mapped.attemptId,
        );
      } else {
        await database.upsertOnlineLearningAttemptRecord(
          attemptId: mapped.attemptId,
          tenantId: mapped.tenantId,
          itemId: mapped.itemId,
          studentId: mapped.studentId,
          attemptStatus: mapped.attemptStatus,
          scorePercent: mapped.scorePercent,
          durationSeconds: mapped.durationSeconds,
          startedAt: mapped.startedAt,
          completedAt: mapped.completedAt,
          isPassed: mapped.isPassed,
          isActive: mapped.isActive,
          source: mapped.source,
          updatedAt: mapped.updatedAt,
        );
      }

      if (latestTimestamp == null || mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }
      upserts++;
    }

    if (latestTimestamp != null && (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _onlineLearningAttemptCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }

    return upserts;
  }

  _OnlineLearningAttemptRemote? _mapOnlineLearningAttemptRecord(Map<String, dynamic> src) {
    final attemptId = _readString(src, ['attempt_id', 'attemptId', 'id']);
    final tenantId = _readString(src, ['tenant_id', 'tenantId']);
    if (attemptId.isEmpty || tenantId.isEmpty) return null;

    final operation = _readString(src, ['operation', 'op']);
    final isDeleted =
        (_readBool(src, ['is_deleted', 'isDeleted', 'deleted']) ?? false) ||
        operation.toLowerCase() == 'delete';

    final updatedAt =
        _readDate(src, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    if (isDeleted) {
      return _OnlineLearningAttemptRemote(
        attemptId: attemptId,
        tenantId: tenantId,
        itemId: '',
        studentId: '',
        attemptStatus: 'in_progress',
        isPassed: false,
        isActive: false,
        source: 'remote',
        updatedAt: updatedAt,
        isDeleted: true,
      );
    }

    final itemId = _readString(src, ['item_id', 'itemId']);
    final studentId = _readString(src, ['student_id', 'studentId']);
    final attemptStatus = _readString(src, ['attempt_status', 'attemptStatus'], fallback: 'in_progress');
    final scorePercentRaw = src['score_percent'] ?? src['scorePercent'];
    final scorePercent = scorePercentRaw is num ? scorePercentRaw.toDouble() : null;
    final durationSecondsRaw = src['duration_seconds'] ?? src['durationSeconds'];
    final durationSeconds = durationSecondsRaw is num ? durationSecondsRaw.toInt() : null;
    final startedAt = _readDate(src, ['started_at', 'startedAt']);
    final completedAt = _readDate(src, ['completed_at', 'completedAt']);
    final isPassed = _readBool(src, ['is_passed', 'isPassed']) ?? false;
    final isActive = _readBool(src, ['is_active', 'isActive']) ?? true;
    final sourceType = _readString(src, ['source'], fallback: 'remote');

    return _OnlineLearningAttemptRemote(
      attemptId: attemptId,
      tenantId: tenantId,
      itemId: itemId,
      studentId: studentId,
      attemptStatus: attemptStatus,
      scorePercent: scorePercent,
      durationSeconds: durationSeconds,
      startedAt: startedAt,
      completedAt: completedAt,
      isPassed: isPassed,
      isActive: isActive,
      source: sourceType,
      updatedAt: updatedAt,
      isDeleted: false,
    );
  }

  // ── Fee Groups ────────────────────────────────────────────────────────────

  Future<int> _pullFeeGroups({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(_feeGroupCheckpointKey);
    final records = await pocketbaseGateway.pullFeeGroups(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapFeeGroupRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'fee_group',
        tenantId: mapped.tenantId,
        entityId: mapped.feeId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null || mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      if (mapped.isDeleted) {
        await database.deleteFeeGroupRecord(
          tenantId: mapped.tenantId,
          feeId: mapped.feeId,
        );
      } else {
        await database.upsertFeeGroupRecord(
          feeId: mapped.feeId,
          tenantId: mapped.tenantId,
          studentId: mapped.studentId,
          feeTitle: mapped.feeTitle,
          feeCode: mapped.feeCode,
          amount: mapped.amount,
          discount: mapped.discount,
          fine: mapped.fine,
          paid: mapped.paid,
          balance: mapped.balance,
          status: mapped.status,
          dueDate: mapped.dueDate,
          isPayable: mapped.isPayable,
          feeType: mapped.feeType,
          source: mapped.source,
          updatedAt: mapped.updatedAt,
        );
      }

      if (latestTimestamp == null || mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }
      upserts++;
    }

    if (latestTimestamp != null && (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _feeGroupCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }
    return upserts;
  }

  _FeeGroupRemote? _mapFeeGroupRecord(Map<String, dynamic> src) {
    final feeId = _readString(src, ['fee_id', 'feeId', 'id']);
    final tenantId = _readString(src, ['tenant_id', 'tenantId']);
    if (feeId.isEmpty || tenantId.isEmpty) return null;

    final operation = _readString(src, ['operation', 'op']);
    final isDeleted =
        (_readBool(src, ['is_deleted', 'isDeleted', 'deleted']) ?? false) ||
        operation.toLowerCase() == 'delete';

    final updatedAt =
        _readDate(src, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    if (isDeleted) {
      return _FeeGroupRemote(
        feeId: feeId,
        tenantId: tenantId,
        studentId: '',
        feeTitle: '',
        status: 'unpaid',
        feeType: 'fee',
        isPayable: false,
        source: 'remote',
        updatedAt: updatedAt,
        isDeleted: true,
      );
    }

    final studentId = _readString(src, ['student_id', 'studentId']);
    final feeTitle = _readString(src, ['fee_title', 'feeTitle', 'title'], fallback: 'Fee');
    final feeCode = _readString(src, ['fee_code', 'feeCode', 'code']);
    final amount = _readDouble(src, ['amount']) ?? 0;
    final discount = _readDouble(src, ['discount']) ?? 0;
    final fine = _readDouble(src, ['fine']) ?? 0;
    final paid = _readDouble(src, ['paid', 'paid_amount']) ?? 0;
    final balance = _readDouble(src, ['balance', 'balance_amount']) ?? 0;
    final status = _readString(src, ['status'], fallback: 'unpaid');
    final dueDate = _readString(src, ['due_date', 'dueDate']);
    final isPayable = _readBool(src, ['is_payable', 'isPayable']) ?? false;
    final feeType = _readString(src, ['fee_type', 'feeType'], fallback: 'fee');
    final sourceType = _readString(src, ['source'], fallback: 'remote');

    return _FeeGroupRemote(
      feeId: feeId,
      tenantId: tenantId,
      studentId: studentId,
      feeTitle: feeTitle,
      feeCode: feeCode.isEmpty ? null : feeCode,
      amount: amount,
      discount: discount,
      fine: fine,
      paid: paid,
      balance: balance,
      status: status,
      dueDate: dueDate.isEmpty ? null : dueDate,
      isPayable: isPayable,
      feeType: feeType,
      source: sourceType,
      updatedAt: updatedAt,
      isDeleted: false,
    );
  }

  // ── CBSE Exam Results ─────────────────────────────────────────────────────

  Future<int> _pullCbseExamResults({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(_cbseExamResultCheckpointKey);
    final records = await pocketbaseGateway.pullCbseExamResults(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapCbseExamResultRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'cbse_exam_result',
        tenantId: mapped.tenantId,
        entityId: mapped.resultId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null || mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      if (mapped.isDeleted) {
        await database.deleteCbseExamResultRecord(
          tenantId: mapped.tenantId,
          resultId: mapped.resultId,
        );
      } else {
        await database.upsertCbseExamResultRecord(
          resultId: mapped.resultId,
          tenantId: mapped.tenantId,
          studentId: mapped.studentId,
          examName: mapped.examName,
          subjectName: mapped.subjectName,
          subjectCode: mapped.subjectCode,
          assessmentName: mapped.assessmentName,
          marksObtained: mapped.marksObtained,
          maxMarks: mapped.maxMarks,
          examDate: mapped.examDate,
          grade: mapped.grade,
          rank: mapped.rank,
          percentage: mapped.percentage,
          resultType: mapped.resultType,
          roomNo: mapped.roomNo,
          timeFrom: mapped.timeFrom,
          duration: mapped.duration,
          source: mapped.source,
          updatedAt: mapped.updatedAt,
        );
      }

      if (latestTimestamp == null || mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }
      upserts++;
    }

    if (latestTimestamp != null && (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _cbseExamResultCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }
    return upserts;
  }

  _CbseExamResultRemote? _mapCbseExamResultRecord(Map<String, dynamic> src) {
    final resultId = _readString(src, ['result_id', 'resultId', 'id']);
    final tenantId = _readString(src, ['tenant_id', 'tenantId']);
    if (resultId.isEmpty || tenantId.isEmpty) return null;

    final operation = _readString(src, ['operation', 'op']);
    final isDeleted =
        (_readBool(src, ['is_deleted', 'isDeleted', 'deleted']) ?? false) ||
        operation.toLowerCase() == 'delete';

    final updatedAt =
        _readDate(src, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    if (isDeleted) {
      return _CbseExamResultRemote(
        resultId: resultId,
        tenantId: tenantId,
        studentId: '',
        examName: '',
        subjectName: '',
        resultType: 'result',
        source: 'remote',
        updatedAt: updatedAt,
        isDeleted: true,
      );
    }

    final studentId = _readString(src, ['student_id', 'studentId']);
    final examName = _readString(src, ['exam_name', 'examName', 'name'], fallback: 'Exam');
    final subjectName = _readString(src, ['subject_name', 'subjectName']);
    final subjectCode = _readString(src, ['subject_code', 'subjectCode']);
    final assessmentName = _readString(src, ['assessment_name', 'assessmentName']);
    final marksObtained = _readDouble(src, ['marks_obtained', 'marksObtained', 'marks']);
    final maxMarks = _readDouble(src, ['max_marks', 'maxMarks', 'maximum_marks']);
    final examDate = _readString(src, ['exam_date', 'examDate', 'date']);
    final grade = _readString(src, ['grade']);
    final rank = _readString(src, ['rank', 'exam_rank']);
    final percentage = _readString(src, ['percentage', 'exam_percentage']);
    final totalObtained = _readString(src, ['total_obtained', 'totalObtained', 'exam_obtain_marks']);
    final totalMax = _readString(src, ['total_max', 'totalMax', 'exam_total_marks']);
    final resultType = _readString(src, ['result_type', 'resultType'], fallback: 'result');
    final roomNo = _readString(src, ['room_no', 'roomNo']);
    final timeFrom = _readString(src, ['time_from', 'timeFrom']);
    final duration = _readString(src, ['duration']);
    final sourceType = _readString(src, ['source'], fallback: 'remote');

    return _CbseExamResultRemote(
      resultId: resultId,
      tenantId: tenantId,
      studentId: studentId,
      examName: examName,
      subjectName: subjectName,
      subjectCode: subjectCode.isEmpty ? null : subjectCode,
      assessmentName: assessmentName.isEmpty ? null : assessmentName,
      marksObtained: marksObtained,
      maxMarks: maxMarks,
      examDate: examDate.isEmpty ? null : examDate,
      grade: grade.isEmpty ? null : grade,
      rank: rank.isEmpty ? null : rank,
      percentage: percentage.isEmpty ? null : percentage,
      totalObtained: totalObtained.isEmpty ? null : totalObtained,
      totalMax: totalMax.isEmpty ? null : totalMax,
      resultType: resultType,
      roomNo: roomNo.isEmpty ? null : roomNo,
      timeFrom: timeFrom.isEmpty ? null : timeFrom,
      duration: duration.isEmpty ? null : duration,
      source: sourceType,
      updatedAt: updatedAt,
      isDeleted: false,
    );
  }

  // ── Online Exams ──────────────────────────────────────────────────────────

  Future<int> _pullOnlineExams({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(_onlineExamCheckpointKey);
    final records = await pocketbaseGateway.pullOnlineExams(
      since: since,
      tenantId: scopedTenantId,
    );

    int upserts = 0;
    DateTime? latestTimestamp = since;

    for (final record in records) {
      final mapped = _mapOnlineExamRecord(record);
      if (mapped == null) continue;
      if (scopedTenantId != null && mapped.tenantId != scopedTenantId) continue;

      final shouldApply = await _shouldApplyRemoteRecord(
        entityType: 'online_exam',
        tenantId: mapped.tenantId,
        entityId: mapped.examId,
        remoteUpdatedAt: mapped.updatedAt,
      );
      if (!shouldApply) {
        if (latestTimestamp == null || mapped.updatedAt.isAfter(latestTimestamp)) {
          latestTimestamp = mapped.updatedAt;
        }
        continue;
      }

      if (mapped.isDeleted) {
        await database.deleteOnlineExamRecord(
          tenantId: mapped.tenantId,
          examId: mapped.examId,
        );
      } else {
        await database.upsertOnlineExamRecord(
          examId: mapped.examId,
          tenantId: mapped.tenantId,
          examTitle: mapped.examTitle,
          description: mapped.description,
          examFrom: mapped.examFrom,
          examTo: mapped.examTo,
          totalQuestions: mapped.totalQuestions,
          totalAttempt: mapped.totalAttempt,
          durationMinutes: mapped.durationMinutes,
          passingPercent: mapped.passingPercent,
          isQuiz: mapped.isQuiz,
          statusLabel: mapped.statusLabel,
          attemptCount: mapped.attemptCount,
          isSubmitted: mapped.isSubmitted,
          lastScorePercent: mapped.lastScorePercent,
          isPassed: mapped.isPassed,
          isActive: mapped.isActive,
          source: mapped.source,
          updatedAt: mapped.updatedAt,
        );
      }

      if (latestTimestamp == null || mapped.updatedAt.isAfter(latestTimestamp)) {
        latestTimestamp = mapped.updatedAt;
      }
      upserts++;
    }

    if (latestTimestamp != null && (since == null || latestTimestamp.isAfter(since))) {
      await database.setLastPullCheckpoint(
        entityType: _onlineExamCheckpointKey,
        checkpoint: latestTimestamp,
      );
    }
    return upserts;
  }

  _OnlineExamRemote? _mapOnlineExamRecord(Map<String, dynamic> src) {
    final examId = _readString(src, ['exam_id', 'examId', 'id']);
    final tenantId = _readString(src, ['tenant_id', 'tenantId']);
    if (examId.isEmpty || tenantId.isEmpty) return null;

    final operation = _readString(src, ['operation', 'op']);
    final isDeleted =
        (_readBool(src, ['is_deleted', 'isDeleted', 'deleted']) ?? false) ||
        operation.toLowerCase() == 'delete';

    final updatedAt =
        _readDate(src, ['updated_at', 'updatedAt', 'updated']) ??
        DateTime.now().toUtc();

    if (isDeleted) {
      return _OnlineExamRemote(
        examId: examId,
        tenantId: tenantId,
        examTitle: '',
        statusLabel: 'upcoming',
        isActive: false,
        source: 'remote',
        updatedAt: updatedAt,
        isDeleted: true,
      );
    }

    final examTitle = _readString(src, ['exam_title', 'examTitle', 'title', 'exam'], fallback: 'Exam');
    final description = _readString(src, ['description', 'instructions']);
    final examFrom = _readString(src, ['exam_from', 'examFrom']);
    final examTo = _readString(src, ['exam_to', 'examTo']);
    final totalQuestions = _readInt(src, ['total_question', 'total_questions', 'totalQuestions']) ?? 0;
    final totalAttempt = _readInt(src, ['total_attempt', 'totalAttempt', 'attempt']) ?? 1;
    final durationMinutes = _readInt(src, ['duration', 'duration_minutes', 'durationMinutes', 'time_duration']) ?? 0;
    final passingPercent = _readDouble(src, ['passing_percentage', 'passingPercent', 'passing_percent']) ?? 35;
    final isQuiz = _readBool(src, ['is_quiz', 'isQuiz']) ?? false;
    final statusLabel = _readString(src, ['status', 'statusLabel', 'status_label'], fallback: 'upcoming');
    final attemptCount = _readInt(src, ['counter', 'attempt_count', 'attemptCount', 'is_attempted']) ?? 0;
    final isSubmitted = _readBool(src, ['is_submitted', 'isSubmitted']) ?? false;
    final lastScorePercent = _readDouble(src, ['last_score_percent', 'lastScorePercent']);
    final isPassed = _readBool(src, ['is_passed', 'isPassed']) ?? false;
    final isActive = _readBool(src, ['is_active', 'isActive']) ?? true;
    final sourceType = _readString(src, ['source'], fallback: 'remote');

    return _OnlineExamRemote(
      examId: examId,
      tenantId: tenantId,
      examTitle: examTitle,
      description: description.isEmpty ? null : description,
      examFrom: examFrom.isEmpty ? null : examFrom,
      examTo: examTo.isEmpty ? null : examTo,
      totalQuestions: totalQuestions,
      totalAttempt: totalAttempt,
      durationMinutes: durationMinutes,
      passingPercent: passingPercent,
      isQuiz: isQuiz,
      statusLabel: statusLabel,
      attemptCount: attemptCount,
      isSubmitted: isSubmitted,
      lastScorePercent: lastScorePercent,
      isPassed: isPassed,
      isActive: isActive,
      source: sourceType,
      updatedAt: updatedAt,
      isDeleted: false,
    );
  }

  // ── Student Behaviour pull/map ────────────────────────────────────────────

  Future<int> _pullStudentBehaviour({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(_studentBehaviourCheckpointKey);
    final records = await pocketbaseGateway.pullStudentBehaviour(since: since, tenantId: scopedTenantId);
    int upserts = 0;
    DateTime? latest = since;
    for (final record in records) {
      final m = _mapStudentBehaviourRecord(record);
      if (m == null) continue;
      if (scopedTenantId != null && m.tenantId != scopedTenantId) continue;
      final apply = await _shouldApplyRemoteRecord(entityType: 'student_behaviour', tenantId: m.tenantId, entityId: m.incidentId, remoteUpdatedAt: m.updatedAt);
      if (!apply) { if (latest == null || m.updatedAt.isAfter(latest)) latest = m.updatedAt; continue; }
      if (m.isDeleted) {
        await database.deleteStudentBehaviourRecord(tenantId: m.tenantId, incidentId: m.incidentId);
      } else {
        await database.upsertStudentBehaviourRecord(incidentId: m.incidentId, tenantId: m.tenantId, studentId: m.studentId, title: m.title, description: m.description, point: m.point, isPositive: m.isPositive, assignedBy: m.assignedBy, incidentDate: m.incidentDate, commentCount: m.commentCount, source: m.source, updatedAt: m.updatedAt);
      }
      if (latest == null || m.updatedAt.isAfter(latest)) latest = m.updatedAt;
      upserts++;
    }
    if (latest != null && (since == null || latest.isAfter(since))) {
      await database.setLastPullCheckpoint(entityType: _studentBehaviourCheckpointKey, checkpoint: latest);
    }
    return upserts;
  }

  _StudentBehaviourRemote? _mapStudentBehaviourRecord(Map<String, dynamic> src) {
    final incidentId = _readString(src, ['incident_id', 'incidentId', 'id']);
    final tenantId = _readString(src, ['tenant_id', 'tenantId']);
    if (incidentId.isEmpty || tenantId.isEmpty) return null;
    final operation = _readString(src, ['operation', 'op']);
    final isDeleted = (_readBool(src, ['is_deleted', 'isDeleted', 'deleted']) ?? false) || operation.toLowerCase() == 'delete';
    final updatedAt = _readDate(src, ['updated_at', 'updatedAt', 'updated']) ?? DateTime.now().toUtc();
    if (isDeleted) return _StudentBehaviourRemote(incidentId: incidentId, tenantId: tenantId, studentId: '', title: '', source: 'remote', updatedAt: updatedAt, isDeleted: true);
    final studentId = _readString(src, ['student_id', 'studentId']);
    final title = _readString(src, ['title'], fallback: 'Incident');
    final description = _readString(src, ['description']);
    final point = _readString(src, ['point'], fallback: '0');
    final isPositive = _readBool(src, ['is_positive', 'isPositive']) ?? true;
    final assignedBy = _readString(src, ['assigned_by', 'assignedBy']);
    final incidentDate = _readString(src, ['incident_date', 'incidentDate', 'date']);
    final commentCountRaw = src['comment_count'] ?? src['commentCount'];
    final commentCount = commentCountRaw is num ? commentCountRaw.toInt() : 0;
    final sourceType = _readString(src, ['source'], fallback: 'remote');
    return _StudentBehaviourRemote(incidentId: incidentId, tenantId: tenantId, studentId: studentId, title: title, description: description.isEmpty ? null : description, point: point, isPositive: isPositive, assignedBy: assignedBy.isEmpty ? null : assignedBy, incidentDate: incidentDate.isEmpty ? null : incidentDate, commentCount: commentCount, source: sourceType, updatedAt: updatedAt, isDeleted: false);
  }

  // ── Behaviour Comments pull/map ───────────────────────────────────────────

  Future<int> _pullBehaviourComments({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(_behaviourCommentCheckpointKey);
    final records = await pocketbaseGateway.pullBehaviourComments(since: since, tenantId: scopedTenantId);
    int upserts = 0;
    DateTime? latest = since;
    for (final record in records) {
      final m = _mapBehaviourCommentRecord(record);
      if (m == null) continue;
      if (scopedTenantId != null && m.tenantId != scopedTenantId) continue;
      final apply = await _shouldApplyRemoteRecord(entityType: 'behaviour_comment', tenantId: m.tenantId, entityId: m.commentId, remoteUpdatedAt: m.updatedAt);
      if (!apply) { if (latest == null || m.updatedAt.isAfter(latest)) latest = m.updatedAt; continue; }
      if (m.isDeleted) {
        await database.deleteBehaviourCommentRecord(tenantId: m.tenantId, commentId: m.commentId);
      } else {
        await database.upsertBehaviourCommentRecord(commentId: m.commentId, tenantId: m.tenantId, incidentId: m.incidentId, commentText: m.commentText, commentedBy: m.commentedBy, commentDate: m.commentDate, source: m.source, updatedAt: m.updatedAt);
      }
      if (latest == null || m.updatedAt.isAfter(latest)) latest = m.updatedAt;
      upserts++;
    }
    if (latest != null && (since == null || latest.isAfter(since))) {
      await database.setLastPullCheckpoint(entityType: _behaviourCommentCheckpointKey, checkpoint: latest);
    }
    return upserts;
  }

  _BehaviourCommentRemote? _mapBehaviourCommentRecord(Map<String, dynamic> src) {
    final commentId = _readString(src, ['comment_id', 'commentId', 'id']);
    final tenantId = _readString(src, ['tenant_id', 'tenantId']);
    if (commentId.isEmpty || tenantId.isEmpty) return null;
    final operation = _readString(src, ['operation', 'op']);
    final isDeleted = (_readBool(src, ['is_deleted', 'isDeleted', 'deleted']) ?? false) || operation.toLowerCase() == 'delete';
    final updatedAt = _readDate(src, ['updated_at', 'updatedAt', 'updated']) ?? DateTime.now().toUtc();
    if (isDeleted) return _BehaviourCommentRemote(commentId: commentId, tenantId: tenantId, incidentId: '', commentText: '', source: 'remote', updatedAt: updatedAt, isDeleted: true);
    final incidentId = _readString(src, ['incident_id', 'incidentId']);
    final commentText = _readString(src, ['comment_text', 'commentText', 'comment'], fallback: '');
    final commentedBy = _readString(src, ['commented_by', 'commentedBy']);
    final commentDate = _readString(src, ['comment_date', 'commentDate', 'date']);
    final sourceType = _readString(src, ['source'], fallback: 'remote');
    return _BehaviourCommentRemote(commentId: commentId, tenantId: tenantId, incidentId: incidentId, commentText: commentText, commentedBy: commentedBy.isEmpty ? null : commentedBy, commentDate: commentDate.isEmpty ? null : commentDate, source: sourceType, updatedAt: updatedAt, isDeleted: false);
  }

  // ── Teachers pull/map ─────────────────────────────────────────────────────

  Future<int> _pullTeachers({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(_teacherCheckpointKey);
    final records = await pocketbaseGateway.pullTeachers(since: since, tenantId: scopedTenantId);
    int upserts = 0;
    DateTime? latest = since;
    for (final record in records) {
      final m = _mapTeacherRecord(record);
      if (m == null) continue;
      if (scopedTenantId != null && m.tenantId != scopedTenantId) continue;
      final apply = await _shouldApplyRemoteRecord(entityType: 'teacher', tenantId: m.tenantId, entityId: m.teacherId, remoteUpdatedAt: m.updatedAt);
      if (!apply) { if (latest == null || m.updatedAt.isAfter(latest)) latest = m.updatedAt; continue; }
      if (m.isDeleted) {
        await database.deleteTeacherRecord(tenantId: m.tenantId, teacherId: m.teacherId);
      } else {
        await database.upsertTeacherRecord(teacherId: m.teacherId, tenantId: m.tenantId, fullName: m.fullName, employeeNo: m.employeeNo, subjectName: m.subjectName, qualification: m.qualification, email: m.email, phone: m.phone, designation: m.designation, isClassTeacher: m.isClassTeacher, imageUrl: m.imageUrl, ratingScore: m.ratingScore, reviewComment: m.reviewComment, hasReviewed: m.hasReviewed, isActive: m.isActive, source: m.source, updatedAt: m.updatedAt);
      }
      if (latest == null || m.updatedAt.isAfter(latest)) latest = m.updatedAt;
      upserts++;
    }
    if (latest != null && (since == null || latest.isAfter(since))) {
      await database.setLastPullCheckpoint(entityType: _teacherCheckpointKey, checkpoint: latest);
    }
    return upserts;
  }

  _TeacherRemote? _mapTeacherRecord(Map<String, dynamic> src) {
    final teacherId = _readString(src, ['teacher_id', 'teacherId', 'staff_id', 'id']);
    final tenantId = _readString(src, ['tenant_id', 'tenantId']);
    if (teacherId.isEmpty || tenantId.isEmpty) return null;
    final operation = _readString(src, ['operation', 'op']);
    final isDeleted = (_readBool(src, ['is_deleted', 'isDeleted', 'deleted']) ?? false) || operation.toLowerCase() == 'delete';
    final updatedAt = _readDate(src, ['updated_at', 'updatedAt', 'updated']) ?? DateTime.now().toUtc();
    if (isDeleted) return _TeacherRemote(teacherId: teacherId, tenantId: tenantId, fullName: '', isActive: false, source: 'remote', updatedAt: updatedAt, isDeleted: true);
    final firstName = _readString(src, ['staff_name', 'first_name', 'firstName']);
    final lastName = _readString(src, ['staff_surname', 'last_name', 'lastName']);
    final fullName = _readString(src, ['full_name', 'fullName', 'name']).isNotEmpty
        ? _readString(src, ['full_name', 'fullName', 'name'])
        : '$firstName $lastName'.trim().isNotEmpty ? '$firstName $lastName'.trim() : 'Teacher';
    final employeeNo = _readString(src, ['employee_no', 'employeeNo', 'staff_no', 'employee_id']);
    final subjectName = _readString(src, ['subject_name', 'subjectName', 'subject']);
    final qualification = _readString(src, ['qualification']);
    final email = _readString(src, ['email']);
    final phone = _readString(src, ['phone', 'contact_no']);
    final designation = _readString(src, ['designation']);
    final isClassTeacher = _readBool(src, ['is_class_teacher', 'isClassTeacher', 'class_teacher']) ?? false;
    final imageUrl = _readString(src, ['image_url', 'imageUrl', 'image', 'staff_image']);
    final ratingScoreRaw = src['rating_score'] ?? src['ratingScore'] ?? src['rate'];
    final ratingScore = ratingScoreRaw is num ? ratingScoreRaw.toInt() : int.tryParse(ratingScoreRaw?.toString() ?? '') ?? 0;
    final reviewComment = _readString(src, ['review_comment', 'reviewComment', 'comment', 'comments']);
    final hasReviewed = ratingScore > 0;
    final isActive = _readBool(src, ['is_active', 'isActive']) ?? true;
    final sourceType = _readString(src, ['source'], fallback: 'remote');
    return _TeacherRemote(teacherId: teacherId, tenantId: tenantId, fullName: fullName, employeeNo: employeeNo.isEmpty ? null : employeeNo, subjectName: subjectName.isEmpty ? null : subjectName, qualification: qualification.isEmpty ? null : qualification, email: email.isEmpty ? null : email, phone: phone.isEmpty ? null : phone, designation: designation.isEmpty ? null : designation, isClassTeacher: isClassTeacher, imageUrl: imageUrl.isEmpty ? null : imageUrl, ratingScore: ratingScore, reviewComment: reviewComment.isEmpty ? null : reviewComment, hasReviewed: hasReviewed, isActive: isActive, source: sourceType, updatedAt: updatedAt, isDeleted: false);
  }

  // ── Online Lessons pull/map ───────────────────────────────────────────────

  Future<int> _pullOnlineLessons({String? scopedTenantId}) async {
    final since = await database.getLastPullCheckpoint(_onlineLessonCheckpointKey);
    final records = await pocketbaseGateway.pullOnlineLessons(since: since, tenantId: scopedTenantId);
    int upserts = 0;
    DateTime? latest = since;
    for (final record in records) {
      final m = _mapOnlineLessonRecord(record);
      if (m == null) continue;
      if (scopedTenantId != null && m.tenantId != scopedTenantId) continue;
      final apply = await _shouldApplyRemoteRecord(entityType: 'online_lesson', tenantId: m.tenantId, entityId: m.lessonId, remoteUpdatedAt: m.updatedAt);
      if (!apply) { if (latest == null || m.updatedAt.isAfter(latest)) latest = m.updatedAt; continue; }
      if (m.isDeleted) {
        await database.deleteOnlineLessonRecord(tenantId: m.tenantId, lessonId: m.lessonId);
      } else {
        await database.upsertOnlineLessonRecord(lessonId: m.lessonId, tenantId: m.tenantId, itemId: m.itemId, title: m.title, contentType: m.contentType, contentUrl: m.contentUrl, description: m.description, sortOrder: m.sortOrder, durationSeconds: m.durationSeconds, isCompleted: m.isCompleted, isActive: m.isActive, source: m.source, updatedAt: m.updatedAt);
      }
      if (latest == null || m.updatedAt.isAfter(latest)) latest = m.updatedAt;
      upserts++;
    }
    if (latest != null && (since == null || latest.isAfter(since))) {
      await database.setLastPullCheckpoint(entityType: _onlineLessonCheckpointKey, checkpoint: latest);
    }
    return upserts;
  }

  _OnlineLessonRemote? _mapOnlineLessonRecord(Map<String, dynamic> src) {
    final lessonId = _readString(src, ['lesson_id', 'lessonId', 'id']);
    final tenantId = _readString(src, ['tenant_id', 'tenantId']);
    if (lessonId.isEmpty || tenantId.isEmpty) return null;
    final operation = _readString(src, ['operation', 'op']);
    final isDeleted = (_readBool(src, ['is_deleted', 'isDeleted', 'deleted']) ?? false) || operation.toLowerCase() == 'delete';
    final updatedAt = _readDate(src, ['updated_at', 'updatedAt', 'updated']) ?? DateTime.now().toUtc();
    if (isDeleted) return _OnlineLessonRemote(lessonId: lessonId, tenantId: tenantId, itemId: '', title: '', source: 'remote', updatedAt: updatedAt, isDeleted: true);
    final itemId = _readString(src, ['item_id', 'itemId', 'course_id']);
    final title = _readString(src, ['title'], fallback: 'Lesson');
    final contentType = _readString(src, ['content_type', 'contentType'], fallback: 'video');
    final contentUrl = _readString(src, ['content_url', 'contentUrl', 'url', 'video_url']);
    final description = _readString(src, ['description']);
    final sortOrder = _readInt(src, ['sort_order', 'sortOrder', 'order']) ?? 0;
    final durationSeconds = _readInt(src, ['duration_seconds', 'durationSeconds', 'duration']) ?? 0;
    final isCompleted = _readBool(src, ['is_completed', 'isCompleted']) ?? false;
    final isActive = _readBool(src, ['is_active', 'isActive']) ?? true;
    final sourceType = _readString(src, ['source'], fallback: 'remote');
    return _OnlineLessonRemote(lessonId: lessonId, tenantId: tenantId, itemId: itemId, title: title, contentType: contentType, contentUrl: contentUrl.isEmpty ? null : contentUrl, description: description.isEmpty ? null : description, sortOrder: sortOrder, durationSeconds: durationSeconds, isCompleted: isCompleted, isActive: isActive, source: sourceType, updatedAt: updatedAt, isDeleted: false);
  }
}

class _TenantLicenseRemote {
  const _TenantLicenseRemote({
    required this.licenseId,
    required this.tenantId,
    required this.tenantName,
    required this.schoolOwnerEmail,
    required this.planCode,
    required this.seatLimit,
    required this.isActive,
    required this.issuedAt,
    required this.updatedAt,
    required this.expiresAt,
  });

  final String licenseId;
  final String tenantId;
  final String tenantName;
  final String schoolOwnerEmail;
  final String planCode;
  final int seatLimit;
  final bool isActive;
  final DateTime issuedAt;
  final DateTime updatedAt;
  final DateTime? expiresAt;
}

class _SchoolOwnerRemote {
  const _SchoolOwnerRemote({
    required this.ownerId,
    required this.tenantId,
    required this.tenantName,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.isPrimary,
    required this.isActive,
    required this.provisioningStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  final String ownerId;
  final String tenantId;
  final String tenantName;
  final String fullName;
  final String email;
  final String? phone;
  final bool isPrimary;
  final bool isActive;
  final String provisioningStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class _TenantUsageMetricRemote {
  const _TenantUsageMetricRemote({
    required this.metricId,
    required this.tenantId,
    required this.periodKey,
    required this.activeStudents,
    required this.activeStaff,
    required this.monthlyActiveUsers,
    required this.storageGb,
    required this.outstandingAmount,
    required this.collectedAmount,
    required this.overdueInvoices,
    required this.nextBillingAt,
    required this.billingStatus,
    required this.source,
    required this.updatedAt,
  });

  final String metricId;
  final String tenantId;
  final String periodKey;
  final int activeStudents;
  final int activeStaff;
  final int monthlyActiveUsers;
  final double storageGb;
  final double outstandingAmount;
  final double collectedAmount;
  final int overdueInvoices;
  final DateTime? nextBillingAt;
  final String billingStatus;
  final String source;
  final DateTime updatedAt;
}

class _TenantFeatureFlagRemote {
  const _TenantFeatureFlagRemote({
    required this.flagId,
    required this.tenantId,
    required this.featureKey,
    required this.isEnabled,
    required this.source,
    required this.updatedAt,
  });

  final String flagId;
  final String tenantId;
  final String featureKey;
  final bool isEnabled;
  final String source;
  final DateTime updatedAt;
}

class _NoticeBoardRemote {
  const _NoticeBoardRemote({
    required this.noticeId,
    required this.tenantId,
    required this.title,
    required this.message,
    required this.audience,
    required this.publishAt,
    required this.expiresAt,
    required this.isPublished,
    required this.source,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String noticeId;
  final String tenantId;
  final String title;
  final String message;
  final String audience;
  final DateTime publishAt;
  final DateTime? expiresAt;
  final bool isPublished;
  final String source;
  final DateTime updatedAt;
  final bool isDeleted;
}

class _TimetableSlotRemote {
  const _TimetableSlotRemote({
    required this.slotId,
    required this.tenantId,
    required this.dayOfWeek,
    required this.periodIndex,
    required this.subjectName,
    required this.teacherName,
    required this.roomNo,
    required this.timeFrom,
    required this.timeTo,
    required this.classSection,
    required this.isActive,
    required this.source,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String slotId;
  final String tenantId;
  final String dayOfWeek;
  final int periodIndex;
  final String subjectName;
  final String? teacherName;
  final String? roomNo;
  final String? timeFrom;
  final String? timeTo;
  final String? classSection;
  final bool isActive;
  final String source;
  final DateTime updatedAt;
  final bool isDeleted;
}

class _TransportRouteRemote {
  const _TransportRouteRemote({
    required this.routeId,
    required this.tenantId,
    required this.routeTitle,
    required this.vehicleNo,
    required this.vehicleModel,
    required this.driverName,
    required this.driverContact,
    required this.pickupPoint,
    required this.destinationPoint,
    required this.pickupTime,
    required this.dropTime,
    required this.monthlyFare,
    required this.isActive,
    required this.source,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String routeId;
  final String tenantId;
  final String routeTitle;
  final String? vehicleNo;
  final String? vehicleModel;
  final String? driverName;
  final String? driverContact;
  final String? pickupPoint;
  final String? destinationPoint;
  final String? pickupTime;
  final String? dropTime;
  final double monthlyFare;
  final bool isActive;
  final String source;
  final DateTime updatedAt;
  final bool isDeleted;
}

class _HomeworkAssignmentRemote {
  const _HomeworkAssignmentRemote({
    required this.assignmentId,
    required this.tenantId,
    required this.assignmentType,
    required this.title,
    required this.subjectName,
    required this.classSection,
    required this.details,
    required this.assignedOn,
    required this.dueDate,
    required this.attachmentUrl,
    required this.isPublished,
    required this.isActive,
    required this.source,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String assignmentId;
  final String tenantId;
  final String assignmentType;
  final String title;
  final String? subjectName;
  final String? classSection;
  final String? details;
  final DateTime? assignedOn;
  final DateTime? dueDate;
  final String? attachmentUrl;
  final bool isPublished;
  final bool isActive;
  final String source;
  final DateTime updatedAt;
  final bool isDeleted;
}

class _OnlineLearningItemRemote {
  const _OnlineLearningItemRemote({
    required this.itemId,
    required this.tenantId,
    required this.itemType,
    required this.title,
    required this.summary,
    required this.instructorName,
    required this.durationLabel,
    required this.accessLevel,
    required this.priceAmount,
    required this.publishedAt,
    required this.isPublished,
    required this.isActive,
    required this.source,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String itemId;
  final String tenantId;
  final String itemType;
  final String title;
  final String? summary;
  final String? instructorName;
  final String? durationLabel;
  final String accessLevel;
  final double priceAmount;
  final DateTime? publishedAt;
  final bool isPublished;
  final bool isActive;
  final String source;
  final DateTime updatedAt;
  final bool isDeleted;
}

class _LessonRemote {
  const _LessonRemote({
    required this.lessonId,
    required this.tenantId,
    required this.title,
    required this.classSection,
    required this.subjectName,
    required this.topicName,
    required this.lessonDateLabel,
    required this.attachmentUrl,
    required this.isActive,
    required this.source,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String lessonId;
  final String tenantId;
  final String title;
  final String? classSection;
  final String? subjectName;
  final String? topicName;
  final String? lessonDateLabel;
  final String? attachmentUrl;
  final bool isActive;
  final String source;
  final DateTime updatedAt;
  final bool isDeleted;
}

class _LessonPlanRemote {
  const _LessonPlanRemote({
    required this.planId,
    required this.tenantId,
    required this.title,
    required this.classSection,
    required this.subjectName,
    required this.objective,
    required this.periodLabel,
    required this.activities,
    required this.isActive,
    required this.source,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String planId;
  final String tenantId;
  final String title;
  final String? classSection;
  final String? subjectName;
  final String? objective;
  final String? periodLabel;
  final String? activities;
  final bool isActive;
  final String source;
  final DateTime updatedAt;
  final bool isDeleted;
}

class _SubjectRemote {
  const _SubjectRemote({
    required this.subjectId,
    required this.tenantId,
    required this.subjectName,
    required this.subjectCode,
    required this.subjectType,
    required this.classSection,
    required this.teacherName,
    required this.isActive,
    required this.source,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String subjectId;
  final String tenantId;
  final String subjectName;
  final String? subjectCode;
  final String subjectType;
  final String? classSection;
  final String? teacherName;
  final bool isActive;
  final String source;
  final DateTime updatedAt;
  final bool isDeleted;
}

class _SyllabusRemote {
  const _SyllabusRemote({
    required this.syllabusId,
    required this.tenantId,
    required this.title,
    required this.classSection,
    required this.subjectName,
    required this.statusLabel,
    required this.completionPercent,
    required this.targetDate,
    required this.notes,
    required this.isActive,
    required this.source,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String syllabusId;
  final String tenantId;
  final String title;
  final String? classSection;
  final String? subjectName;
  final String statusLabel;
  final String? completionPercent;
  final DateTime? targetDate;
  final String? notes;
  final bool isActive;
  final String source;
  final DateTime updatedAt;
  final bool isDeleted;
}

class _LibraryItemRemote {
  const _LibraryItemRemote({
    required this.bookId,
    required this.tenantId,
    required this.bookType,
    required this.title,
    required this.authorName,
    required this.categoryName,
    required this.issuedOn,
    required this.dueDate,
    required this.returnDate,
    required this.ratingScore,
    required this.issueCount,
    required this.isIssued,
    required this.isActive,
    required this.source,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String bookId;
  final String tenantId;
  final String bookType;
  final String title;
  final String? authorName;
  final String? categoryName;
  final DateTime? issuedOn;
  final DateTime? dueDate;
  final DateTime? returnDate;
  final double ratingScore;
  final int issueCount;
  final bool isIssued;
  final bool isActive;
  final String source;
  final DateTime updatedAt;
  final bool isDeleted;
}

class _DocumentCenterRemote {
  const _DocumentCenterRemote({
    required this.itemId,
    required this.tenantId,
    required this.contentType,
    required this.title,
    required this.description,
    required this.fileUrl,
    required this.thumbnailUrl,
    required this.categoryLabel,
    required this.uploadState,
    required this.publishedAt,
    required this.isActive,
    required this.source,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String itemId;
  final String tenantId;
  final String contentType;
  final String title;
  final String? description;
  final String? fileUrl;
  final String? thumbnailUrl;
  final String? categoryLabel;
  final String uploadState;
  final DateTime? publishedAt;
  final bool isActive;
  final String source;
  final DateTime updatedAt;
  final bool isDeleted;
}

class _VisitorCommunicationRemote {
  const _VisitorCommunicationRemote({
    required this.entryId,
    required this.tenantId,
    required this.entryType,
    required this.visitorName,
    required this.purpose,
    required this.phone,
    required this.checkInAt,
    required this.checkOutAt,
    required this.statusLabel,
    required this.note,
    required this.isActive,
    required this.source,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String entryId;
  final String tenantId;
  final String entryType;
  final String? visitorName;
  final String? purpose;
  final String? phone;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final String statusLabel;
  final String? note;
  final bool isActive;
  final String source;
  final DateTime updatedAt;
  final bool isDeleted;
}

class _NotificationRemote {
  const _NotificationRemote({
    required this.notificationId,
    required this.tenantId,
    required this.notificationType,
    required this.title,
    required this.body,
    required this.audience,
    required this.isRead,
    required this.deliveryStatus,
    required this.sentAt,
    required this.readAt,
    required this.payloadJson,
    required this.isActive,
    required this.source,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String notificationId;
  final String tenantId;
  final String notificationType;
  final String title;
  final String? body;
  final String audience;
  final bool isRead;
  final String deliveryStatus;
  final DateTime? sentAt;
  final DateTime? readAt;
  final String? payloadJson;
  final bool isActive;
  final String source;
  final DateTime updatedAt;
  final bool isDeleted;
}

class _LiveClassRemote {
  const _LiveClassRemote({
    required this.classId,
    required this.tenantId,
    required this.providerType,
    required this.title,
    required this.classSection,
    required this.hostName,
    required this.startAt,
    required this.endAt,
    required this.joinUrl,
    required this.meetingId,
    required this.meetingPassword,
    required this.statusLabel,
    required this.isActive,
    required this.source,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String classId;
  final String tenantId;
  final String providerType;
  final String title;
  final String? classSection;
  final String? hostName;
  final DateTime? startAt;
  final DateTime? endAt;
  final String? joinUrl;
  final String? meetingId;
  final String? meetingPassword;
  final String statusLabel;
  final bool isActive;
  final String source;
  final DateTime updatedAt;
  final bool isDeleted;
}

class _StudentAttendanceRemote {
  const _StudentAttendanceRemote({
    required this.recordId,
    required this.tenantId,
    required this.studentId,
    required this.status,
    required this.source,
    required this.attendanceDate,
    required this.updatedAt,
  });

  final String recordId;
  final String tenantId;
  final String studentId;
  final String status;
  final String source;
  final DateTime attendanceDate;
  final DateTime updatedAt;
}

class _LeaveRequestRemote {
  const _LeaveRequestRemote({
    required this.leaveId,
    required this.tenantId,
    required this.requesterId,
    required this.leaveFrom,
    required this.leaveTo,
    required this.appliedAt,
    required this.reason,
    required this.statusLabel,
    required this.approverName,
    required this.approvedAt,
    required this.attachmentUrl,
    required this.isActive,
    required this.source,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String leaveId;
  final String tenantId;
  final String? requesterId;
  final DateTime? leaveFrom;
  final DateTime? leaveTo;
  final DateTime? appliedAt;
  final String? reason;
  final String statusLabel;
  final String? approverName;
  final DateTime? approvedAt;
  final String? attachmentUrl;
  final bool isActive;
  final String source;
  final DateTime updatedAt;
  final bool isDeleted;
}

class _PendingTaskRemote {
  const _PendingTaskRemote({
    required this.taskId,
    required this.tenantId,
    required this.userId,
    required this.title,
    required this.dueDate,
    required this.statusLabel,
    required this.isCompleted,
    required this.priority,
    required this.isActive,
    required this.source,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String taskId;
  final String tenantId;
  final String? userId;
  final String title;
  final DateTime? dueDate;
  final String statusLabel;
  final bool isCompleted;
  final String priority;
  final bool isActive;
  final String source;
  final DateTime updatedAt;
  final bool isDeleted;
}

class _HostelRoomRemote {
  const _HostelRoomRemote({
    required this.roomId,
    required this.tenantId,
    required this.studentId,
    required this.hostelName,
    required this.roomNo,
    required this.roomType,
    required this.floorNo,
    required this.bedNo,
    required this.wardenName,
    required this.wardenContact,
    required this.monthlyFees,
    required this.isActive,
    required this.source,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String roomId;
  final String tenantId;
  final String? studentId;
  final String? hostelName;
  final String? roomNo;
  final String? roomType;
  final String? floorNo;
  final String? bedNo;
  final String? wardenName;
  final String? wardenContact;
  final double monthlyFees;
  final bool isActive;
  final String source;
  final DateTime updatedAt;
  final bool isDeleted;
}

class _StudentProfileRemote {
  const _StudentProfileRemote({
    required this.studentId,
    required this.tenantId,
    required this.admissionNo,
    required this.fullName,
    required this.classSection,
    required this.isActive,
    required this.updatedAt,
  });

  final String studentId;
  final String tenantId;
  final String admissionNo;
  final String fullName;
  final String? classSection;
  final bool isActive;
  final DateTime updatedAt;
}

class _StudentGuardianRemote {
  const _StudentGuardianRemote({
    required this.guardianId,
    required this.tenantId,
    required this.studentId,
    required this.fullName,
    required this.relation,
    required this.phone,
    required this.email,
    required this.isPrimary,
    required this.isActive,
    required this.source,
    required this.updatedAt,
  });

  final String guardianId;
  final String tenantId;
  final String studentId;
  final String fullName;
  final String relation;
  final String? phone;
  final String? email;
  final bool isPrimary;
  final bool isActive;
  final String source;
  final DateTime updatedAt;
}

class _StudentEnrollmentRemote {
  const _StudentEnrollmentRemote({
    required this.enrollmentId,
    required this.tenantId,
    required this.studentId,
    required this.academicSession,
    required this.enrollmentStatus,
    required this.enrolledOn,
    required this.leftOn,
    required this.remarks,
    required this.source,
    required this.updatedAt,
  });

  final String enrollmentId;
  final String tenantId;
  final String studentId;
  final String academicSession;
  final String enrollmentStatus;
  final DateTime? enrolledOn;
  final DateTime? leftOn;
  final String? remarks;
  final String source;
  final DateTime updatedAt;
}

class _StudentClassRollRemote {
  const _StudentClassRollRemote({
    required this.classRollId,
    required this.tenantId,
    required this.studentId,
    required this.academicSession,
    required this.className,
    required this.sectionName,
    required this.rollNo,
    required this.isActive,
    required this.source,
    required this.updatedAt,
  });

  final String classRollId;
  final String tenantId;
  final String studentId;
  final String academicSession;
  final String className;
  final String? sectionName;
  final String? rollNo;
  final bool isActive;
  final String source;
  final DateTime updatedAt;
}

class _FeeInvoiceRemote {
  const _FeeInvoiceRemote({
    required this.recordId,
    required this.tenantId,
    required this.studentId,
    required this.invoiceNo,
    required this.amountDue,
    required this.amountPaid,
    required this.status,
    required this.dueDate,
    required this.source,
    required this.updatedAt,
  });

  final String recordId;
  final String tenantId;
  final String studentId;
  final String invoiceNo;
  final double amountDue;
  final double amountPaid;
  final String status;
  final DateTime? dueDate;
  final String source;
  final DateTime updatedAt;
}

class _FeePaymentRemote {
  const _FeePaymentRemote({
    required this.paymentId,
    required this.tenantId,
    required this.invoiceId,
    required this.studentId,
    required this.amount,
    required this.paidAt,
    required this.paymentMethod,
    required this.referenceNo,
    required this.source,
    required this.updatedAt,
  });

  final String paymentId;
  final String tenantId;
  final String invoiceId;
  final String studentId;
  final double amount;
  final DateTime paidAt;
  final String paymentMethod;
  final String? referenceNo;
  final String source;
  final DateTime updatedAt;
}

class _ExamScheduleRemote {
  const _ExamScheduleRemote({
    required this.scheduleId,
    required this.tenantId,
    required this.examName,
    required this.subjectName,
    required this.maxMarks,
    required this.examDate,
    required this.source,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String scheduleId;
  final String tenantId;
  final String examName;
  final String subjectName;
  final double maxMarks;
  final DateTime examDate;
  final String source;
  final DateTime updatedAt;
  final bool isDeleted;
}

class _ExamMarkRemote {
  const _ExamMarkRemote({
    required this.markId,
    required this.tenantId,
    required this.studentId,
    required this.scheduleId,
    required this.marksObtained,
    required this.grade,
    required this.source,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String markId;
  final String tenantId;
  final String studentId;
  final String scheduleId;
  final double marksObtained;
  final String? grade;
  final String source;
  final DateTime updatedAt;
  final bool isDeleted;
}


class _HomeworkSubmissionRemote {
  const _HomeworkSubmissionRemote({
    required this.submissionId,
    required this.tenantId,
    required this.assignmentId,
    required this.studentId,
    this.submissionText,
    this.attachmentUrl,
    required this.statusLabel,
    this.teacherFeedback,
    this.gradeScore,
    this.submittedAt,
    this.reviewedAt,
    required this.isActive,
    required this.source,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String submissionId;
  final String tenantId;
  final String assignmentId;
  final String studentId;
  final String? submissionText;
  final String? attachmentUrl;
  final String statusLabel;
  final String? teacherFeedback;
  final double? gradeScore;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final bool isActive;
  final String source;
  final DateTime updatedAt;
  final bool isDeleted;
}

class _OnlineLearningAttemptRemote {
  const _OnlineLearningAttemptRemote({
    required this.attemptId,
    required this.tenantId,
    required this.itemId,
    required this.studentId,
    required this.attemptStatus,
    this.scorePercent,
    this.durationSeconds,
    this.startedAt,
    this.completedAt,
    required this.isPassed,
    required this.isActive,
    required this.source,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String attemptId;
  final String tenantId;
  final String itemId;
  final String studentId;
  final String attemptStatus;
  final double? scorePercent;
  final int? durationSeconds;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final bool isPassed;
  final bool isActive;
  final String source;
  final DateTime updatedAt;
  final bool isDeleted;
}

class _FeeGroupRemote {
  const _FeeGroupRemote({
    required this.feeId,
    required this.tenantId,
    required this.studentId,
    required this.feeTitle,
    this.feeCode,
    this.amount = 0,
    this.discount = 0,
    this.fine = 0,
    this.paid = 0,
    this.balance = 0,
    required this.status,
    this.dueDate,
    required this.isPayable,
    required this.feeType,
    required this.source,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String feeId;
  final String tenantId;
  final String studentId;
  final String feeTitle;
  final String? feeCode;
  final double amount;
  final double discount;
  final double fine;
  final double paid;
  final double balance;
  final String status;
  final String? dueDate;
  final bool isPayable;
  final String feeType;
  final String source;
  final DateTime updatedAt;
  final bool isDeleted;
}

class _CbseExamResultRemote {
  const _CbseExamResultRemote({
    required this.resultId,
    required this.tenantId,
    required this.studentId,
    required this.examName,
    required this.subjectName,
    this.subjectCode,
    this.assessmentName,
    this.marksObtained,
    this.maxMarks,
    this.examDate,
    this.grade,
    this.rank,
    this.percentage,
    this.totalObtained,
    this.totalMax,
    required this.resultType,
    this.roomNo,
    this.timeFrom,
    this.duration,
    required this.source,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String resultId;
  final String tenantId;
  final String studentId;
  final String examName;
  final String subjectName;
  final String? subjectCode;
  final String? assessmentName;
  final double? marksObtained;
  final double? maxMarks;
  final String? examDate;
  final String? grade;
  final String? rank;
  final String? percentage;
  final String? totalObtained;
  final String? totalMax;
  final String resultType;
  final String? roomNo;
  final String? timeFrom;
  final String? duration;
  final String source;
  final DateTime updatedAt;
  final bool isDeleted;
}

class _OnlineExamRemote {
  const _OnlineExamRemote({
    required this.examId,
    required this.tenantId,
    required this.examTitle,
    this.description,
    this.examFrom,
    this.examTo,
    this.totalQuestions = 0,
    this.totalAttempt = 1,
    this.durationMinutes = 0,
    this.passingPercent = 35,
    this.isQuiz = false,
    required this.statusLabel,
    this.attemptCount = 0,
    this.isSubmitted = false,
    this.lastScorePercent,
    this.isPassed = false,
    required this.isActive,
    required this.source,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String examId;
  final String tenantId;
  final String examTitle;
  final String? description;
  final String? examFrom;
  final String? examTo;
  final int totalQuestions;
  final int totalAttempt;
  final int durationMinutes;
  final double passingPercent;
  final bool isQuiz;
  final String statusLabel;
  final int attemptCount;
  final bool isSubmitted;
  final double? lastScorePercent;
  final bool isPassed;
  final bool isActive;
  final String source;
  final DateTime updatedAt;
  final bool isDeleted;
}

class _StudentBehaviourRemote {
  const _StudentBehaviourRemote({
    required this.incidentId,
    required this.tenantId,
    required this.studentId,
    required this.title,
    this.description,
    this.point = '0',
    this.isPositive = true,
    this.assignedBy,
    this.incidentDate,
    this.commentCount = 0,
    required this.source,
    required this.updatedAt,
    required this.isDeleted,
  });
  final String incidentId;
  final String tenantId;
  final String studentId;
  final String title;
  final String? description;
  final String point;
  final bool isPositive;
  final String? assignedBy;
  final String? incidentDate;
  final int commentCount;
  final String source;
  final DateTime updatedAt;
  final bool isDeleted;
}

class _BehaviourCommentRemote {
  const _BehaviourCommentRemote({
    required this.commentId,
    required this.tenantId,
    required this.incidentId,
    required this.commentText,
    this.commentedBy,
    this.commentDate,
    required this.source,
    required this.updatedAt,
    required this.isDeleted,
  });
  final String commentId;
  final String tenantId;
  final String incidentId;
  final String commentText;
  final String? commentedBy;
  final String? commentDate;
  final String source;
  final DateTime updatedAt;
  final bool isDeleted;
}

class _TeacherRemote {
  const _TeacherRemote({
    required this.teacherId,
    required this.tenantId,
    required this.fullName,
    this.employeeNo,
    this.subjectName,
    this.qualification,
    this.email,
    this.phone,
    this.designation,
    this.isClassTeacher = false,
    this.imageUrl,
    this.ratingScore = 0,
    this.reviewComment,
    this.hasReviewed = false,
    required this.isActive,
    required this.source,
    required this.updatedAt,
    required this.isDeleted,
  });
  final String teacherId;
  final String tenantId;
  final String fullName;
  final String? employeeNo;
  final String? subjectName;
  final String? qualification;
  final String? email;
  final String? phone;
  final String? designation;
  final bool isClassTeacher;
  final String? imageUrl;
  final int ratingScore;
  final String? reviewComment;
  final bool hasReviewed;
  final bool isActive;
  final String source;
  final DateTime updatedAt;
  final bool isDeleted;
}

class _OnlineLessonRemote {
  const _OnlineLessonRemote({
    required this.lessonId,
    required this.tenantId,
    required this.itemId,
    required this.title,
    this.contentType = 'video',
    this.contentUrl,
    this.description,
    this.sortOrder = 0,
    this.durationSeconds = 0,
    this.isCompleted = false,
    this.isActive = true,
    required this.source,
    required this.updatedAt,
    required this.isDeleted,
  });
  final String lessonId;
  final String tenantId;
  final String itemId;
  final String title;
  final String contentType;
  final String? contentUrl;
  final String? description;
  final int sortOrder;
  final int durationSeconds;
  final bool isCompleted;
  final bool isActive;
  final String source;
  final DateTime updatedAt;
  final bool isDeleted;
}
