import 'package:flutter/material.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../data/cbse_exam_repository.dart';

class CbseExamPage extends StatefulWidget {
  const CbseExamPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<CbseExamPage> createState() => _CbseExamPageState();
}

class _CbseExamPageState extends State<CbseExamPage> {
  late final CbseExamRepository _repository;
  int _selectedTab = 0; // 0=Results, 1=Schedule

  @override
  void initState() {
    super.initState();
    _repository = CbseExamRepository(
      database: widget.syncEngine.database,
      syncEngine: widget.syncEngine,
      tenantContext: widget.tenantContext,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CBSE Exams')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Results'),
                    selected: _selectedTab == 0,
                    onSelected: (_) => setState(() => _selectedTab = 0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Schedule'),
                    selected: _selectedTab == 1,
                    onSelected: (_) => setState(() => _selectedTab = 1),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<CbseExamResultEntry>>(
              stream: _repository.watchResults(
                resultType: _selectedTab == 0
                    ? CbseExamRepository.typeResult
                    : CbseExamRepository.typeSchedule,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Failed to load: ${snapshot.error}'),
                  );
                }

                final rows = snapshot.data ?? const <CbseExamResultEntry>[];
                if (rows.isEmpty) {
                  return Center(
                    child: Text(
                      _selectedTab == 0
                          ? 'No CBSE exam results found.'
                          : 'No CBSE exam schedule found.',
                    ),
                  );
                }

                if (_selectedTab == 0) {
                  return _buildResultsView(rows);
                }
                return _buildScheduleView(rows);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView(List<CbseExamResultEntry> rows) {
    // Group by exam name
    final grouped = <String, List<CbseExamResultEntry>>{};
    for (final row in rows) {
      grouped.putIfAbsent(row.examName, () => []).add(row);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: grouped.entries.map((entry) {
        final examName = entry.key;
        final subjects = entry.value;

        // Pick summary from first row that has it
        final summary = subjects.firstWhere(
          (s) => s.percentage?.isNotEmpty == true,
          orElse: () => subjects.first,
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Text(
                  examName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              // Subject rows
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Header
                    _tableRow(
                      ['Subject', 'Assessment', 'Marks', 'Max', 'Grade'],
                      isHeader: true,
                    ),
                    const Divider(height: 8),
                    ...subjects.map(
                      (s) => _tableRow([
                        '${s.subjectName}${s.subjectCode?.isNotEmpty == true ? ' (${s.subjectCode})' : ''}',
                        s.assessmentName ?? '-',
                        s.marksObtained?.toStringAsFixed(1) ?? 'xx',
                        s.maxMarks?.toStringAsFixed(0) ?? '-',
                        s.grade ?? '-',
                      ]),
                    ),
                    if (summary.percentage?.isNotEmpty == true ||
                        summary.totalObtained?.isNotEmpty == true) ...[
                      const Divider(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondaryContainer.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            if (summary.totalObtained?.isNotEmpty == true)
                              _summaryChip(
                                'Total',
                                '${summary.totalObtained}/${summary.totalMax ?? '?'}',
                              ),
                            if (summary.percentage?.isNotEmpty == true)
                              _summaryChip('Percent', '${summary.percentage}%'),
                            if (summary.grade?.isNotEmpty == true)
                              _summaryChip('Grade', summary.grade!),
                            if (summary.rank?.isNotEmpty == true)
                              _summaryChip('Rank', summary.rank!),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildScheduleView(List<CbseExamResultEntry> rows) {
    // Group by exam name
    final grouped = <String, List<CbseExamResultEntry>>{};
    for (final row in rows) {
      grouped.putIfAbsent(row.examName, () => []).add(row);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: grouped.entries.map((entry) {
        final examName = entry.key;
        final subjects = entry.value;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.tertiaryContainer.withValues(alpha: 0.4),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Text(
                  examName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: subjects.map((s) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.subjectName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (s.subjectCode?.isNotEmpty == true)
                                  Text(
                                    s.subjectCode!,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(s.examDate ?? '-'),
                          ),
                          Expanded(
                            child: Text(s.timeFrom ?? '-'),
                          ),
                          Expanded(
                            child: Text(
                              s.duration?.isNotEmpty == true
                                  ? '${s.duration}m'
                                  : '-',
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _tableRow(List<String> cells, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: cells.asMap().entries.map((e) {
          final flex = e.key == 0 ? 3 : 2;
          return Expanded(
            flex: flex,
            child: Text(
              e.value,
              style: TextStyle(
                fontWeight:
                    isHeader ? FontWeight.bold : FontWeight.normal,
                fontSize: isHeader ? 11 : 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _summaryChip(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
