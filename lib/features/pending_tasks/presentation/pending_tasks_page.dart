import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../data/pending_task_repository.dart';

class PendingTasksPage extends StatefulWidget {
  const PendingTasksPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<PendingTasksPage> createState() => _PendingTasksPageState();
}

class _PendingTasksPageState extends State<PendingTasksPage> {
  late final PendingTaskRepository _repository;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _userController = TextEditingController();
  DateTime? _dueDate;
  String _priority = 'medium';
  bool _isCompleted = false;
  bool _isActive = true;
  bool _includeInactive = false;
  bool _isSaving = false;
  String? _editingTaskId;

  @override
  void initState() {
    super.initState();
    _repository = PendingTaskRepository(
      database: widget.syncEngine.database,
      syncEngine: widget.syncEngine,
      tenantContext: widget.tenantContext,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _userController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pending Tasks')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 260,
                          child: TextField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'Task Title',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: _userController,
                            decoration: const InputDecoration(
                              labelText: 'User ID',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _pickDueDate,
                          icon: const Icon(Icons.event),
                          label: Text(
                            _dueDate == null
                                ? 'Pick Due Date'
                                : DateFormat('dd MMM yyyy').format(_dueDate!),
                          ),
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: _priority,
                          decoration: const InputDecoration(
                            labelText: 'Priority',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'low', child: Text('Low')),
                            DropdownMenuItem(
                              value: 'medium',
                              child: Text('Medium'),
                            ),
                            DropdownMenuItem(
                              value: 'high',
                              child: Text('High'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _priority = value;
                            });
                          },
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Completed'),
                          value: _isCompleted,
                          onChanged: (value) {
                            setState(() {
                              _isCompleted = value;
                            });
                          },
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Active'),
                          value: _isActive,
                          onChanged: (value) {
                            setState(() {
                              _isActive = value;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: _isSaving ? null : _saveTask,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(
                            _editingTaskId == null
                                ? 'Save Task'
                                : 'Update Task',
                          ),
                        ),
                        OutlinedButton(
                          onPressed: _clearForm,
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Include inactive tasks'),
              value: _includeInactive,
              onChanged: (value) {
                setState(() {
                  _includeInactive = value;
                });
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<PendingTaskEntry>>(
                stream: _repository.watchPendingTasks(
                  includeInactive: _includeInactive,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Failed to load pending tasks: ${snapshot.error}',
                      ),
                    );
                  }

                  final rows = snapshot.data ?? const <PendingTaskEntry>[];
                  if (rows.isEmpty) {
                    return const Center(child: Text('No pending tasks yet.'));
                  }

                  return ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      final dueText = row.dueDate == null
                          ? 'No due date'
                          : 'Due ${DateFormat('dd MMM yyyy').format(row.dueDate!.toLocal())}';

                      return Card(
                        child: ListTile(
                          leading: Icon(
                            row.isCompleted
                                ? Icons.check_circle
                                : Icons.pending_actions,
                            color: row.isCompleted ? Colors.green : null,
                          ),
                          title: Text(row.title),
                          subtitle: Text(
                            '${row.statusLabel.toUpperCase()} | ${row.priority.toUpperCase()} | $dueText',
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) => _handleAction(action, row),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'toggle',
                                child: Text('Toggle Complete'),
                              ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
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

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 5),
      initialDate: _dueDate ?? now,
    );

    if (picked == null) return;
    setState(() {
      _dueDate = picked;
    });
  }

  Future<void> _saveTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a task title.')));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.saveTask(
        taskId: _editingTaskId,
        userId: _userController.text.trim().isEmpty
            ? null
            : _userController.text.trim(),
        title: title,
        dueDate: _dueDate,
        statusLabel: _isCompleted ? 'completed' : 'pending',
        isCompleted: _isCompleted,
        priority: _priority,
        isActive: _isActive,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Task saved locally.')));
      }

      _clearForm();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save task: $error')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _handleAction(String action, PendingTaskEntry entry) async {
    if (action == 'toggle') {
      await _repository.toggleCompletion(entry);
      return;
    }

    if (action == 'edit') {
      _loadEntry(entry);
      return;
    }

    if (action == 'delete') {
      await _repository.deleteTask(entry);
    }
  }

  void _loadEntry(PendingTaskEntry entry) {
    setState(() {
      _editingTaskId = entry.id;
      _titleController.text = entry.title;
      _userController.text = entry.userId ?? '';
      _dueDate = entry.dueDate;
      _priority = entry.priority;
      _isCompleted = entry.isCompleted;
      _isActive = entry.isActive;
    });
  }

  void _clearForm() {
    setState(() {
      _editingTaskId = null;
      _titleController.clear();
      _userController.clear();
      _dueDate = null;
      _priority = 'medium';
      _isCompleted = false;
      _isActive = true;
    });
  }
}
