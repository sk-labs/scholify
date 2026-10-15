import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../../../core/theme/scholify_colors.dart';
import '../../../core/widgets/scholify_empty_state.dart';
import '../data/attendance_repository.dart';

/// Guardian-facing attendance view: analytics and trends for their child.
/// Read-only — no marking controls (that's the teacher's job).
class GuardianAttendancePage extends StatefulWidget {
  const GuardianAttendancePage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<GuardianAttendancePage> createState() => _GuardianAttendancePageState();
}

class _GuardianAttendancePageState extends State<GuardianAttendancePage> {
  late final AttendanceRepository _repository;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _repository = AttendanceRepository(
      database: widget.syncEngine.database,
      syncEngine: widget.syncEngine,
      tenantContext: widget.tenantContext,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: StreamBuilder<List<StudentDirectoryEntry>>(
        stream: _repository.watchStudents(),
        builder: (context, studentSnapshot) {
          final students = studentSnapshot.data ?? const [];
          if (studentSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (students.isEmpty) {
            return Center(
              child: ScholifyEmptyState(
                icon: Icons.family_restroom_outlined,
                title: 'No children linked',
                message:
                    'Contact the school office to link your children to this account.',
              ),
            );
          }
          // For now show the first linked child; a child switcher can be added.
          final child = students.first;
          return _buildAnalytics(context, theme, scheme, child);
        },
      ),
    );
  }

