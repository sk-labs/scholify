import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../../../core/theme/scholify_colors.dart';
import '../../../core/widgets/scholify_empty_state.dart';
import '../data/homework_repository.dart';

/// Guardian/student-facing homework: read-only list of assignments.
/// No creating or editing — that's the teacher's job.
class GuardianHomeworkPage extends StatefulWidget {
  const GuardianHomeworkPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<GuardianHomeworkPage> createState() => _GuardianHomeworkPageState();
}

class _GuardianHomeworkPageState extends State<GuardianHomeworkPage> {
  late final HomeworkRepository _repository;
  String _filter = 'all'; // all | due_soon | overdue | performance

  @override
  void initState() {
    super.initState();
    _repository = HomeworkRepository(
      database: widget.syncEngine.database,
      syncEngine: widget.syncEngine,
      tenantContext: widget.tenantContext,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = widget.tenantContext.role.toLowerCase();
    final isGuardian = role == 'guardian';

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeader(theme, isGuardian),
          const SizedBox(height: 20),
          _buildFilterChips(theme),
          const SizedBox(height: 16),
          if (_filter == 'performance')
            _buildPerformanceView(theme, isGuardian)
          else
            StreamBuilder<List<HomeworkAssignmentEntry>>(
            stream: _repository.watchAssignments(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              var items = (snapshot.data ?? const [])
                  .where((a) => a.isActive && a.isPublished)
                  .toList();
              items = _applyFilter(items);
              items.sort((a, b) {
                final da = a.dueDate ?? DateTime(2100);
                final db = b.dueDate ?? DateTime(2100);
                return da.compareTo(db);
              });

              if (items.isEmpty) {
                return ScholifyEmptyState(
                  icon: Icons.assignment_outlined,
                  title: 'No homework',
                  message: isGuardian
                      ? 'No homework assigned to your child right now.'
                      : 'No homework assigned right now. Enjoy!',
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    _buildHomeworkCard(theme, items[i]),
                    if (i < items.length - 1) const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<HomeworkAssignmentEntry> _applyFilter(
      List<HomeworkAssignmentEntry> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_filter) {
      case 'due_soon':
        return items.where((a) {
          if (a.dueDate == null) return false;
          final d = DateTime(
              a.dueDate!.year, a.dueDate!.month, a.dueDate!.day);
          final diff = d.difference(today).inDays;
          return diff >= 0 && diff <= 3;
        }).toList();
      case 'overdue':
        return items.where((a) {
          if (a.dueDate == null) return false;
          final d = DateTime(
              a.dueDate!.year, a.dueDate!.month, a.dueDate!.day);
          return d.isBefore(today);
        }).toList();
      default:
        return items;
    }
  }

  /// Performance view: charts showing homework completion stats.
  Widget _buildPerformanceView(ThemeData theme, bool isGuardian) {
    // For guardians, show the first linked child's data.
    // The student ID comes from the student directory.
    return StreamBuilder<List<StudentDirectoryEntry>>(
      stream: widget.syncEngine.database.watchActiveStudentProfiles(
        tenantId: widget.tenantContext.tenantId ?? '',
      ),
      builder: (context, studentSnapshot) {
        final students = studentSnapshot.data ?? const [];
        if (students.isEmpty) {
          return ScholifyEmptyState(
            icon: Icons.analytics_outlined,
            title: 'No performance data',
            message: isGuardian
                ? 'Link a child to see homework performance.'
                : 'No homework data yet.',
          );
        }
        final studentId = students.first.id;
        return StreamBuilder<List<HomeworkAssignmentEntry>>(
          stream: _repository.watchAssignments(),
          builder: (context, assignSnapshot) {
            final assignments = (assignSnapshot.data ?? const [])
                .where((a) => a.isActive && a.isPublished)
                .toList();
            return StreamBuilder<List<HomeworkSubmissionEntry>>(
              stream: _repository.watchStudentSubmissions(
                studentId: studentId,
              ),
              builder: (context, subSnapshot) {
                final submissions = subSnapshot.data ?? const [];
                return _buildPerformanceCharts(
                  theme,
                  assignments,
                  submissions,
                  isGuardian,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPerformanceCharts(
    ThemeData theme,
    List<HomeworkAssignmentEntry> assignments,
    List<HomeworkSubmissionEntry> submissions,
    bool isGuardian,
  ) {
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Submitted assignment IDs.
    final submittedIds =
        submissions.map((s) => s.assignmentId).toSet();

    int completed = 0;
    int pending = 0;
    int overdue = 0;
    final subjectStats = <String, Map<String, int>>{};

    for (final a in assignments) {
      final subject = a.subjectName ?? 'General';
      subjectStats.putIfAbsent(
          subject, () => {'total': 0, 'done': 0});
      subjectStats[subject]!['total'] =
          subjectStats[subject]!['total']! + 1;

      if (submittedIds.contains(a.id)) {
        completed++;
        subjectStats[subject]!['done'] =
            subjectStats[subject]!['done']! + 1;
      } else if (a.dueDate != null) {
        final d = DateTime(
            a.dueDate!.year, a.dueDate!.month, a.dueDate!.day);
        if (d.isBefore(today)) {
          overdue++;
        } else {
          pending++;
        }
      } else {
        pending++;
      }
    }

    final total = assignments.length;
    final completionRate =
        total == 0 ? 0.0 : (completed / total) * 100;

    // Average grade from graded submissions.
    final grades = submissions
        .where((s) => s.gradeScore != null)
        .map((s) => s.gradeScore!)
        .toList();
    final avgGrade = grades.isEmpty
        ? null
        : grades.reduce((a, b) => a + b) / grades.length;

    return Column(
      children: [
        _buildPerfStatCards(
            theme, completionRate, completed, pending, overdue, avgGrade),
        const SizedBox(height: 20),
        _buildCompletionGauge(
            theme, scheme, completionRate, completed, pending, overdue),
        const SizedBox(height: 20),
        _buildWeeklyStrip(
            theme, scheme, assignments, submittedIds),
        const SizedBox(height: 20),
        _buildSubjectBars(theme, scheme, subjectStats),
      ],
    );
  }

  Widget _buildPerfStatCards(
    ThemeData theme,
    double completionRate,
    int completed,
    int pending,
    int overdue,
    double? avgGrade,
  ) {
    final cards = [
      _PerfStatCard(
        label: 'Completion Rate',
        value: '${completionRate.toStringAsFixed(0)}%',
        icon: Icons.percent_outlined,
        color: ScholifyColors.scholarTeal,
      ),
      _PerfStatCard(
        label: 'Completed',
        value: '$completed',
        icon: Icons.check_circle_outlined,
        color: ScholifyColors.success,
      ),
      _PerfStatCard(
        label: 'Pending',
        value: '$pending',
        icon: Icons.schedule_outlined,
        color: ScholifyColors.achievementAmber,
      ),
      _PerfStatCard(
        label: 'Overdue',
        value: '$overdue',
        icon: Icons.warning_amber_outlined,
        color: ScholifyColors.error,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return GridView.count(
          crossAxisCount: isWide ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.7,
          children: cards,
        );
      },
    );
  }

  /// Radial completion gauge — visually distinct from the donut
  /// used on the attendance page.
  Widget _buildCompletionGauge(
    ThemeData theme,
    ColorScheme scheme,
    double completionRate,
    int completed,
    int pending,
    int overdue,
  ) {
    final total = completed + pending + overdue;
    if (total == 0) {
      return ScholifyEmptyState(
        icon: Icons.donut_large_outlined,
        title: 'No homework yet',
        message: 'Completion stats will appear here.',
      );
    }
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Completion Gauge',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Share of homework finished on time',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: CustomPaint(
                  painter: _GaugePainter(
                    progress: completionRate / 100,
                    trackColor:
                        scheme.outlineVariant.withValues(alpha: 0.5),
                    progressColor: ScholifyColors.scholarTeal,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${completionRate.toStringAsFixed(0)}%',
                          style: theme.textTheme.headlineLarge
                              ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: ScholifyColors.scholarTeal,
                          ),
                        ),
                        Text(
                          'complete',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _GaugeStat(
                    value: '$completed',
                    label: 'Done',
                    color: ScholifyColors.success),
                _GaugeStat(
                    value: '$pending',
                    label: 'Pending',
                    color: ScholifyColors.achievementAmber),
                _GaugeStat(
                    value: '$overdue',
                    label: 'Overdue',
                    color: ScholifyColors.error),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Segmented weekly activity strip — a different rhythm from the
  /// bar chart below it.
  Widget _buildWeeklyStrip(
    ThemeData theme,
    ColorScheme scheme,
    List<HomeworkAssignmentEntry> assignments,
    Set<String> submittedIds,
  ) {
    final now = DateTime.now();
    // Last 4 weeks, oldest first.
    final weeks = List.generate(4, (i) {
      final end =
          DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: now.weekday % 7 + i * 7));
      final start = end.subtract(const Duration(days: 6));
      return (start, end);
    }).reversed.toList();

    int maxCount = 1;
    final counts = <int>[];
    final doneCounts = <int>[];
    for (final (start, end) in weeks) {
      int total = 0;
      int done = 0;
      for (final a in assignments) {
        final d = a.assignedOn ?? a.dueDate;
        if (d == null) continue;
        final day = DateTime(d.year, d.month, d.day);
        if (!day.isBefore(start) && !day.isAfter(end)) {
          total++;
          if (submittedIds.contains(a.id)) done++;
        }
      }
      counts.add(total);
      doneCounts.add(done);
      if (total > maxCount) maxCount = total;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weekly Activity',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Assignments given vs finished, last 4 weeks',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < weeks.length; i++)
                  Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 110,
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.end,
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                _StripBar(
                                  fraction: counts[i] / maxCount,
                                  color: scheme.outlineVariant,
                                ),
                                const SizedBox(width: 6),
                                _StripBar(
                                  fraction:
                                      doneCounts[i] / maxCount,
                                  color:
                                      ScholifyColors.scholarTeal,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'W${4 - i}',
                            style: theme.textTheme.labelSmall,
                          ),
                          Text(
                            '${doneCounts[i]}/${counts[i]}',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PerfLegend(
                    color: scheme.outlineVariant,
                    label: 'Given'),
                const SizedBox(width: 16),
                _PerfLegend(
                    color: ScholifyColors.scholarTeal,
                    label: 'Finished'),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildSubjectBars(
    ThemeData theme,
    ColorScheme scheme,
    Map<String, Map<String, int>> subjectStats,
  ) {
    if (subjectStats.isEmpty) return const SizedBox.shrink();
    final subjects = subjectStats.keys.toList();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('By Subject',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Completed vs total assignments per subject',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: (subjectStats.values
                              .map((s) => s['total']!)
                              .reduce((a, b) =>
                                  a > b ? a : b)
                              .toDouble()) +
                      1,
                  barGroups: [
                    for (var i = 0;
                        i < subjects.length;
                        i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: subjectStats[subjects[i]]![
                                    'done']!
                                .toDouble(),
                            color: ScholifyColors.scholarTeal,
                            width: 18,
                            borderRadius:
                                BorderRadius.circular(4),
                          ),
                          BarChartRodData(
                            toY: (subjectStats[subjects[i]]![
                                            'total']! -
                                        subjectStats[subjects[i]]![
                                            'done']!)
                                    .toDouble(),
                            color: scheme.outlineVariant,
                            width: 18,
                            borderRadius:
                                BorderRadius.circular(4),
                          ),
                        ],
                      ),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx < 0 ||
                              idx >= subjects.length) {
                            return const SizedBox.shrink();
                          }
                          final name = subjects[idx];
                          return Padding(
                            padding:
                                const EdgeInsets.only(top: 4),
                            child: Text(
                              name.length > 8
                                  ? '${name.substring(0, 8)}…'
                                  : name,
                              style:
                                  theme.textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PerfLegend(
                    color: ScholifyColors.scholarTeal,
                    label: 'Completed'),
                const SizedBox(width: 16),
                _PerfLegend(
                    color: scheme.outlineVariant,
                    label: 'Remaining'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isGuardian) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ScholifyColors.academicNavy,
            ScholifyColors.navyLight,
            ScholifyColors.scholarTeal.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ScholifyColors.academicNavy.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Homework',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Assignments',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isGuardian
                      ? 'What your child needs to work on'
                      : 'What you need to work on',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.assignment_outlined,
                color: Colors.white, size: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme) {
    final chips = [
      ('all', 'All'),
      ('due_soon', 'Due Soon'),
      ('overdue', 'Overdue'),
      ('performance', 'Performance'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final chip in chips)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(chip.$2),
                selected: _filter == chip.$1,
                onSelected: (_) =>
                    setState(() => _filter = chip.$1),
                selectedColor: ScholifyColors.academicNavy,
                labelStyle: TextStyle(
                  color: _filter == chip.$1
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHomeworkCard(
      ThemeData theme, HomeworkAssignmentEntry item) {
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    Color statusColor = ScholifyColors.scholarTeal;
    String statusLabel = 'Upcoming';
    IconData statusIcon = Icons.schedule_outlined;
    if (item.dueDate != null) {
      final d = DateTime(item.dueDate!.year, item.dueDate!.month,
          item.dueDate!.day);
      final diff = d.difference(today).inDays;
      if (diff < 0) {
        statusColor = ScholifyColors.error;
        statusLabel = 'Overdue';
        statusIcon = Icons.warning_amber_outlined;
      } else if (diff == 0) {
        statusColor = ScholifyColors.achievementAmber;
        statusLabel = 'Due today';
        statusIcon = Icons.today_outlined;
      } else if (diff <= 3) {
        statusColor = ScholifyColors.achievementAmber;
        statusLabel = 'Due in $diff days';
        statusIcon = Icons.upcoming_outlined;
      }
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusIcon,
                      color: statusColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700),
                      ),
                      if (item.subjectName != null)
                        Text(
                          item.subjectName!,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (item.details != null && item.details!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(item.details!,
                  style: theme.textTheme.bodyMedium),
            ],
            if (item.dueDate != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.event_outlined,
                      size: 14,
                      color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'Due ${DateFormat('EEE, d MMM yyyy').format(item.dueDate!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PerfStatCard extends StatelessWidget {
  const _PerfStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: theme.colorScheme.outlineVariant
                .withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(height: 6),
            Text(value,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            Text(label,
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _PerfLegend extends StatelessWidget {
  const _PerfLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Radial progress ring painter for the completion gauge.
class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 18.0;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Full track circle.
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc, starting at top (-90 degrees).
    final sweep = (progress.clamp(0.0, 1.0)) * 3.141592653589793 * 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.141592653589793 / 2,
      sweep,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}

class _GaugeStat extends StatelessWidget {
  const _GaugeStat({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// Single vertical bar in the weekly strip.
class _StripBar extends StatelessWidget {
  const _StripBar({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: (fraction.clamp(0.0, 1.0) * 100).clamp(6.0, 100.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
