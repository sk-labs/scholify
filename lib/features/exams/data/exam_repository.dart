import 'dart:convert';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

class ExamAnalyticsSnapshot {
  const ExamAnalyticsSnapshot({
    required this.totalAttempts,
    required this.uniqueStudents,
    required this.averagePercent,
    required this.passRate,
    required this.gradeDistribution,
    required this.subjectPerformance,
    required this.topperList,
    required this.trendPoints,
    required this.availableSubjects,
    required this.availableClassSections,
  });

  final int totalAttempts;
  final int uniqueStudents;
  final double averagePercent;
  final double passRate;
  final Map<String, int> gradeDistribution;
  final List<ExamSubjectPerformance> subjectPerformance;
  final List<ExamTopperMetric> topperList;
  final List<ExamTrendPoint> trendPoints;
  final List<String> availableSubjects;
  final List<String> availableClassSections;

  bool get hasData => totalAttempts > 0;
}

class ExamSubjectPerformance {
  const ExamSubjectPerformance({
    required this.subjectName,
    required this.attempts,
    required this.averagePercent,
    required this.passRate,
  });

  final String subjectName;
  final int attempts;
  final double averagePercent;
  final double passRate;
}

class ExamTopperMetric {
  const ExamTopperMetric({
    required this.studentId,
    required this.studentName,
    required this.admissionNo,
    required this.classSection,
    required this.attempts,
    required this.totalObtained,
    required this.totalMax,
    required this.averagePercent,
  });

  final String studentId;
  final String studentName;
  final String? admissionNo;
  final String? classSection;
  final int attempts;
  final double totalObtained;
  final double totalMax;
  final double averagePercent;
}

class ExamTrendPoint {
  const ExamTrendPoint({
    required this.date,
    required this.attempts,
    required this.averagePercent,
  });

  final DateTime date;
  final int attempts;
  final double averagePercent;
}

class ExamRepository {
  ExamRepository({
    required this.database,
    required this.syncEngine,
    required this.tenantContext,
  });

  final AppLocalDatabase database;
  final SyncEngine syncEngine;
  final TenantContext tenantContext;

  Stream<List<StudentDirectoryEntry>> watchStudents() {
    return database.watchActiveStudentProfiles(tenantId: _resolveTenantId());
  }

  Stream<List<ExamScheduleEntry>> watchExamSchedules({
    required DateTime month,
  }) {
    final range = _monthRange(month);
    return database.watchExamSchedulesInMonth(
      tenantId: _resolveTenantId(),
      from: range.$1,
      to: range.$2,
    );
  }

  Stream<List<StudentExamMarkView>> watchStudentMonthMarks({
    required String studentId,
    required DateTime month,
  }) {
    final range = _monthRange(month);
    return database.watchStudentExamMarkViews(
      tenantId: _resolveTenantId(),
      studentId: studentId,
      from: range.$1,
      to: range.$2,
    );
  }

  Stream<ExamAnalyticsSnapshot> watchExamAnalytics({
    required DateTime month,
    String? subjectName,
    String? classSection,
  }) {
    final range = _monthRange(month);
    return database
        .watchExamAnalyticsMarkRowsInMonth(
          tenantId: _resolveTenantId(),
          from: range.$1,
          to: range.$2,
        )
        .map(
          (rows) => _buildAnalyticsSnapshot(
            rows,
            subjectName: subjectName,
            classSection: classSection,
          ),
        );
  }

