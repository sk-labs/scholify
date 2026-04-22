import 'package:flutter/material.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../data/homework_repository.dart';

class HomeworkAssignmentsPage extends StatefulWidget {
  const HomeworkAssignmentsPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<HomeworkAssignmentsPage> createState() =>
      _HomeworkAssignmentsPageState();
}

class _HomeworkAssignmentsPageState extends State<HomeworkAssignmentsPage> {
  late final HomeworkRepository _repository;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _classSectionController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _attachmentController = TextEditingController();

  String _selectedType = HomeworkRepository.homeworkType;
  DateTime? _selectedDueDate;
  bool _isSaving = false;

  // Submission panel state
  HomeworkAssignmentEntry? _viewingSubmissionsFor;

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
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _classSectionController.dispose();
    _detailsController.dispose();
    _attachmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Homework & Daily Assignments')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTypeSelector(),
            const SizedBox(height: 12),
            _buildComposerCard(),
            const SizedBox(height: 12),
            if (_viewingSubmissionsFor != null) ...[
              _buildSubmissionsPanel(_viewingSubmissionsFor!),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: StreamBuilder<List<HomeworkAssignmentEntry>>(
                stream: _repository.watchAssignments(
                  assignmentType: _selectedType,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Failed to load assignments: ${snapshot.error}',
                      ),
                    );
                  }

