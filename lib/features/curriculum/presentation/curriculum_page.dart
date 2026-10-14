import 'package:flutter/material.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../../../core/theme/scholify_colors.dart';
import '../../../core/widgets/scholify_empty_state.dart';
import '../data/curriculum_repository.dart';

class CurriculumPage extends StatefulWidget {
  const CurriculumPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<CurriculumPage> createState() => _CurriculumPageState();
}

class _CurriculumPageState extends State<CurriculumPage> {
  late final CurriculumRepository _repository;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _classController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _metaOneController = TextEditingController();
  final TextEditingController _metaTwoController = TextEditingController();
  final TextEditingController _metaThreeController = TextEditingController();

  String _selectedType = _CurriculumType.lesson;
  String? _selectedTemplateId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _repository = CurriculumRepository(
      database: widget.syncEngine.database,
      syncEngine: widget.syncEngine,
      tenantContext: widget.tenantContext,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _classController.dispose();
    _subjectController.dispose();
    _metaOneController.dispose();
    _metaTwoController.dispose();
    _metaThreeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildPageHeader(context),
            const SizedBox(height: 16),
            _buildTypeSelector(),
            const SizedBox(height: 12),
            _buildAnalyticsBanner(),
            const SizedBox(height: 12),
            _buildComposerCard(),
            const SizedBox(height: 12),
            Expanded(child: _buildTypeList()),
          ],
        ),
      ),
    );
  }

  /// In-page header (the shell already provides the top AppBar).
  Widget _buildPageHeader(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Curriculum Management',
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Plan lessons, structure subjects, and track syllabus progress.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// Shared card shape: 16px radius with a subtle outline border.
  ShapeBorder _cardShape(BuildContext context) {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color:
            Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
      ),
    );
  }

  /// Tinted icon medallion in a palette color.
  Widget _buildIconMedallion(IconData icon, Color color) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: ScholifyColors.tint(color, 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _buildTypeSelector() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final type in _CurriculumType.all)
            ChoiceChip(
              label: Text(_labelForType(type)),
              selected: _selectedType == type,
              onSelected: (_) {
                setState(() {
                  _selectedType = type;
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildComposerCard() {
    final theme = Theme.of(context);
    final metaOneLabel = _metaOneLabel();
    final metaTwoLabel = _metaTwoLabel();
    final metaThreeLabel = _metaThreeLabel();

    return Card(
      shape: _cardShape(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add ${_labelForType(_selectedType)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
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
                  width: 210,
                  child: TextField(
                    controller: _classController,
                    decoration: const InputDecoration(
                      labelText: 'Class / Section',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 210,
                  child: TextField(
                    controller: _subjectController,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 210,
                  child: TextField(
                    controller: _metaOneController,
                    decoration: InputDecoration(
                      labelText: metaOneLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 210,
                  child: TextField(
                    controller: _metaTwoController,
                    decoration: InputDecoration(
                      labelText: metaTwoLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 210,
                  child: TextField(
                    controller: _metaThreeController,
                    decoration: InputDecoration(
                      labelText: metaThreeLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            if (_selectedType == _CurriculumType.lessonPlan) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _selectedTemplateId,
                decoration: const InputDecoration(
                  labelText: 'Lesson Plan Template',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Custom'),
                  ),
                  for (final template
                      in CurriculumRepository.lessonPlanTemplates)
                    DropdownMenuItem<String>(
                      value: template.templateId,
                      child: Text(template.title),
                    ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedTemplateId = value;
                  });
                  _applyTemplate(value);
                },
              ),
            ],
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveCurrentType,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(_isSaving ? 'Saving...' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeList() {
    switch (_selectedType) {
      case _CurriculumType.lesson:
        return StreamBuilder<List<LessonEntry>>(
          stream: _repository.watchLessons(),
          builder: (context, snapshot) => _buildLessonList(snapshot),
        );
      case _CurriculumType.lessonPlan:
        return StreamBuilder<List<LessonPlanEntry>>(
          stream: _repository.watchLessonPlans(),
          builder: (context, snapshot) => _buildLessonPlanList(snapshot),
        );
      case _CurriculumType.subject:
        return StreamBuilder<List<SubjectEntry>>(
          stream: _repository.watchSubjects(),
          builder: (context, snapshot) => _buildSubjectList(snapshot),
        );
      case _CurriculumType.syllabus:
        return StreamBuilder<List<SyllabusEntry>>(
          stream: _repository.watchSyllabusItems(),
          builder: (context, snapshot) => _buildSyllabusList(snapshot),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildLessonList(AsyncSnapshot<List<LessonEntry>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return Center(child: Text('Failed to load lessons: ${snapshot.error}'));
    }

    final rows = snapshot.data ?? const <LessonEntry>[];
    if (rows.isEmpty) {
      return const ScholifyEmptyState(
        icon: Icons.menu_book_outlined,
        title: 'No lessons yet',
        message: 'Add your first lesson above to start building the curriculum.',
        accent: ScholifyColors.academicNavy,
      );
    }

    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final row = rows[index];
        final attachments = _attachmentList(row.attachmentUrl);
        final subtitle =
            '${row.classSection ?? 'Class TBD'} | ${row.subjectName ?? 'Subject TBD'}\n${row.topicName ?? 'Topic TBD'} | Attachments: ${attachments.length}';
        return _buildTile(
          title: row.title,
          subtitle: subtitle,
          leadingAction: IconButton(
            tooltip: 'Upload attachment URL',
            icon: const Icon(Icons.attach_file),
            onPressed: _isSaving ? null : () => _uploadAttachment(row),
          ),
          onDelete: () => _deleteLesson(row),
        );
      },
    );
  }

  Widget _buildLessonPlanList(AsyncSnapshot<List<LessonPlanEntry>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return Center(
        child: Text('Failed to load lesson plans: ${snapshot.error}'),
      );
    }

    final rows = snapshot.data ?? const <LessonPlanEntry>[];
    if (rows.isEmpty) {
      return const ScholifyEmptyState(
        icon: Icons.event_note_outlined,
        title: 'No lesson plans yet',
        message: 'Create a lesson plan above or start from a template.',
        accent: ScholifyColors.academicNavy,
      );
    }

    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final row = rows[index];
        final subtitle =
            '${row.classSection ?? 'Class TBD'} | ${row.subjectName ?? 'Subject TBD'}\n${row.objective ?? 'Objective TBD'}';
        return _buildTile(
          title: row.title,
          subtitle: subtitle,
          onDelete: () => _deleteLessonPlan(row),
        );
      },
    );
  }

  Widget _buildSubjectList(AsyncSnapshot<List<SubjectEntry>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return Center(child: Text('Failed to load subjects: ${snapshot.error}'));
    }

    final rows = snapshot.data ?? const <SubjectEntry>[];
    if (rows.isEmpty) {
      return const ScholifyEmptyState(
        icon: Icons.library_books_outlined,
        title: 'No subjects yet',
        message: 'Add subjects above to organize classes and teachers.',
        accent: ScholifyColors.academicNavy,
      );
    }

    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final row = rows[index];
        final subtitle =
            '${row.subjectCode ?? 'Code TBD'} | ${row.subjectType}\n${row.classSection ?? 'Class TBD'} | ${row.teacherName ?? 'Teacher TBD'}';
        return _buildTile(
          title: row.subjectName,
          subtitle: subtitle,
          onDelete: () => _deleteSubject(row),
        );
      },
    );
  }

  Widget _buildSyllabusList(AsyncSnapshot<List<SyllabusEntry>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return Center(
        child: Text('Failed to load syllabus items: ${snapshot.error}'),
      );
    }

    final rows = snapshot.data ?? const <SyllabusEntry>[];
    if (rows.isEmpty) {
      return const ScholifyEmptyState(
        icon: Icons.checklist_outlined,
        title: 'No syllabus items yet',
        message: 'Add syllabus items above and track their completion here.',
        accent: ScholifyColors.scholarTeal,
      );
    }

    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final row = rows[index];
        final subtitle =
            '${row.classSection ?? 'Class TBD'} | ${row.subjectName ?? 'Subject TBD'}\n${row.statusLabel} | ${row.completionPercent ?? '0%'}';
        return _buildTile(
          title: row.title,
          subtitle: subtitle,
          onDelete: () => _deleteSyllabus(row),
        );
      },
    );
  }

  Widget _buildTile({
    required String title,
    required String subtitle,
    required Future<void> Function() onDelete,
    Widget? leadingAction,
  }) {
    return Card(
      shape: _cardShape(context),
      child: ListTile(
        leading: leadingAction,
        title: Text(title),
        subtitle: Text(subtitle),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: 'Delete item',
          icon: const Icon(Icons.delete_outline),
          onPressed: _isSaving ? null : onDelete,
        ),
      ),
    );
  }

  Future<void> _saveCurrentType() async {
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
      switch (_selectedType) {
        case _CurriculumType.lesson:
          await _repository.saveLesson(
            title: title,
            classSection: _emptyToNull(_classController.text),
            subjectName: _emptyToNull(_subjectController.text),
            topicName: _emptyToNull(_metaOneController.text),
            lessonDateLabel: _emptyToNull(_metaTwoController.text),
            attachmentUrl: _emptyToNull(_metaThreeController.text),
          );
          break;
        case _CurriculumType.lessonPlan:
          await _repository.saveLessonPlan(
            title: title,
            classSection: _emptyToNull(_classController.text),
            subjectName: _emptyToNull(_subjectController.text),
            objective: _emptyToNull(_metaOneController.text),
            periodLabel: _emptyToNull(_metaTwoController.text),
            activities: _emptyToNull(_metaThreeController.text),
          );
          break;
        case _CurriculumType.subject:
          await _repository.saveSubject(
            subjectName: title,
            classSection: _emptyToNull(_classController.text),
            teacherName: _emptyToNull(_subjectController.text),
            subjectCode: _emptyToNull(_metaOneController.text),
            subjectType: _emptyToNull(_metaTwoController.text) ?? 'theory',
          );
          break;
        case _CurriculumType.syllabus:
          await _repository.saveSyllabus(
            title: title,
            classSection: _emptyToNull(_classController.text),
            subjectName: _emptyToNull(_subjectController.text),
            statusLabel: _emptyToNull(_metaOneController.text) ?? 'pending',
            completionPercent: _emptyToNull(_metaTwoController.text),
            notes: _emptyToNull(_metaThreeController.text),
          );
          break;
      }

      _titleController.clear();
      _classController.clear();
      _subjectController.clear();
      _metaOneController.clear();
      _metaTwoController.clear();
      _metaThreeController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_labelForType(_selectedType)} saved for sync.'),
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

  Widget _buildAnalyticsBanner() {
    return StreamBuilder<SyllabusProgressAnalytics>(
      stream: _repository.watchSyllabusProgressAnalytics(),
      builder: (context, snapshot) {
        final analytics = snapshot.data;
        if (analytics == null || analytics.totalItems == 0) {
          return const SizedBox.shrink();
        }

        return Card(
          shape: _cardShape(context),
          color: ScholifyColors.tint(ScholifyColors.scholarTeal, 0.08),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildIconMedallion(
                      Icons.track_changes_outlined,
                      ScholifyColors.scholarTeal,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Syllabus Progress',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Text('Syllabus Items: ${analytics.totalItems}'),
                    Text('Completed: ${analytics.completedItems}'),
                    Text('In Progress: ${analytics.inProgressItems}'),
                    Text(
                      'Avg Completion: ${analytics.averageCompletionPercent.toStringAsFixed(1)}%',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _applyTemplate(String? templateId) {
    if (templateId == null || templateId.isEmpty) {
      return;
    }

    LessonPlanTemplate? template;
    for (final item in CurriculumRepository.lessonPlanTemplates) {
      if (item.templateId == templateId) {
        template = item;
        break;
      }
    }
    if (template == null) return;

    _titleController.text = template.title;
    _metaOneController.text = template.objective;
    _metaTwoController.text = template.periodLabel;
    _metaThreeController.text = template.activities;
  }

  Future<void> _uploadAttachment(LessonEntry row) async {
    final controller = TextEditingController();
    final submitted = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload Attachment URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Attachment URL',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (submitted == null || submitted.isEmpty) return;

    setState(() {
      _isSaving = true;
    });
    try {
      await _repository.attachLessonResource(
        lesson: row,
        attachmentUrl: submitted,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attachment queued for upload sync.')),
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

  List<String> _attachmentList(String? csv) {
    if (csv == null || csv.trim().isEmpty) return const <String>[];
    return csv
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<void> _deleteLesson(LessonEntry row) async {
    await _runDelete(() => _repository.deleteLesson(row));
  }

  Future<void> _deleteLessonPlan(LessonPlanEntry row) async {
    await _runDelete(() => _repository.deleteLessonPlan(row));
  }

  Future<void> _deleteSubject(SubjectEntry row) async {
    await _runDelete(() => _repository.deleteSubject(row));
  }

  Future<void> _deleteSyllabus(SyllabusEntry row) async {
    await _runDelete(() => _repository.deleteSyllabus(row));
  }

  Future<void> _runDelete(Future<void> Function() action) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item deleted and queued for sync.')),
        );
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

  String _metaOneLabel() {
    switch (_selectedType) {
      case _CurriculumType.lesson:
        return 'Topic';
      case _CurriculumType.lessonPlan:
        return 'Objective';
      case _CurriculumType.subject:
        return 'Subject Code';
      case _CurriculumType.syllabus:
        return 'Status';
    }
    return 'Meta 1';
  }

  String _metaTwoLabel() {
    switch (_selectedType) {
      case _CurriculumType.lesson:
        return 'Lesson Date Label';
      case _CurriculumType.lessonPlan:
        return 'Period Label';
      case _CurriculumType.subject:
        return 'Subject Type';
      case _CurriculumType.syllabus:
        return 'Completion %';
    }
    return 'Meta 2';
  }

  String _metaThreeLabel() {
    switch (_selectedType) {
      case _CurriculumType.lesson:
        return 'Attachment URL';
      case _CurriculumType.lessonPlan:
        return 'Activities';
      case _CurriculumType.subject:
        return 'Optional';
      case _CurriculumType.syllabus:
        return 'Notes';
    }
    return 'Meta 3';
  }

  String _labelForType(String type) {
    switch (type) {
      case _CurriculumType.lesson:
        return 'Lessons';
      case _CurriculumType.lessonPlan:
        return 'Lesson Plans';
      case _CurriculumType.subject:
        return 'Subjects';
      case _CurriculumType.syllabus:
        return 'Syllabus';
      default:
        return type;
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }
}

class _CurriculumType {
  static const String lesson = 'lesson';
  static const String lessonPlan = 'lesson_plan';
  static const String subject = 'subject';
  static const String syllabus = 'syllabus';

  static const List<String> all = [lesson, lessonPlan, subject, syllabus];
}
