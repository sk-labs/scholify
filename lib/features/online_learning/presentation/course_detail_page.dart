import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../data/online_lesson_repository.dart';
import '../data/online_learning_repository.dart';

class CourseDetailPage extends StatefulWidget {
  const CourseDetailPage({
    super.key,
    required this.course,
    required this.tenantContext,
    required this.syncEngine,
  });

  final OnlineLearningEntry course;
  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  late final OnlineLessonRepository _lessonRepo;

  final _titleController = TextEditingController();
  final _urlController = TextEditingController();
  final _descController = TextEditingController();
  String _contentType = 'video';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _lessonRepo = OnlineLessonRepository(
      database: widget.syncEngine.database,
      syncEngine: widget.syncEngine,
      tenantContext: widget.tenantContext,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;

    return Scaffold(
      appBar: AppBar(title: Text(course.title)),
      body: Column(
        children: [
          // Course info header
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        course.itemType == OnlineLearningRepository.quizType
                            ? Icons.quiz_outlined
                            : Icons.video_library_outlined,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              course.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (course.instructorName?.isNotEmpty == true)
                              Text(
                                course.instructorName!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (course.summary?.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text(course.summary!),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (course.durationLabel?.isNotEmpty == true)
                        _chip(Icons.timer_outlined, course.durationLabel!),
                      _chip(Icons.lock_outline, course.accessLevel),
                      if (course.priceAmount > 0)
                        _chip(
                          Icons.attach_money,
                          course.priceAmount.toStringAsFixed(2),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Add lesson form
          _buildAddLessonCard(),
          // Lesson list
          Expanded(
            child: StreamBuilder<List<OnlineLessonEntry>>(
              stream: _lessonRepo.watchLessons(itemId: course.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final lessons =
                    snapshot.data ?? const <OnlineLessonEntry>[];
                if (lessons.isEmpty) {
                  return const Center(
                    child: Text('No lessons yet. Add one above.'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: lessons.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _buildLessonTile(lessons[index], index + 1),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddLessonCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Lesson',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Lesson title',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'Content URL',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 130,
                  child: DropdownButtonFormField<String>(
                    initialValue: _contentType,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'video', child: Text('Video')),
                      DropdownMenuItem(value: 'pdf', child: Text('PDF')),
                      DropdownMenuItem(value: 'text', child: Text('Text')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _contentType = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _saveLesson,
                icon: _isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonTile(OnlineLessonEntry lesson, int index) {
    final icon = switch (lesson.contentType) {
      'pdf' => Icons.picture_as_pdf_outlined,
      'text' => Icons.article_outlined,
      _ => Icons.play_circle_outline,
    };

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: lesson.isCompleted
              ? Colors.green.withValues(alpha: 0.15)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: lesson.isCompleted
              ? const Icon(Icons.check, color: Colors.green, size: 18)
              : Text('$index'),
        ),
        title: Text(lesson.title),
        subtitle: lesson.description?.isNotEmpty == true
            ? Text(
                lesson.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lesson.contentUrl?.isNotEmpty == true)
              IconButton(
                tooltip: 'Open content',
                icon: Icon(icon, size: 20),
                onPressed: () => _openContent(lesson.contentUrl!),
              ),
            PopupMenuButton<String>(
              onSelected: (action) => _handleLessonAction(action, lesson),
              itemBuilder: (context) => [
                if (!lesson.isCompleted)
                  const PopupMenuItem(
                    value: 'complete',
                    child: Text('Mark complete'),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveLesson() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _lessonRepo.saveLesson(
        itemId: widget.course.id,
        title: title,
        contentType: _contentType,
        contentUrl: _urlController.text.trim().isEmpty
            ? null
            : _urlController.text.trim(),
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
      );
      _titleController.clear();
      _urlController.clear();
      _descController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lesson saved and queued.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleLessonAction(
    String action,
    OnlineLessonEntry lesson,
  ) async {
    if (action == 'complete') {
      await _lessonRepo.markCompleted(lesson);
    } else if (action == 'delete') {
      await _lessonRepo.deleteLesson(lesson);
    }
  }

  Future<void> _openContent(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _chip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
