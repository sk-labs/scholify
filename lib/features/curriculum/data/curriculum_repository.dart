import 'dart:convert';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

class CurriculumRepository {
  CurriculumRepository({
    required this.database,
    required this.syncEngine,
    required this.tenantContext,
  });

  final AppLocalDatabase database;
  final SyncEngine syncEngine;
  final TenantContext tenantContext;

  static const List<LessonPlanTemplate> lessonPlanTemplates = [
    LessonPlanTemplate(
      templateId: 'template_flipped',
      title: 'Flipped Classroom',
      objective: 'Students review pre-read material before class.',
      periodLabel: '40 mins',
      activities:
          '5m recap, 20m guided discussion, 10m worksheet, 5m reflection.',
    ),
    LessonPlanTemplate(
      templateId: 'template_lab',
      title: 'Inquiry Lab Session',
      objective: 'Students validate core concepts through experiment.',
      periodLabel: '60 mins',
      activities: '10m hypothesis, 30m lab work, 10m data review, 10m summary.',
    ),
    LessonPlanTemplate(
      templateId: 'template_revision',
      title: 'Revision and Assessment',
      objective: 'Reinforce key outcomes and assess understanding.',
      periodLabel: '45 mins',
      activities: '15m quick recap, 20m timed quiz, 10m answer walkthrough.',
    ),
  ];

  Stream<List<LessonEntry>> watchLessons({bool includeInactive = false}) {
    return database.watchLessons(
      tenantId: _resolveTenantId(),
      includeInactive: includeInactive,
    );
  }

  Stream<List<LessonPlanEntry>> watchLessonPlans({
    bool includeInactive = false,
  }) {
    return database.watchLessonPlans(
      tenantId: _resolveTenantId(),
      includeInactive: includeInactive,
    );
  }

  Stream<List<SubjectEntry>> watchSubjects({bool includeInactive = false}) {
    return database.watchSubjects(
      tenantId: _resolveTenantId(),
      includeInactive: includeInactive,
    );
  }

  Stream<List<SyllabusEntry>> watchSyllabusItems({
    bool includeInactive = false,
  }) {
    return database.watchSyllabusItems(
      tenantId: _resolveTenantId(),
      includeInactive: includeInactive,
    );
  }

  Stream<SyllabusProgressAnalytics> watchSyllabusProgressAnalytics() {
    return watchSyllabusItems(includeInactive: false).map((items) {
      if (items.isEmpty) {
        return const SyllabusProgressAnalytics(
          totalItems: 0,
          completedItems: 0,
          inProgressItems: 0,
          averageCompletionPercent: 0,
        );
      }

      int completed = 0;
      int inProgress = 0;
      double completionSum = 0;

      for (final item in items) {
        final status = item.statusLabel.trim().toLowerCase();
        if (status == 'completed' || status == 'done') {
          completed++;
        } else if (status == 'in_progress' || status == 'in progress') {
          inProgress++;
        }

        completionSum += _parseCompletionPercent(item.completionPercent);
      }

      return SyllabusProgressAnalytics(
        totalItems: items.length,
        completedItems: completed,
        inProgressItems: inProgress,
        averageCompletionPercent: completionSum / items.length,
      );
    });
  }

