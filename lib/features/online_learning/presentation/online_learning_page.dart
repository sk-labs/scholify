import 'package:flutter/material.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../data/online_learning_repository.dart';

class OnlineLearningPage extends StatefulWidget {
  const OnlineLearningPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<OnlineLearningPage> createState() => _OnlineLearningPageState();
}

class _OnlineLearningPageState extends State<OnlineLearningPage> {
  late final OnlineLearningRepository _repository;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _instructorController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  String _selectedType = OnlineLearningRepository.courseType;
  String _accessLevel = 'open';
  bool _isSaving = false;

  // Attempt panel state
  OnlineLearningEntry? _viewingAttemptsFor;

  @override
  void initState() {
    super.initState();
    _repository = OnlineLearningRepository(
      database: widget.syncEngine.database,
      syncEngine: widget.syncEngine,
      tenantContext: widget.tenantContext,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _instructorController.dispose();
    _durationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Online Learning Catalog')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTypeSelector(),
            const SizedBox(height: 12),
            _buildComposerCard(),
            const SizedBox(height: 12),
            if (_viewingAttemptsFor != null) ...[
              _buildAttemptsPanel(_viewingAttemptsFor!),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: StreamBuilder<List<OnlineLearningEntry>>(
                stream: _repository.watchItems(itemType: _selectedType),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Failed to load items: ${snapshot.error}'),
                    );
                  }

                  final rows = snapshot.data ?? const <OnlineLearningEntry>[];
                  if (rows.isEmpty) {
                    return Center(
                      child: Text(
                        _selectedType == OnlineLearningRepository.quizType
                            ? 'No quizzes in catalog.'
                            : 'No courses in catalog.',
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      final isViewing = _viewingAttemptsFor?.id == row.id;
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            row.itemType == OnlineLearningRepository.quizType
                                ? Icons.quiz_outlined
                                : Icons.video_library_outlined,
                          ),
                          title: Text(row.title),
                          subtitle: Text(_itemSubtitle(row)),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: isViewing
                                    ? 'Hide attempts'
                                    : 'View attempts',
                                icon: Icon(
                                  isViewing
                                      ? Icons.expand_less
                                      : Icons.bar_chart_outlined,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _viewingAttemptsFor =
                                        isViewing ? null : row;
                                  });
                                },
                              ),
                              IconButton(
                                tooltip: 'Delete item',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: _isSaving
                                    ? null
                                    : () => _deleteItem(row),
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

  Widget _buildAttemptsPanel(OnlineLearningEntry item) {
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
                    'Attempts: ${item.title}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _promptStartAttempt(item),
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Start Attempt'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 240,
              child: StreamBuilder<List<OnlineLearningAttemptEntry>>(
                stream: _repository.watchItemAttempts(itemId: item.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final attempts =
                      snapshot.data ?? const <OnlineLearningAttemptEntry>[];
                  if (attempts.isEmpty) {
                    return const Center(
                      child: Text('No attempts recorded for this item.'),
                    );
                  }
                  return ListView.separated(
                    itemCount: attempts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final att = attempts[index];
                      final statusIcon = att.isPassed
                          ? Icons.check_circle_outline
                          : att.attemptStatus == 'completed'
                          ? Icons.cancel_outlined
                          : Icons.hourglass_empty;
                      return ListTile(
                        dense: true,
                        leading: Icon(statusIcon, size: 18),
                        title: Text(
                          'Student: ${att.studentId}  •  ${att.attemptStatus.toUpperCase()}',
                        ),
                        subtitle: Text(
                          [
                            if (att.scorePercent != null)
                              'Score: ${att.scorePercent!.toStringAsFixed(1)}%',
                            if (att.durationSeconds != null)
                              'Duration: ${att.durationSeconds}s',
                            if (att.isPassed) 'PASSED' else if (att.attemptStatus == 'completed') 'FAILED',
                          ].join(' | '),
                        ),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Attempt actions',
                          onSelected: (action) =>
                              _handleAttemptAction(action, att),
                          itemBuilder: (context) => [
                            if (att.attemptStatus == 'in_progress')
                              const PopupMenuItem(
                                value: 'complete',
                                child: Text('Mark Complete'),
                              ),
                            const PopupMenuItem(
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

  Future<void> _promptStartAttempt(OnlineLearningEntry item) async {
    final studentController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Attempt'),
        content: TextField(
          controller: studentController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Student ID'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Start'),
          ),
        ],
      ),
    );

    studentController.dispose();
    if (confirmed != true) return;

    final studentId = studentController.text.trim();
    if (studentId.isEmpty) return;

    try {
      await _repository.startAttempt(itemId: item.id, studentId: studentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attempt started and queued.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start attempt: $e')),
        );
      }
    }
  }

  Future<void> _handleAttemptAction(
    String action,
    OnlineLearningAttemptEntry attempt,
  ) async {
    if (action == 'delete') {
      try {
        await _repository.deleteAttempt(attempt);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Attempt deleted.')),
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

    if (action == 'complete') {
      final scoreController = TextEditingController();
      final durationController = TextEditingController();
      bool isPassed = false;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setInner) => AlertDialog(
            title: const Text('Complete Attempt'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: scoreController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Score %',
                    hintText: '0–100',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duration (seconds)',
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Passed'),
                  value: isPassed,
                  onChanged: (v) => setInner(() => isPassed = v ?? false),
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
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );

      scoreController.dispose();
      durationController.dispose();

      if (confirmed != true) return;

      try {
        await _repository.completeAttempt(
          attempt: attempt,
          scorePercent: double.tryParse(scoreController.text.trim()) ?? 0,
          durationSeconds: int.tryParse(durationController.text.trim()) ?? 0,
          isPassed: isPassed,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Attempt completed and queued.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to complete attempt: $e')),
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
            label: const Text('Courses'),
            selected: _selectedType == OnlineLearningRepository.courseType,
            onSelected: (_) {
              setState(() {
                _selectedType = OnlineLearningRepository.courseType;
                _viewingAttemptsFor = null;
              });
            },
          ),
          ChoiceChip(
            label: const Text('Quizzes'),
            selected: _selectedType == OnlineLearningRepository.quizType,
            onSelected: (_) {
              setState(() {
                _selectedType = OnlineLearningRepository.quizType;
                _viewingAttemptsFor = null;
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
              _selectedType == OnlineLearningRepository.quizType
                  ? 'Add Quiz'
                  : 'Add Course',
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
                  width: 220,
                  child: TextField(
                    controller: _instructorController,
                    decoration: const InputDecoration(
                      labelText: 'Instructor',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _durationController,
                    decoration: const InputDecoration(
                      labelText: 'Duration (e.g. 3h 20m)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    initialValue: _accessLevel,
                    decoration: const InputDecoration(
                      labelText: 'Access',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'open', child: Text('Open')),
                      DropdownMenuItem(
                        value: 'enrolled',
                        child: Text('Enrolled'),
                      ),
                      DropdownMenuItem(
                        value: 'premium',
                        child: Text('Premium'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _accessLevel = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _summaryController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Summary',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveItem,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(_isSaving ? 'Saving...' : 'Save Item'),
            ),
          ],
        ),
      ),
    );
  }

  String _itemSubtitle(OnlineLearningEntry item) {
    final instructor = item.instructorName ?? 'Instructor TBD';
    final duration = item.durationLabel ?? 'Duration TBD';
    final summary = item.summary ?? 'No summary';
    final price = item.priceAmount.toStringAsFixed(2);

    return '$instructor | $duration | ${item.accessLevel}\n$summary | Price: $price';
  }

  Future<void> _saveItem() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Title is required.')));
      return;
    }

    final price = double.tryParse(_priceController.text.trim()) ?? 0;

    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.saveItem(
        itemType: _selectedType,
        title: title,
        summary: _emptyToNull(_summaryController.text),
        instructorName: _emptyToNull(_instructorController.text),
        durationLabel: _emptyToNull(_durationController.text),
        accessLevel: _accessLevel,
        priceAmount: price,
        publishedAt: DateTime.now(),
      );

      _titleController.clear();
      _summaryController.clear();
      _instructorController.clear();
      _durationController.clear();
      _priceController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Online learning item saved and queued for sync.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save item: $error')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteItem(OnlineLearningEntry item) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.deleteItem(item);
      if (_viewingAttemptsFor?.id == item.id) {
        setState(() => _viewingAttemptsFor = null);
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Item deleted.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete item: $error')),
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

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