  Widget _buildAnalytics(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
    StudentDirectoryEntry child,
  ) {
    return StreamBuilder<List<StudentAttendanceRecord>>(
      stream: _repository.watchStudentMonth(
        studentId: child.id,
        month: _selectedMonth,
      ),
      builder: (context, snapshot) {
        final records = snapshot.data ?? const [];

        final present = records.where((r) => r.status == 'present').length;
        final absent = records.where((r) => r.status == 'absent').length;
        final late = records.where((r) => r.status == 'late').length;
        final total = records.length;
        final percentage = total == 0 ? 0.0 : (present / total) * 100;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildHeader(context, theme, child),
            const SizedBox(height: 20),
            _buildMonthSelector(theme),
            const SizedBox(height: 20),
            if (records.isEmpty)
              ScholifyEmptyState(
                icon: Icons.calendar_month_outlined,
                title: 'No records this month',
                message:
                    'Attendance for ${DateFormat('MMMM yyyy').format(_selectedMonth)} will appear here.',
              )
            else ...[
              _buildSummaryCards(theme, scheme, present, absent, late, percentage),
              const SizedBox(height: 20),
              _buildDonutCard(theme, scheme, present, absent, late),
              const SizedBox(height: 20),
              _buildTrendCard(theme, scheme, records),
              const SizedBox(height: 20),
              _buildRecentList(theme, scheme, records),
            ],
          ],
        );
      },
    );
  }

  Widget _buildHeader(
      BuildContext context, ThemeData theme, StudentDirectoryEntry child) {
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
                  'Attendance',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  child.fullName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'How ${child.fullName.split(' ').first} is doing this term',
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
            child: const Icon(Icons.fact_check_outlined,
                color: Colors.white, size: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => setState(() {
            _selectedMonth =
                DateTime(_selectedMonth.year, _selectedMonth.month - 1);
          }),
        ),
        Text(
          DateFormat('MMMM yyyy').format(_selectedMonth),
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            final now = DateTime.now();
            final next =
                DateTime(_selectedMonth.year, _selectedMonth.month + 1);
            if (next.isBefore(DateTime(now.year, now.month + 1))) {
              setState(() => _selectedMonth = next);
            }
          },
        ),
      ],
    );
  }

  Widget _buildSummaryCards(
    ThemeData theme,
    ColorScheme scheme,
    int present,
    int absent,
    int late,
    double percentage,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final cards = [
          _StatCard(
            label: 'Attendance Rate',
            value: '${percentage.toStringAsFixed(0)}%',
            icon: Icons.percent_outlined,
            color: ScholifyColors.scholarTeal,
          ),
          _StatCard(
            label: 'Present',
            value: '$present days',
            icon: Icons.check_circle_outlined,
            color: ScholifyColors.success,
          ),
          _StatCard(
            label: 'Absent',
            value: '$absent days',
            icon: Icons.cancel_outlined,
            color: ScholifyColors.error,
          ),
          _StatCard(
            label: 'Late',
            value: '$late days',
            icon: Icons.schedule_outlined,
            color: ScholifyColors.achievementAmber,
          ),
        ];
        if (isWide) {
          return GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: cards,
          );
        }
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.8,
          children: cards,
        );
      },
    );
  }

  Widget _buildDonutCard(
      ThemeData theme, ColorScheme scheme, int present, int absent, int late) {
    final total = present + absent + late;
    if (total == 0) return const SizedBox.shrink();

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
            Text('This Month Breakdown',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 50,
                  sections: [
                    PieChartSectionData(
                      value: present.toDouble(),
                      title: '$present',
                      color: ScholifyColors.success,
                      radius: 60,
                      titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                    PieChartSectionData(
                      value: absent.toDouble(),
                      title: absent > 0 ? '$absent' : '',
                      color: ScholifyColors.error,
                      radius: 60,
                      titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                    PieChartSectionData(
                      value: late.toDouble(),
                      title: late > 0 ? '$late' : '',
                      color: ScholifyColors.achievementAmber,
                      radius: 60,
                      titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(
                    color: ScholifyColors.success, label: 'Present'),
                const SizedBox(width: 16),
                _LegendDot(
                    color: ScholifyColors.error, label: 'Absent'),
                const SizedBox(width: 16),
                _LegendDot(
                    color: ScholifyColors.achievementAmber,
                    label: 'Late'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendCard(
      ThemeData theme, ColorScheme scheme, List<StudentAttendanceRecord> records) {
    // Group by week of month for a simple bar trend.
    final sorted = [...records]
      ..sort((a, b) => a.attendanceDate.compareTo(b.attendanceDate));
    final byDay = <int, double>{};
    for (final r in sorted) {
      byDay[r.attendanceDate.day] =
          r.status == 'present' ? 1.0 : (r.status == 'late' ? 0.5 : 0.0);
    }
    final spots = byDay.entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    if (spots.isEmpty) return const SizedBox.shrink();

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
            Text('Daily Trend',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Green = present, amber = late, red = absent',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: 1.2,
                  barGroups: spots.map((s) {
                    final color = s.y == 1.0
                        ? ScholifyColors.success
                        : (s.y == 0.5
                            ? ScholifyColors.achievementAmber
                            : ScholifyColors.error);
                    return BarChartGroupData(
                      x: s.x.toInt(),
                      barRods: [
                        BarChartRodData(
                          toY: s.y == 0 ? 0.08 : s.y,
                          color: color,
                          width: 14,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) => Text(
                          '${v.toInt()}',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentList(
      ThemeData theme, ColorScheme scheme, List<StudentAttendanceRecord> records) {
    final sorted = [...records]
      ..sort((a, b) => b.attendanceDate.compareTo(a.attendanceDate));
    final recent = sorted.take(7).toList();

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
            Text('Recent Days',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            for (final r in recent) _buildDayRow(theme, r),
          ],
        ),
      ),
    );
  }

  Widget _buildDayRow(ThemeData theme, StudentAttendanceRecord record) {
    final isPresent = record.status == 'present';
    final isLate = record.status == 'late';
    final color = isPresent
        ? ScholifyColors.success
        : (isLate ? ScholifyColors.achievementAmber : ScholifyColors.error);
    final icon = isPresent
        ? Icons.check_circle
        : (isLate ? Icons.schedule : Icons.cancel);
    final label = isPresent
        ? 'Present'
        : (isLate ? 'Late' : 'Absent');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, d MMM yyyy')
                      .format(record.attendanceDate),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(label,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
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
            color:
                theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(value,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
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