                  final rows =
                      snapshot.data ?? const <HomeworkAssignmentEntry>[];
                  if (rows.isEmpty) {
                    return Center(
                      child: Text(
                        _selectedType == HomeworkRepository.dailyAssignmentType
                            ? 'No daily assignments found.'
                            : 'No homework assignments found.',
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      final isViewing = _viewingSubmissionsFor?.id == row.id;
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            row.assignmentType ==
                                    HomeworkRepository.dailyAssignmentType
                                ? Icons.wb_sunny_outlined
                                : Icons.menu_book_outlined,
                          ),
                          title: Text(row.title),
                          subtitle: Text(_assignmentSubtitle(row)),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: isViewing
                                    ? 'Hide submissions'
                                    : 'View submissions',
                                icon: Icon(
                                  isViewing
                                      ? Icons.expand_less
                                      : Icons.assignment_turned_in_outlined,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _viewingSubmissionsFor =
                                        isViewing ? null : row;
                                  });
                                },
                              ),
                              IconButton(
                                tooltip: 'Delete assignment',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: _isSaving
                                    ? null
                                    : () => _deleteAssignment(row),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionsPanel(HomeworkAssignmentEntry assignment) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Submissions: ${assignment.title}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _promptAddSubmission(assignment),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Submission'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 260,
              child: StreamBuilder<List<HomeworkSubmissionEntry>>(
                stream: _repository.watchSubmissions(
                  assignmentId: assignment.id,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final submissions =
                      snapshot.data ?? const <HomeworkSubmissionEntry>[];
                  if (submissions.isEmpty) {
                    return const Center(
                      child: Text('No submissions yet for this assignment.'),
                    );
                  }
                  return ListView.separated(
                    itemCount: submissions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final sub = submissions[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                          'Student: ${sub.studentId}  •  ${sub.statusLabel.toUpperCase()}',
                        ),
                        subtitle: Text(
                          [
                            if (sub.submissionText?.isNotEmpty == true)
                              sub.submissionText!,
                            if (sub.teacherFeedback?.isNotEmpty == true)
                              'Feedback: ${sub.teacherFeedback}',
                            if (sub.gradeScore != null)
                              'Grade: ${sub.gradeScore!.toStringAsFixed(1)}',
                          ].join(' | '),
                        ),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Submission actions',
                          onSelected: (action) =>
                              _handleSubmissionAction(action, sub),
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'review',
                              child: Text('Review / Grade'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _promptAddSubmission(HomeworkAssignmentEntry assignment) async {
    final studentController = TextEditingController();
    final textController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Submission'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: studentController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Student ID'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: textController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Submission text'),
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

    studentController.dispose();
    textController.dispose();

    if (confirmed != true) return;

    final studentId = studentController.text.trim();
    if (studentId.isEmpty) return;

    try {
      await _repository.submitHomework(
        assignmentId: assignment.id,
        studentId: studentId,
        submissionText: textController.text.trim().isEmpty
            ? null
            : textController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submission saved and queued.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save submission: $e')),
        );
      }
    }
  }

  Future<void> _handleSubmissionAction(
    String action,
    HomeworkSubmissionEntry submission,
  ) async {
    if (action == 'delete') {
      try {
        await _repository.deleteSubmission(submission);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Submission deleted.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
      return;
    }

    if (action == 'review') {
      final feedbackController = TextEditingController(
        text: submission.teacherFeedback ?? '',
      );
      final gradeController = TextEditingController(
        text: submission.gradeScore?.toStringAsFixed(1) ?? '',
      );
      String status = submission.statusLabel;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setInner) => AlertDialog(
            title: const Text('Review Submission'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(
                      value: 'submitted',
                      child: Text('Submitted'),
                    ),
                    DropdownMenuItem(
                      value: 'reviewed',
                      child: Text('Reviewed'),
                    ),
                    DropdownMenuItem(
                      value: 'graded',
                      child: Text('Graded'),
                    ),
                    DropdownMenuItem(
                      value: 'returned',
                      child: Text('Returned'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setInner(() => status = v);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: feedbackController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Feedback'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: gradeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Grade score'),
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
                child: const Text('Save Review'),
              ),
            ],
          ),
        ),
      );

      feedbackController.dispose();
      gradeController.dispose();

      if (confirmed != true) return;

      try {
        await _repository.reviewSubmission(
          submission: submission,
          statusLabel: status,
          teacherFeedback: feedbackController.text.trim().isEmpty
              ? null
              : feedbackController.text.trim(),
          gradeScore: double.tryParse(gradeController.text.trim()),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Review saved and queued.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save review: $e')),
          );
        }
      }
    }
  }

  Widget _buildTypeSelector() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          ChoiceChip(
            label: const Text('Homework'),
            selected: _selectedType == HomeworkRepository.homeworkType,
            onSelected: (_) {
              setState(() {
                _selectedType = HomeworkRepository.homeworkType;
                _viewingSubmissionsFor = null;
              });
            },
          ),
          ChoiceChip(
            label: const Text('Daily Assignment'),
            selected: _selectedType == HomeworkRepository.dailyAssignmentType,
            onSelected: (_) {
              setState(() {
                _selectedType = HomeworkRepository.dailyAssignmentType;
                _viewingSubmissionsFor = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildComposerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedType == HomeworkRepository.dailyAssignmentType
                  ? 'Add Daily Assignment'
                  : 'Add Homework',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _subjectController,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _classSectionController,
                    decoration: const InputDecoration(
                      labelText: 'Class Section',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _pickDueDate,
                  icon: const Icon(Icons.event),
                  label: Text(
                    _selectedDueDate == null
                        ? 'Set Due Date'
                        : _formatDate(_selectedDueDate!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _detailsController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Details',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _attachmentController,
              decoration: const InputDecoration(
                labelText: 'Attachment URL (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveAssignment,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_task),
              label: Text(_isSaving ? 'Saving...' : 'Save Assignment'),
            ),
          ],
        ),
      ),
    );
  }

  String _assignmentSubtitle(HomeworkAssignmentEntry row) {
    final subject = row.subjectName?.trim().isNotEmpty == true
        ? row.subjectName!.trim()
        : 'Subject NA';
    final classSection = row.classSection?.trim().isNotEmpty == true
        ? row.classSection!.trim()
        : 'Class NA';
    final due = row.dueDate == null ? 'No due date' : _formatDate(row.dueDate!);
    final details = row.details?.trim().isNotEmpty == true
        ? row.details!.trim()
        : 'No details';

    return '$subject | $classSection | Due: $due\n$details';
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (picked == null) return;
    setState(() {
      _selectedDueDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        23,
        59,
      );
    });
  }

  Future<void> _saveAssignment() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Title is required.')));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.saveAssignment(
        assignmentType: _selectedType,
        title: title,
        subjectName: _emptyToNull(_subjectController.text),
        classSection: _emptyToNull(_classSectionController.text),
        details: _emptyToNull(_detailsController.text),
        assignedOn: DateTime.now(),
        dueDate: _selectedDueDate,
        attachmentUrl: _emptyToNull(_attachmentController.text),
      );

      _titleController.clear();
      _subjectController.clear();
      _classSectionController.clear();
      _detailsController.clear();
      _attachmentController.clear();
      _selectedDueDate = null;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment saved locally and queued for sync.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save assignment: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteAssignment(HomeworkAssignmentEntry assignment) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.deleteAssignment(assignment);
      if (_viewingSubmissionsFor?.id == assignment.id) {
        setState(() => _viewingSubmissionsFor = null);
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Assignment deleted.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete assignment: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

