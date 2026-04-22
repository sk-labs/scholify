import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/exam_repository.dart';

class ExamAnalyticsPanel extends StatefulWidget {
  const ExamAnalyticsPanel({
    super.key,
    required this.repository,
    required this.month,
  });

  final ExamRepository repository;
  final DateTime month;

  @override
  State<ExamAnalyticsPanel> createState() => _ExamAnalyticsPanelState();
}

class _ExamAnalyticsPanelState extends State<ExamAnalyticsPanel> {
  String? _subjectFilter;
  String? _classFilter;

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(widget.month);

    return StreamBuilder<ExamAnalyticsSnapshot>(
      stream: widget.repository.watchExamAnalytics(
        month: widget.month,
        subjectName: _subjectFilter,
        classSection: _classFilter,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(child: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return Card(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load exam analytics: ${snapshot.error}'),
              ),
            ),
          );
        }

        final analytics =
            snapshot.data ??
            const ExamAnalyticsSnapshot(
              totalAttempts: 0,
              uniqueStudents: 0,
              averagePercent: 0,
              passRate: 0,
              gradeDistribution: <String, int>{},
              subjectPerformance: <ExamSubjectPerformance>[],
              topperList: <ExamTopperMetric>[],
              trendPoints: <ExamTrendPoint>[],
              availableSubjects: <String>[],
              availableClassSections: <String>[],
            );

        _ensureFilterValidity(analytics);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exam Analytics Dashboard ($monthLabel)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 210,
                      child: DropdownButtonFormField<String?>(
                        initialValue: _subjectFilter,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Subject Filter',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All Subjects'),
                          ),
                          ...analytics.availableSubjects.map(
                            (subject) => DropdownMenuItem<String?>(
                              value: subject,
                              child: Text(
                                subject,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _subjectFilter = value;
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: 210,
                      child: DropdownButtonFormField<String?>(
                        initialValue: _classFilter,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Class Filter',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All Classes'),
                          ),
                          ...analytics.availableClassSections.map(
                            (className) => DropdownMenuItem<String?>(
                              value: className,
                              child: Text(
                                className,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _classFilter = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _metricChip('Attempts', '${analytics.totalAttempts}'),
                    _metricChip('Students', '${analytics.uniqueStudents}'),
                    _metricChip(
                      'Average %',
                      analytics.averagePercent.toStringAsFixed(1),
                    ),
                    _metricChip(
                      'Pass Rate %',
                      analytics.passRate.toStringAsFixed(1),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (!analytics.hasData)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No marks found for selected filters in this month.',
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView(
                      children: [
                        _buildGradeDistribution(analytics.gradeDistribution),
                        const SizedBox(height: 8),
                        _buildSubjectPerformance(analytics.subjectPerformance),
                        const SizedBox(height: 8),
                        _buildToppers(analytics.topperList),
                        const SizedBox(height: 8),
                        _buildTrend(analytics.trendPoints),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _ensureFilterValidity(ExamAnalyticsSnapshot analytics) {
    if (_subjectFilter != null &&
        !analytics.availableSubjects.contains(_subjectFilter)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _subjectFilter = null;
        });
      });
    }

    if (_classFilter != null &&
        !analytics.availableClassSections.contains(_classFilter)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _classFilter = null;
        });
      });
    }
  }

  Widget _buildGradeDistribution(Map<String, int> grades) {
    if (grades.isEmpty) {
      return const SizedBox.shrink();
    }

    final order = <String>['A+', 'A', 'B+', 'B', 'C', 'D', 'F', 'N/A'];
    final sortedKeys = grades.keys.toList()
      ..sort((a, b) {
        final ai = order.indexOf(a);
        final bi = order.indexOf(b);
        if (ai == -1 && bi == -1) return a.compareTo(b);
        if (ai == -1) return 1;
        if (bi == -1) return -1;
        return ai.compareTo(bi);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Grade Distribution'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final grade in sortedKeys)
              Chip(label: Text('$grade: ${grades[grade]}')),
          ],
        ),
      ],
    );
  }

  Widget _buildSubjectPerformance(List<ExamSubjectPerformance> items) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Subject Performance'),
        const SizedBox(height: 4),
        for (final item in items.take(5))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(item.subjectName),
            subtitle: Text(
              'Attempts: ${item.attempts} | Avg: ${item.averagePercent.toStringAsFixed(1)}% | Pass: ${item.passRate.toStringAsFixed(1)}%',
            ),
          ),
      ],
    );
  }

  Widget _buildToppers(List<ExamTopperMetric> toppers) {
    if (toppers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Top Performers'),
        const SizedBox(height: 4),
        for (final topper in toppers.take(5))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(topper.studentName),
            subtitle: Text(
              '${topper.classSection ?? 'Class N/A'} | ${topper.totalObtained.toStringAsFixed(1)} / ${topper.totalMax.toStringAsFixed(1)}',
            ),
            trailing: Text('${topper.averagePercent.toStringAsFixed(1)}%'),
          ),
      ],
    );
  }

  Widget _buildTrend(List<ExamTrendPoint> trendPoints) {
    if (trendPoints.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Daily Trend'),
        const SizedBox(height: 4),
        for (final point in trendPoints)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(DateFormat('dd MMM yyyy').format(point.date)),
            subtitle: Text('Attempts: ${point.attempts}'),
            trailing: Text('${point.averagePercent.toStringAsFixed(1)}%'),
          ),
      ],
    );
  }

  Widget _metricChip(String label, String value) {
    return Chip(label: Text('$label: $value'));
  }
}