  Future<void> createExamSchedule({
    required String examName,
    required String subjectName,
    required double maxMarks,
    required DateTime examDate,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();
    final scheduleId = 'ex_${tenantId}_${now.millisecondsSinceEpoch}';

    await database.upsertExamScheduleRecord(
      scheduleId: scheduleId,
      tenantId: tenantId,
      examName: examName,
      subjectName: subjectName,
      maxMarks: maxMarks,
      examDate: examDate,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'exam_schedule',
      entityId: scheduleId,
      operation: 'upsert',
      payload: jsonEncode({
        'scheduleId': scheduleId,
        'tenantId': tenantId,
        'examName': examName,
        'subjectName': subjectName,
        'maxMarks': maxMarks,
        'examDate': examDate.toUtc().toIso8601String(),
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> updateExamSchedule({
    required ExamScheduleEntry schedule,
    required String examName,
    required String subjectName,
    required double maxMarks,
    required DateTime examDate,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();

    await database.upsertExamScheduleRecord(
      scheduleId: schedule.id,
      tenantId: tenantId,
      examName: examName,
      subjectName: subjectName,
      maxMarks: maxMarks,
      examDate: examDate,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'exam_schedule',
      entityId: schedule.id,
      operation: 'upsert',
      payload: jsonEncode({
        'scheduleId': schedule.id,
        'tenantId': tenantId,
        'examName': examName,
        'subjectName': subjectName,
        'maxMarks': maxMarks,
        'examDate': examDate.toUtc().toIso8601String(),
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> deleteExamSchedule({required ExamScheduleEntry schedule}) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();
    final markIds = await database.getExamMarkIdsBySchedule(
      tenantId: tenantId,
      scheduleId: schedule.id,
    );

    await database.deleteExamScheduleCascade(
      tenantId: tenantId,
      scheduleId: schedule.id,
    );

    await syncEngine.enqueueOperation(
      entityType: 'exam_schedule',
      entityId: schedule.id,
      operation: 'delete',
      payload: jsonEncode({
        'scheduleId': schedule.id,
        'tenantId': tenantId,
        'updatedAt': now.toIso8601String(),
      }),
    );

    for (final markId in markIds) {
      await syncEngine.enqueueOperation(
        entityType: 'exam_mark',
        entityId: markId,
        operation: 'delete',
        payload: jsonEncode({
          'markId': markId,
          'tenantId': tenantId,
          'scheduleId': schedule.id,
          'updatedAt': now.toIso8601String(),
        }),
      );
    }
  }

  Future<void> setStudentMark({
    required String studentId,
    required ExamScheduleEntry schedule,
    required double marksObtained,
    String? grade,
  }) async {
    await upsertStudentMark(
      studentId: studentId,
      scheduleId: schedule.id,
      scheduleMaxMarks: schedule.maxMarks,
      marksObtained: marksObtained,
      grade: grade,
    );
  }

  Future<void> upsertStudentMark({
    required String studentId,
    required String scheduleId,
    required double scheduleMaxMarks,
    required double marksObtained,
    String? grade,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();
    final markId = 'mark_${scheduleId}_$studentId';
    final resolvedGrade =
        grade ??
        _gradeFromPercent(
          marksObtained: marksObtained,
          maxMarks: scheduleMaxMarks,
        );

    await database.upsertStudentExamMarkRecord(
      markId: markId,
      tenantId: tenantId,
      studentId: studentId,
      scheduleId: scheduleId,
      marksObtained: marksObtained,
      grade: resolvedGrade,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'exam_mark',
      entityId: markId,
      operation: 'upsert',
      payload: jsonEncode({
        'markId': markId,
        'tenantId': tenantId,
        'studentId': studentId,
        'scheduleId': scheduleId,
        'marksObtained': marksObtained,
        'grade': resolvedGrade,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> deleteStudentMark({
    required String markId,
    required String scheduleId,
    required String studentId,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();

    await database.deleteStudentExamMarkRecord(
      tenantId: tenantId,
      markId: markId,
    );

    await syncEngine.enqueueOperation(
      entityType: 'exam_mark',
      entityId: markId,
      operation: 'delete',
      payload: jsonEncode({
        'markId': markId,
        'tenantId': tenantId,
        'scheduleId': scheduleId,
        'studentId': studentId,
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  (DateTime, DateTime) _monthRange(DateTime month) {
    final normalized = DateTime(month.year, month.month, 1);
    final start = DateTime(normalized.year, normalized.month, 1);
    final end = DateTime(
      normalized.year,
      normalized.month + 1,
      0,
      23,
      59,
      59,
      999,
    );
    return (start, end);
  }

  String _gradeFromPercent({
    required double marksObtained,
    required double maxMarks,
  }) {
    if (maxMarks <= 0) return 'N/A';
    final percent = (marksObtained / maxMarks) * 100;
    if (percent >= 90) return 'A+';
    if (percent >= 80) return 'A';
    if (percent >= 70) return 'B+';
    if (percent >= 60) return 'B';
    if (percent >= 50) return 'C';
    if (percent >= 35) return 'D';
    return 'F';
  }

  ExamAnalyticsSnapshot _buildAnalyticsSnapshot(
    List<ExamAnalyticsMarkRow> rows, {
    String? subjectName,
    String? classSection,
  }) {
    final availableSubjects =
        rows
            .map((row) => row.subjectName.trim())
            .where((subject) => subject.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    final availableClassSections =
        rows
            .map((row) => row.classSection?.trim() ?? '')
            .where((className) => className.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    final filteredRows = rows.where((row) {
      final subjectMatches =
          subjectName == null ||
          subjectName.isEmpty ||
          row.subjectName == subjectName;
      final classMatches =
          classSection == null ||
          classSection.isEmpty ||
          (row.classSection?.trim() ?? '') == classSection;
      return subjectMatches && classMatches;
    }).toList();

    if (filteredRows.isEmpty) {
      return ExamAnalyticsSnapshot(
        totalAttempts: 0,
        uniqueStudents: 0,
        averagePercent: 0,
        passRate: 0,
        gradeDistribution: const <String, int>{},
        subjectPerformance: const <ExamSubjectPerformance>[],
        topperList: const <ExamTopperMetric>[],
        trendPoints: const <ExamTrendPoint>[],
        availableSubjects: availableSubjects,
        availableClassSections: availableClassSections,
      );
    }

    final gradeDistribution = <String, int>{};
    final subjectBuckets = <String, _StatsBucket>{};
    final topperBuckets = <String, _TopperBucket>{};
    final trendBuckets = <DateTime, _StatsBucket>{};

    double totalObtained = 0;
    double totalMax = 0;
    int passCount = 0;

    for (final row in filteredRows) {
      totalObtained += row.marksObtained;
      totalMax += row.maxMarks;

      final percent = row.maxMarks <= 0
          ? 0
          : (row.marksObtained / row.maxMarks) * 100;
      if (percent >= 35) {
        passCount++;
      }

      final resolvedGrade = (row.grade == null || row.grade!.trim().isEmpty)
          ? _gradeFromPercent(
              marksObtained: row.marksObtained,
              maxMarks: row.maxMarks,
            )
          : row.grade!.trim();
      gradeDistribution[resolvedGrade] =
          (gradeDistribution[resolvedGrade] ?? 0) + 1;

      final subjectBucket = subjectBuckets.putIfAbsent(
        row.subjectName,
        () => _StatsBucket(),
      );
      subjectBucket.add(row.marksObtained, row.maxMarks);

      final topperBucket = topperBuckets.putIfAbsent(
        row.studentId,
        () => _TopperBucket(
          studentId: row.studentId,
          studentName: row.studentName?.trim().isNotEmpty == true
              ? row.studentName!.trim()
              : row.studentId,
          admissionNo: row.admissionNo,
          classSection: row.classSection,
        ),
      );
      topperBucket.add(row.marksObtained, row.maxMarks);

      final trendDate = DateTime(
        row.examDate.year,
        row.examDate.month,
        row.examDate.day,
      );
      final trendBucket = trendBuckets.putIfAbsent(
        trendDate,
        () => _StatsBucket(),
      );
      trendBucket.add(row.marksObtained, row.maxMarks);
    }

    final attempts = filteredRows.length;
    final averagePercent = totalMax <= 0
        ? 0.0
        : (totalObtained / totalMax) * 100;
    final passRate = attempts == 0 ? 0.0 : (passCount / attempts) * 100;

    final subjectPerformance =
        subjectBuckets.entries
            .map(
              (entry) => ExamSubjectPerformance(
                subjectName: entry.key,
                attempts: entry.value.attempts,
                averagePercent: entry.value.averagePercent,
                passRate: entry.value.passRate,
              ),
            )
            .toList()
          ..sort((a, b) => b.averagePercent.compareTo(a.averagePercent));

    final topperList =
        topperBuckets.values
            .map(
              (bucket) => ExamTopperMetric(
                studentId: bucket.studentId,
                studentName: bucket.studentName,
                admissionNo: bucket.admissionNo,
                classSection: bucket.classSection,
                attempts: bucket.attempts,
                totalObtained: bucket.totalObtained,
                totalMax: bucket.totalMax,
                averagePercent: bucket.averagePercent,
              ),
            )
            .toList()
          ..sort((a, b) {
            final percentOrder = b.averagePercent.compareTo(a.averagePercent);
            if (percentOrder != 0) return percentOrder;
            return b.totalObtained.compareTo(a.totalObtained);
          });

    final trendPoints =
        trendBuckets.entries
            .map(
              (entry) => ExamTrendPoint(
                date: entry.key,
                attempts: entry.value.attempts,
                averagePercent: entry.value.averagePercent,
              ),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    return ExamAnalyticsSnapshot(
      totalAttempts: attempts,
      uniqueStudents: filteredRows.map((row) => row.studentId).toSet().length,
      averagePercent: averagePercent,
      passRate: passRate,
      gradeDistribution: gradeDistribution,
      subjectPerformance: subjectPerformance,
      topperList: topperList,
      trendPoints: trendPoints,
      availableSubjects: availableSubjects,
      availableClassSections: availableClassSections,
    );
  }

  String _resolveTenantId() {
    if (tenantContext.tenantId != null && tenantContext.tenantId!.isNotEmpty) {
      return tenantContext.tenantId!;
    }
    return 'school_demo';
  }
}

class _StatsBucket {
  int attempts = 0;
  int passCount = 0;
  double totalObtained = 0;
  double totalMax = 0;

  void add(double obtained, double max) {
    attempts++;
    totalObtained += obtained;
    totalMax += max;

    final percent = max <= 0 ? 0.0 : (obtained / max) * 100;
    if (percent >= 35) {
      passCount++;
    }
  }

  double get averagePercent =>
      totalMax <= 0 ? 0.0 : (totalObtained / totalMax) * 100;
  double get passRate => attempts == 0 ? 0.0 : (passCount / attempts) * 100;
}

class _TopperBucket {
  _TopperBucket({
    required this.studentId,
    required this.studentName,
    required this.admissionNo,
    required this.classSection,
  });

  final String studentId;
  final String studentName;
  final String? admissionNo;
  final String? classSection;

  int attempts = 0;
  double totalObtained = 0;
  double totalMax = 0;

  void add(double obtained, double max) {
    attempts++;
    totalObtained += obtained;
    totalMax += max;
  }

  double get averagePercent =>
      totalMax <= 0 ? 0.0 : (totalObtained / totalMax) * 100;
}