  Future<void> attachLessonResource({
    required LessonEntry lesson,
    required String attachmentUrl,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();
    final normalized = attachmentUrl.trim();
    final mergedAttachment = _mergeAttachments(
      lesson.attachmentUrl,
      normalized,
    );

    await database.upsertLessonRecord(
      lessonId: lesson.id,
      tenantId: tenantId,
      title: lesson.title,
      classSection: lesson.classSection,
      subjectName: lesson.subjectName,
      topicName: lesson.topicName,
      lessonDateLabel: lesson.lessonDateLabel,
      attachmentUrl: mergedAttachment,
      isActive: lesson.isActive,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'lesson',
      entityId: lesson.id,
      operation: 'upsert',
      payload: jsonEncode({
        'lessonId': lesson.id,
        'tenantId': tenantId,
        'title': lesson.title,
        'classSection': lesson.classSection,
        'subjectName': lesson.subjectName,
        'topicName': lesson.topicName,
        'lessonDateLabel': lesson.lessonDateLabel,
        'attachmentUrl': mergedAttachment,
        'isActive': lesson.isActive,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> saveLesson({
    String? lessonId,
    required String title,
    String? classSection,
    String? subjectName,
    String? topicName,
    String? lessonDateLabel,
    String? attachmentUrl,
    bool isActive = true,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();
    final resolvedId =
        lessonId ?? 'lesson_${tenantId}_${now.millisecondsSinceEpoch}';

    await database.upsertLessonRecord(
      lessonId: resolvedId,
      tenantId: tenantId,
      title: title,
      classSection: classSection,
      subjectName: subjectName,
      topicName: topicName,
      lessonDateLabel: lessonDateLabel,
      attachmentUrl: attachmentUrl,
      isActive: isActive,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'lesson',
      entityId: resolvedId,
      operation: 'upsert',
      payload: jsonEncode({
        'lessonId': resolvedId,
        'tenantId': tenantId,
        'title': title,
        'classSection': classSection,
        'subjectName': subjectName,
        'topicName': topicName,
        'lessonDateLabel': lessonDateLabel,
        'attachmentUrl': attachmentUrl,
        'isActive': isActive,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> deleteLesson(LessonEntry lesson) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();

    await database.deleteLessonRecord(tenantId: tenantId, lessonId: lesson.id);

    await syncEngine.enqueueOperation(
      entityType: 'lesson',
      entityId: lesson.id,
      operation: 'delete',
      payload: jsonEncode({
        'lessonId': lesson.id,
        'tenantId': tenantId,
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> saveLessonPlan({
    String? planId,
    required String title,
    String? classSection,
    String? subjectName,
    String? objective,
    String? periodLabel,
    String? activities,
    bool isActive = true,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();
    final resolvedId = planId ?? 'lp_${tenantId}_${now.millisecondsSinceEpoch}';

    await database.upsertLessonPlanRecord(
      planId: resolvedId,
      tenantId: tenantId,
      title: title,
      classSection: classSection,
      subjectName: subjectName,
      objective: objective,
      periodLabel: periodLabel,
      activities: activities,
      isActive: isActive,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'lesson_plan',
      entityId: resolvedId,
      operation: 'upsert',
      payload: jsonEncode({
        'planId': resolvedId,
        'tenantId': tenantId,
        'title': title,
        'classSection': classSection,
        'subjectName': subjectName,
        'objective': objective,
        'periodLabel': periodLabel,
        'activities': activities,
        'isActive': isActive,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> deleteLessonPlan(LessonPlanEntry plan) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();

    await database.deleteLessonPlanRecord(tenantId: tenantId, planId: plan.id);

    await syncEngine.enqueueOperation(
      entityType: 'lesson_plan',
      entityId: plan.id,
      operation: 'delete',
      payload: jsonEncode({
        'planId': plan.id,
        'tenantId': tenantId,
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> saveSubject({
    String? subjectId,
    required String subjectName,
    String? subjectCode,
    String subjectType = 'theory',
    String? classSection,
    String? teacherName,
    bool isActive = true,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();
    final resolvedId =
        subjectId ?? 'sub_${tenantId}_${now.millisecondsSinceEpoch}';

    await database.upsertSubjectRecord(
      subjectId: resolvedId,
      tenantId: tenantId,
      subjectName: subjectName,
      subjectCode: subjectCode,
      subjectType: subjectType,
      classSection: classSection,
      teacherName: teacherName,
      isActive: isActive,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'subject',
      entityId: resolvedId,
      operation: 'upsert',
      payload: jsonEncode({
        'subjectId': resolvedId,
        'tenantId': tenantId,
        'subjectName': subjectName,
        'subjectCode': subjectCode,
        'subjectType': subjectType,
        'classSection': classSection,
        'teacherName': teacherName,
        'isActive': isActive,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> deleteSubject(SubjectEntry subject) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();

    await database.deleteSubjectRecord(
      tenantId: tenantId,
      subjectId: subject.id,
    );

    await syncEngine.enqueueOperation(
      entityType: 'subject',
      entityId: subject.id,
      operation: 'delete',
      payload: jsonEncode({
        'subjectId': subject.id,
        'tenantId': tenantId,
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> saveSyllabus({
    String? syllabusId,
    required String title,
    String? classSection,
    String? subjectName,
    String statusLabel = 'pending',
    String? completionPercent,
    DateTime? targetDate,
    String? notes,
    bool isActive = true,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();
    final resolvedId =
        syllabusId ?? 'syl_${tenantId}_${now.millisecondsSinceEpoch}';

    await database.upsertSyllabusRecord(
      syllabusId: resolvedId,
      tenantId: tenantId,
      title: title,
      classSection: classSection,
      subjectName: subjectName,
      statusLabel: statusLabel,
      completionPercent: completionPercent,
      targetDate: targetDate?.toUtc(),
      notes: notes,
      isActive: isActive,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'syllabus',
      entityId: resolvedId,
      operation: 'upsert',
      payload: jsonEncode({
        'syllabusId': resolvedId,
        'tenantId': tenantId,
        'title': title,
        'classSection': classSection,
        'subjectName': subjectName,
        'statusLabel': statusLabel,
        'completionPercent': completionPercent,
        'targetDate': targetDate?.toUtc().toIso8601String(),
        'notes': notes,
        'isActive': isActive,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> deleteSyllabus(SyllabusEntry syllabus) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();

    await database.deleteSyllabusRecord(
      tenantId: tenantId,
      syllabusId: syllabus.id,
    );

    await syncEngine.enqueueOperation(
      entityType: 'syllabus',
      entityId: syllabus.id,
      operation: 'delete',
      payload: jsonEncode({
        'syllabusId': syllabus.id,
        'tenantId': tenantId,
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  String _resolveTenantId() {
    if (tenantContext.tenantId != null && tenantContext.tenantId!.isNotEmpty) {
      return tenantContext.tenantId!;
    }
    return 'school_demo';
  }

  double _parseCompletionPercent(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 0;
    final normalized = raw.replaceAll('%', '').trim();
    return double.tryParse(normalized) ?? 0;
  }

  String _mergeAttachments(String? existing, String candidate) {
    final values = <String>{};
    for (final item in (existing ?? '').split(',')) {
      final trimmed = item.trim();
      if (trimmed.isNotEmpty) values.add(trimmed);
    }
    if (candidate.isNotEmpty) {
      values.add(candidate);
    }
    return values.join(', ');
  }
}

class SyllabusProgressAnalytics {
  const SyllabusProgressAnalytics({
    required this.totalItems,
    required this.completedItems,
    required this.inProgressItems,
    required this.averageCompletionPercent,
  });

  final int totalItems;
  final int completedItems;
  final int inProgressItems;
  final double averageCompletionPercent;
}

class LessonPlanTemplate {
  const LessonPlanTemplate({
    required this.templateId,
    required this.title,
    required this.objective,
    required this.periodLabel,
    required this.activities,
  });

  final String templateId;
  final String title;
  final String objective;
  final String periodLabel;
  final String activities;
}
