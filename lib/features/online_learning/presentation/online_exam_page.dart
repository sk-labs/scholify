import 'package:flutter/material.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../data/online_exam_repository.dart';

class OnlineExamPage extends StatefulWidget {
  const OnlineExamPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<OnlineExamPage> createState() => _OnlineExamPageState();
}

class _OnlineExamPageState extends State<OnlineExamPage> {
  late final OnlineExamRepository _repository;
  int _selectedTab = 0; // 0=Upcoming, 1=Closed

  @override
  void initState() {
    super.initState();
    _repository = OnlineExamRepository(
      database: widget.syncEngine.database,
      syncEngine: widget.syncEngine,
      tenantContext: widget.tenantContext,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Online Examination')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Upcoming'),
                    selected: _selectedTab == 0,
                    onSelected: (_) => setState(() => _selectedTab = 0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Closed / Submitted'),
                    selected: _selectedTab == 1,
                    onSelected: (_) => setState(() => _selectedTab = 1),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<OnlineExamEntry>>(
              stream: _repository.watchExams(
                isSubmitted: _selectedTab == 1 ? true : false,
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

                final rows = snapshot.data ?? const <OnlineExamEntry>[];
                if (rows.isEmpty) {
                  return Center(
                    child: Text(
                      _selectedTab == 0
                          ? 'No upcoming exams.'
                          : 'No submitted exams.',
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _buildExamCard(rows[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamCard(OnlineExamEntry exam) {
    final isUpcoming = !exam.isSubmitted;
    final canStart = isUpcoming && exam.attemptCount < exam.totalAttempt;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isUpcoming
                  ? Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.4)
                  : Theme.of(
                      context,
                    ).colorScheme.secondaryContainer.withValues(alpha: 0.4),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    exam.examTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (exam.isQuiz)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'QUIZ',
                      style: TextStyle(
                        color: Colors.purple,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (exam.examFrom?.isNotEmpty == true)
                  _row('From', exam.examFrom!),
                if (exam.examTo?.isNotEmpty == true)
                  _row('To', exam.examTo!),
                _row('Questions', '${exam.totalQuestions}'),
                _row(
                  'Duration',
                  exam.durationMinutes > 0
                      ? '${exam.durationMinutes} min'
                      : 'Unlimited',
                ),
                _row('Passing', '${exam.passingPercent.toStringAsFixed(0)}%'),
                _row(
                  'Attempts',
                  '${exam.attemptCount} / ${exam.totalAttempt}',
                ),
                if (exam.isSubmitted && exam.lastScorePercent != null) ...[
                  const Divider(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _row(
                          'Score',
                          '${exam.lastScorePercent!.toStringAsFixed(1)}%',
                        ),
                      ),
                      Expanded(
                        child: _row(
                          'Result',
                          exam.isPassed ? 'PASSED' : 'FAILED',
                          valueColor:
                              exam.isPassed ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
                if (exam.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    exam.description!,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                if (isUpcoming)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: canStart
                          ? () => _promptStartExam(exam)
                          : null,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(
                        canStart
                            ? 'Start Exam'
                            : 'Max Attempts Reached',
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Submitted'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _promptStartExam(OnlineExamEntry exam) async {
    // In a full implementation this would launch an exam-taking flow.
    // For now we show a score entry dialog to simulate submission.
    final scoreController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Submit: ${exam.examTitle}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Duration: ${exam.durationMinutes > 0 ? '${exam.durationMinutes} min' : 'Unlimited'} | '
              'Questions: ${exam.totalQuestions} | '
              'Passing: ${exam.passingPercent.toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: scoreController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Score % (0–100)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    scoreController.dispose();
    if (confirmed != true) return;

    final score = double.tryParse(scoreController.text.trim()) ?? 0;

    try {
      await _repository.submitExam(exam: exam, scorePercent: score);
      if (mounted) {
        final passed = score >= exam.passingPercent;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Submitted — Score: ${score.toStringAsFixed(1)}% — ${passed ? 'PASSED' : 'FAILED'}',
            ),
            backgroundColor: passed ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e')),
        );
      }
    }
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
