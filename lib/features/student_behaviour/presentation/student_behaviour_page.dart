import 'package:flutter/material.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../data/student_behaviour_repository.dart';

class StudentBehaviourPage extends StatefulWidget {
  const StudentBehaviourPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<StudentBehaviourPage> createState() => _StudentBehaviourPageState();
}

class _StudentBehaviourPageState extends State<StudentBehaviourPage> {
  late final StudentBehaviourRepository _repository;

  // For a school-admin view we show all students; for now use a simple
  // student-id text field as the selector (same pattern as other pages).
  final _studentIdController = TextEditingController();
  String _activeStudentId = '';

  @override
  void initState() {
    super.initState();
    _repository = StudentBehaviourRepository(
      database: widget.syncEngine.database,
      syncEngine: widget.syncEngine,
      tenantContext: widget.tenantContext,
    );
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Behaviour')),
      body: Column(
        children: [
          _buildStudentSelector(),
          if (_activeStudentId.isNotEmpty)
            Expanded(child: _buildIncidentList()),
        ],
      ),
    );
  }

  Widget _buildStudentSelector() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _studentIdController,
              decoration: const InputDecoration(
                labelText: 'Student ID',
                border: OutlineInputBorder(),
                hintText: 'Enter student ID to view behaviour',
              ),
              onSubmitted: (_) => _applyStudentId(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _applyStudentId,
            child: const Text('View'),
          ),
        ],
      ),
    );
  }

  void _applyStudentId() {
    final id = _studentIdController.text.trim();
    if (id.isEmpty) return;
    setState(() => _activeStudentId = id);
  }

  Widget _buildIncidentList() {
    return StreamBuilder<List<StudentBehaviourEntry>>(
      stream: _repository.watchBehaviour(studentId: _activeStudentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final rows = snapshot.data ?? const <StudentBehaviourEntry>[];
        if (rows.isEmpty) {
          return const Center(
            child: Text('No behaviour records for this student.'),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _buildIncidentCard(rows[index]),
        );
      },
    );
  }

  Widget _buildIncidentCard(StudentBehaviourEntry incident) {
    final isPositive = incident.isPositive;
    final pointColor = isPositive ? Colors.green : Colors.red;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isPositive
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    incident.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: pointColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${isPositive ? '+' : ''}${incident.point} pts',
                    style: TextStyle(
                      color: pointColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
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
                if (incident.description?.isNotEmpty == true)
                  Text(incident.description!),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (incident.incidentDate?.isNotEmpty == true) ...[
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        incident.incidentDate!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 16),
                    ],
                    if (incident.assignedBy?.isNotEmpty == true) ...[
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        incident.assignedBy!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _showComments(incident),
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: Text(
                    'Comments (${incident.commentCount})',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showComments(StudentBehaviourEntry incident) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _CommentsSheet(
        incident: incident,
        repository: _repository,
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({
    required this.incident,
    required this.repository,
  });

  final StudentBehaviourEntry incident;
  final StudentBehaviourRepository repository;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _commentController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Comments — ${widget.incident.title}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<List<BehaviourCommentEntry>>(
                  stream: widget.repository.watchComments(
                    incidentId: widget.incident.id,
                  ),
                  builder: (context, snapshot) {
                    final comments =
                        snapshot.data ?? const <BehaviourCommentEntry>[];
                    if (comments.isEmpty) {
                      return const Center(
                        child: Text('No comments yet.'),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      itemCount: comments.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final c = comments[index];
                        return ListTile(
                          dense: true,
                          title: Text(c.commentText),
                          subtitle: Text(
                            [
                              if (c.commentedBy?.isNotEmpty == true)
                                c.commentedBy!,
                              if (c.commentDate?.isNotEmpty == true)
                                c.commentDate!,
                            ].join(' · '),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () =>
                                widget.repository.deleteComment(c),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isSaving ? null : _submitComment,
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Post'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await widget.repository.addComment(
        incidentId: widget.incident.id,
        commentText: text,
      );
      _commentController.clear();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
