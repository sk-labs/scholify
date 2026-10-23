import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../../../core/theme/scholify_colors.dart';
import '../../../core/widgets/scholify_empty_state.dart';
import '../../family/family_links.dart';
import '../data/exam_repository.dart';

/// Family-facing exam view: a guardian sees each linked child's exam
/// results (with the shared child switcher); a student sees their own.
/// Read-only — schedules and marks are managed by staff. Scored subjects
/// show marks and grades; scheduled subjects without marks yet show as
/// upcoming or awaited.
class FamilyExamsPage extends StatefulWidget {
  const FamilyExamsPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<FamilyExamsPage> createState() => _FamilyExamsPageState();
}

class _FamilyExamsPageState extends State<FamilyExamsPage> {
  late final ExamRepository _repository;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _repository = ExamRepository(
      database: widget.syncEngine.database,
      syncEngine: widget.syncEngine,
      tenantContext: widget.tenantContext,
    );
  }

  FamilyIdentity get _identity =>
      FamilyIdentity.fromGateway(widget.syncEngine.pocketbaseGateway);

  @override
  Widget build(BuildContext context) {
    final role = widget.tenantContext.role.toLowerCase();
    if (role == 'guardian') {
      return _buildGuardianBody(context);
    }
    return _buildStudentBody(context);
  }

  Widget _buildGuardianBody(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: StreamBuilder<List<StudentDirectoryEntry>>(
        stream: watchLinkedChildren(
          widget.syncEngine.database,
          identity: _identity,
          tenantId: widget.tenantContext.tenantId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final children = snapshot.data ?? const [];
          if (children.isEmpty) {
            return Center(
              child: ScholifyEmptyState(
                icon: Icons.family_restroom_outlined,
                title: 'No children linked',
                message:
                    'Contact the school office to link your children to this account.',
              ),
            );
          }
          return ValueListenableBuilder<String?>(
            valueListenable: FamilyChildSelection.selectedStudentId,
            builder: (context, _, _) {
              final child = effectiveChild(children)!;
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildHeader(
                    theme,
                    'Exam Results',
                    'Results and upcoming exams for ${child.fullName}',
                  ),
                  if (children.length > 1) ...[
                    const SizedBox(height: 16),
                    FamilyChildSwitcher(children: children),
                  ],
                  const SizedBox(height: 8),
                  _buildMonthSelector(theme),
                  const SizedBox(height: 12),
                  _MonthResults(
                    key: ValueKey('${child.id}_${_selectedMonth.month}'),
                    repository: _repository,
                    studentId: child.id,
                    month: _selectedMonth,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStudentBody(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: StreamBuilder<StudentDirectoryEntry?>(
        stream: watchOwnStudentRecord(
          widget.syncEngine.database,
          identity: _identity,
          tenantId: widget.tenantContext.tenantId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final student = snapshot.data;
          if (student == null) {
            return Center(
              child: ScholifyEmptyState(
                icon: Icons.person_search_outlined,
                title: 'No student record linked',
                message:
                    'Contact the school office to link this account to your student record.',
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildHeader(
                theme,
                'Exam Results',
                'Your exam results and upcoming exams',
              ),
              const SizedBox(height: 8),
              _buildMonthSelector(theme),
              const SizedBox(height: 12),
              _MonthResults(
                key: ValueKey('${student.id}_${_selectedMonth.month}'),
                repository: _repository,
                studentId: student.id,
                month: _selectedMonth,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthSelector(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => setState(() {
            _selectedMonth = DateTime(
              _selectedMonth.year,
              _selectedMonth.month - 1,
            );
          }),
        ),
        Text(
          DateFormat('MMMM yyyy').format(_selectedMonth),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          // Exams are scheduled ahead, so future months stay reachable
          // (unlike attendance, which only exists for past months).
          onPressed: () => setState(() {
            _selectedMonth = DateTime(
              _selectedMonth.year,
              _selectedMonth.month + 1,
            );
          }),
        ),
      ],
    );
  }
}

/// One student's exam groups for one month: scored subjects with marks
/// and grades, plus scheduled subjects that have no mark yet.
class _MonthResults extends StatelessWidget {
  const _MonthResults({
    super.key,
    required this.repository,
    required this.studentId,
    required this.month,
  });

  final ExamRepository repository;
  final String studentId;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StudentExamMarkView>>(
      stream: repository.watchStudentMonthMarks(
        studentId: studentId,
        month: month,
      ),
      builder: (context, marksSnapshot) {
        return StreamBuilder<List<ExamScheduleEntry>>(
          stream: repository.watchExamSchedules(month: month),
          builder: (context, schedulesSnapshot) {
            if (marksSnapshot.connectionState == ConnectionState.waiting ||
                schedulesSnapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final groups = buildExamGroups(
              marks: marksSnapshot.data ?? const [],
              schedules: schedulesSnapshot.data ?? const [],
            );
            if (groups.isEmpty) {
              return ScholifyEmptyState(
                icon: Icons.workspace_premium_outlined,
                title: 'No exams this month',
                message:
                    'Exam schedules and results for ${DateFormat('MMMM yyyy').format(month)} will appear here.',
              );
            }
            final scored = [
              for (final g in groups)
                for (final r in g.rows)
                  if (r.mark != null) r,
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (scored.isNotEmpty) ...[
                  _MonthSummary(rows: scored),
                  const SizedBox(height: 16),
                ],
                for (final group in groups) ...[
                  _ExamGroupCard(group: group),
                  const SizedBox(height: 14),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _MonthSummary extends StatelessWidget {
  const _MonthSummary({required this.rows});

  /// Scored rows only.
  final List<ExamSubjectRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var obtained = 0.0;
    var maxTotal = 0.0;
    ExamSubjectRow? best;
    var bestPct = -1.0;
    for (final row in rows) {
      final mark = row.mark!;
      obtained += mark.marksObtained;
      maxTotal += mark.maxMarks;
      final pct = percentOf(mark.marksObtained, mark.maxMarks);
      if (pct > bestPct) {
        bestPct = pct;
        best = row;
      }
    }
    final overall = percentOf(obtained, maxTotal);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: _SummaryStat(
                icon: Icons.emoji_events_outlined,
                label: 'Overall',
                value: '${overall.toStringAsFixed(1)}%',
                color: ScholifyColors.onTint(
                  ScholifyColors.academicNavy,
                  theme.brightness,
                ),
              ),
            ),
            Expanded(
              child: _SummaryStat(
                icon: Icons.menu_book_outlined,
                label: 'Subjects Scored',
                value: '${rows.length}',
                color: theme.colorScheme.onSurface,
              ),
            ),
            Expanded(
              child: _SummaryStat(
                icon: Icons.star_outline,
                label: 'Best Subject',
                value: best == null
                    ? '—'
                    : '${best.subjectName} · ${bestPct.toStringAsFixed(0)}%',
                color: ScholifyColors.onTint(
                  ScholifyColors.achievementAmber,
                  theme.brightness,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ExamGroupCard extends StatelessWidget {
  const _ExamGroupCard({required this.group});

  final ExamGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scoredRows = group.rows.where((r) => r.mark != null).toList();
    String? overallChip;
    if (scoredRows.isNotEmpty) {
      var obtained = 0.0;
      var maxTotal = 0.0;
      for (final row in scoredRows) {
        obtained += row.mark!.marksObtained;
        maxTotal += row.mark!.maxMarks;
      }
      overallChip =
          '${percentOf(obtained, maxTotal).toStringAsFixed(1)}% · '
          '${gradeForMarks(obtained, maxTotal)}';
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group.examName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (overallChip != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: ScholifyColors.tintOf(
                        ScholifyColors.academicNavy,
                        theme.brightness,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      overallChip,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: ScholifyColors.onTint(
                          ScholifyColors.academicNavy,
                          theme.brightness,
                        ),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (final row in group.rows) _SubjectRow(row: row),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({required this.row});

  final ExamSubjectRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mark = row.mark;
    final accent = subjectAccent(row.subjectName);
    final now = DateTime.now();
    final isFuture = row.examDate.isAfter(
      DateTime(now.year, now.month, now.day, 23, 59),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ScholifyColors.tintOf(accent, theme.brightness),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.menu_book_outlined,
              size: 20,
              color: ScholifyColors.onTint(accent, theme.brightness),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.subjectName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('d MMM yyyy').format(row.examDate),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (mark != null) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: percentOf(mark.marksObtained, mark.maxMarks) / 100,
                      minHeight: 5,
                      backgroundColor: ScholifyColors.tintOf(
                        accent,
                        theme.brightness,
                      ),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        ScholifyColors.onTint(accent, theme.brightness),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (mark != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_trimNumber(mark.marksObtained)} / ${_trimNumber(mark.maxMarks)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                _GradeChip(
                  grade:
                      mark.grade ??
                      gradeForMarks(mark.marksObtained, mark.maxMarks),
                ),
              ],
            )
          else
            _StatusChip(
              label: isFuture ? 'Upcoming' : 'Awaited',
              accent: scheme.onSurfaceVariant,
            ),
        ],
      ),
    );
  }
}

class _GradeChip extends StatelessWidget {
  const _GradeChip({required this.grade});

  final String grade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = gradeAccent(grade, theme.colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: ScholifyColors.tintOf(accent, theme.brightness),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        grade,
        style: theme.textTheme.labelSmall?.copyWith(
          color: ScholifyColors.onTint(accent, theme.brightness),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: ScholifyColors.tintOf(accent, theme.brightness),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: ScholifyColors.onTint(accent, theme.brightness),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// One subject within an exam group: a scored mark when one exists,
/// otherwise just the schedule entry.
class ExamSubjectRow {
  const ExamSubjectRow({
    required this.subjectName,
    required this.examDate,
    this.mark,
  });

  final String subjectName;
  final DateTime examDate;
  final StudentExamMarkView? mark;
}

/// An exam (e.g. "Monthly Test — October 2026") and its subject rows.
class ExamGroup {
  const ExamGroup({required this.examName, required this.rows});

  final String examName;
  final List<ExamSubjectRow> rows;
}

/// Merges marks and schedules into exam groups. A schedule with a mark
/// renders through the mark (which carries subject/date/max); a schedule
/// without one renders as an unscored row. Groups and rows are ordered
/// by exam date.
List<ExamGroup> buildExamGroups({
  required List<StudentExamMarkView> marks,
  required List<ExamScheduleEntry> schedules,
}) {
  final scoredScheduleIds = marks.map((m) => m.scheduleId).toSet();
  final byExam = <String, List<ExamSubjectRow>>{};

  for (final mark in marks) {
    byExam.putIfAbsent(mark.examName, () => []).add(
      ExamSubjectRow(
        subjectName: mark.subjectName,
        examDate: mark.examDate,
        mark: mark,
      ),
    );
  }
  for (final schedule in schedules) {
    if (scoredScheduleIds.contains(schedule.id)) continue;
    byExam.putIfAbsent(schedule.examName, () => []).add(
      ExamSubjectRow(subjectName: schedule.subjectName, examDate: schedule.examDate),
    );
  }

  final groups = [
    for (final entry in byExam.entries)
      ExamGroup(
        examName: entry.key,
        rows: entry.value..sort((a, b) => a.examDate.compareTo(b.examDate)),
      ),
  ];
  groups.sort((a, b) {
    final aFirst = a.rows.isEmpty ? DateTime(1970) : a.rows.first.examDate;
    final bFirst = b.rows.isEmpty ? DateTime(1970) : b.rows.first.examDate;
    return aFirst.compareTo(bFirst);
  });
  return groups;
}

/// Percentage of marks obtained, 0 when max is not positive.
double percentOf(double obtained, double max) {
  if (max <= 0) return 0;
  return (obtained / max) * 100;
}

/// Letter grade for a score, mirroring the staff grade scale.
String gradeForMarks(double obtained, double max) {
  if (max <= 0) return 'N/A';
  final percent = percentOf(obtained, max);
  if (percent >= 90) return 'A+';
  if (percent >= 80) return 'A';
  if (percent >= 70) return 'B+';
  if (percent >= 60) return 'B';
  if (percent >= 50) return 'C';
  if (percent >= 35) return 'D';
  return 'F';
}

/// Accent color for a grade chip.
Color gradeAccent(String grade, ColorScheme scheme) {
  if (grade.startsWith('A')) return ScholifyColors.accentFinance;
  if (grade.startsWith('B')) return ScholifyColors.scholarTeal;
  if (grade.startsWith('C')) return ScholifyColors.achievementAmber;
  if (grade == 'N/A') return scheme.onSurfaceVariant;
  return scheme.error;
}

const _subjectPalette = [
  ScholifyColors.accentAcademics,
  ScholifyColors.scholarTeal,
  ScholifyColors.achievementAmber,
  ScholifyColors.accentStudents,
  ScholifyColors.accentComms,
  ScholifyColors.accentFinance,
];

const _subjectAccents = <String, Color>{
  'mathematics': ScholifyColors.accentAcademics,
  'maths': ScholifyColors.accentAcademics,
  'english': ScholifyColors.accentStudents,
  'science': ScholifyColors.accentFinance,
  'physics': ScholifyColors.accentFinance,
  'chemistry': ScholifyColors.accentFinance,
  'biology': ScholifyColors.accentFinance,
  'social studies': ScholifyColors.achievementAmber,
  'history': ScholifyColors.achievementAmber,
  'geography': ScholifyColors.achievementAmber,
  'art': ScholifyColors.accentComms,
  'urdu': ScholifyColors.scholarTeal,
  'islamiyat': ScholifyColors.scholarTeal,
  'computer science': ScholifyColors.accentOperations,
  'computer': ScholifyColors.accentOperations,
};

/// Stable per-subject accent so each subject keeps its own color:
/// hand-picked for common subjects, hashed fallback for the rest.
Color subjectAccent(String subjectName) {
  final mapped = _subjectAccents[subjectName.trim().toLowerCase()];
  if (mapped != null) return mapped;
  var hash = 0;
  for (final unit in subjectName.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return _subjectPalette[hash % _subjectPalette.length];
}

String _trimNumber(double value) {
  return value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}
