import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../../../core/theme/scholify_colors.dart';
import '../../../core/widgets/scholify_empty_state.dart';
import '../data/exam_repository.dart';
import 'exam_analytics_panel.dart';

class ExamOverviewPage extends StatefulWidget {
  const ExamOverviewPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<ExamOverviewPage> createState() => _ExamOverviewPageState();
}

class _ExamOverviewPageState extends State<ExamOverviewPage> {
  late final ExamRepository _repository;

  final TextEditingController _examNameController = TextEditingController();
  final TextEditingController _subjectNameController = TextEditingController();
  final TextEditingController _maxMarksController = TextEditingController(
    text: '100',
  );

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedExamDate = DateTime.now();

  String? _selectedStudentId;
  bool _isSavingSchedule = false;
  String? _markingScheduleId;
  String? _processingScheduleId;
  String? _processingMarkId;
  ExamScheduleEntry? _editingSchedule;

  @override
  void initState() {
    super.initState();
    _repository = ExamRepository(
      database: widget.syncEngine.database,
      syncEngine: widget.syncEngine,
      tenantContext: widget.tenantContext,
    );
  }

  @override
  void dispose() {
    _examNameController.dispose();
    _subjectNameController.dispose();
    _maxMarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPageHeader(context),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<StudentDirectoryEntry>>(
          stream: _repository.watchStudents(),
          builder: (context, studentsSnapshot) {
            if (studentsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (studentsSnapshot.hasError) {
              return Center(
                child: Text(
                  'Failed to load students: ${studentsSnapshot.error}',
                ),
              );
            }

            final students =
                studentsSnapshot.data ?? const <StudentDirectoryEntry>[];
            if (students.isEmpty) {
              return const ScholifyEmptyState(
                icon: Icons.people_outline,
                title: 'No students yet',
                message: 'Add students in the Students tab first.',
                accent: ScholifyColors.accentStudents,
              );
            }

            final selectedStudentId = _resolveSelectedStudentId(students);

            return Column(
              children: [
                _buildToolbar(monthLabel, students, selectedStudentId),
                const SizedBox(height: 12),
                _buildScheduleCreatorCard(),
                const SizedBox(height: 12),
                SizedBox(
                  height: 360,
                  child: ExamAnalyticsPanel(
                    repository: _repository,
                    month: _selectedMonth,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final useVerticalLayout = constraints.maxWidth < 960;

                      if (useVerticalLayout) {
                        return Column(
                          children: [
                            Expanded(
                              child: _buildExamScheduleList(selectedStudentId),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: _buildStudentMarksList(selectedStudentId),
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: _buildExamScheduleList(selectedStudentId),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStudentMarksList(selectedStudentId),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Exams', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          'Schedule exams, record marks, and track performance.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  ShapeBorder _cardShape(BuildContext context) {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant.withValues(
          alpha: 0.6,
        ),
      ),
    );
  }

  Widget _buildToolbar(
    String monthLabel,
    List<StudentDirectoryEntry> students,
    String selectedStudentId,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 320,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Student',
              border: OutlineInputBorder(),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: selectedStudentId,
                items: students
                    .map(
                      (student) => DropdownMenuItem<String>(
                        value: student.id,
                        child: Text(
                          '${student.fullName} (${student.admissionNo})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedStudentId = value;
                  });
                },
              ),
            ),
          ),
        ),
        SizedBox(
          width: 280,
          child: Card(
            margin: EdgeInsets.zero,
            shape: _cardShape(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous Month',
                    onPressed: () {
                      setState(() {
                        _selectedMonth = DateTime(
                          _selectedMonth.year,
                          _selectedMonth.month - 1,
                        );
                      });
                    },
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(monthLabel, textAlign: TextAlign.center),
                  ),
                  IconButton(
                    tooltip: 'Next Month',
                    onPressed: () {
                      setState(() {
                        _selectedMonth = DateTime(
                          _selectedMonth.year,
                          _selectedMonth.month + 1,
                        );
                      });
                    },
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleCreatorCard() {
    final isEditing = _editingSchedule != null;

    return Card(
      shape: _cardShape(context),
      color: ScholifyColors.tint(ScholifyColors.academicNavy, 0.06),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              isEditing ? 'Edit Schedule' : 'Create Schedule',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            SizedBox(
              width: 190,
              child: TextField(
                controller: _examNameController,
                decoration: const InputDecoration(
                  labelText: 'Exam Name',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 190,
              child: TextField(
                controller: _subjectNameController,
                decoration: const InputDecoration(
                  labelText: 'Subject Name',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 150,
              child: TextField(
                controller: _maxMarksController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Max Marks',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _pickExamDate,
              icon: const Icon(Icons.event),
              label: Text(DateFormat('dd MMM yyyy').format(_selectedExamDate)),
            ),
            FilledButton.icon(
              onPressed: _isSavingSchedule ? null : _saveExamSchedule,
              icon: _isSavingSchedule
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(
                _isSavingSchedule
                    ? 'Saving...'
                    : isEditing
                    ? 'Update Schedule'
                    : 'Create Schedule',
              ),
            ),
            if (isEditing)
              OutlinedButton.icon(
                onPressed: _isSavingSchedule
                    ? null
                    : () {
                        setState(_resetScheduleForm);
                      },
                icon: const Icon(Icons.close),
                label: const Text('Cancel Edit'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamScheduleList(String selectedStudentId) {
    return StreamBuilder<List<ExamScheduleEntry>>(
      stream: _repository.watchExamSchedules(month: _selectedMonth),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Failed to load exam schedules: ${snapshot.error}'),
          );
        }

        final schedules = snapshot.data ?? const [];
        if (schedules.isEmpty) {
          return const ScholifyEmptyState(
            icon: Icons.calendar_month,
            title: 'No exam schedules',
            message: 'No exam schedules in this month. Create one above.',
            accent: ScholifyColors.achievementAmber,
          );
        }

        return Card(
          shape: _cardShape(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Exam Schedules',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: schedules.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final row = schedules[index];
                      final dateText = DateFormat(
                        'dd MMM yyyy',
                      ).format(row.examDate.toLocal());
                      final isScheduleBusy =
                          _processingScheduleId == row.id ||
                          _markingScheduleId == row.id;

                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: ScholifyColors.tint(
                              ScholifyColors.academicNavy,
                              0.1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.quiz_outlined,
                            color: ScholifyColors.academicNavy,
                          ),
                        ),
                        title: Text('${row.examName} - ${row.subjectName}'),
                        subtitle: Text(
                          '$dateText | Max: ${row.maxMarks.toStringAsFixed(0)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: isScheduleBusy
                                  ? null
                                  : () => _captureMark(
                                      studentId: selectedStudentId,
                                      schedule: row,
                                    ),
                              icon: _markingScheduleId == row.id
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.edit_note),
                              label: const Text('Set Mark'),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Schedule actions',
                              enabled: !isScheduleBusy,
                              onSelected: (action) {
                                _handleScheduleAction(action, row);
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem<String>(
                                  value: 'edit',
                                  child: Text('Edit Schedule'),
                                ),
                                PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Text('Delete Schedule'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudentMarksList(String selectedStudentId) {
    return StreamBuilder<List<StudentExamMarkView>>(
      stream: _repository.watchStudentMonthMarks(
        studentId: selectedStudentId,
        month: _selectedMonth,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Failed to load marks: ${snapshot.error}'));
        }

        final marks = snapshot.data ?? const [];
        if (marks.isEmpty) {
          return const ScholifyEmptyState(
            icon: Icons.grading_outlined,
            title: 'No marks recorded',
            message: 'No marks recorded for this student in this month.',
            accent: ScholifyColors.scholarTeal,
          );
        }

        final totalObtained = marks.fold<double>(
          0,
          (sum, row) => sum + row.marksObtained,
        );
        final totalMax = marks.fold<double>(
          0,
          (sum, row) => sum + row.maxMarks,
        );
        final percent = totalMax <= 0 ? 0 : (totalObtained / totalMax) * 100;

        return Card(
          shape: _cardShape(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Student Marks'),
                  subtitle: Text(
                    'Total: ${totalObtained.toStringAsFixed(1)} / ${totalMax.toStringAsFixed(1)} (${percent.toStringAsFixed(1)}%)',
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: marks.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final row = marks[index];
                      final dateText = DateFormat(
                        'dd MMM',
                      ).format(row.examDate.toLocal());
                      final isMarkBusy = _processingMarkId == row.markId;

                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: ScholifyColors.tint(
                              ScholifyColors.scholarTeal,
                              0.1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.assignment_outlined,
                            color: ScholifyColors.scholarTeal,
                          ),
                        ),
                        title: Text('${row.examName} - ${row.subjectName}'),
                        subtitle: Text(
                          '$dateText | ${row.marksObtained.toStringAsFixed(1)} / ${row.maxMarks.toStringAsFixed(1)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(row.grade ?? '-'),
                            const SizedBox(width: 8),
                            if (isMarkBusy)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              PopupMenuButton<String>(
                                tooltip: 'Mark actions',
                                onSelected: (action) {
                                  _handleMarkAction(
                                    action,
                                    row,
                                    selectedStudentId,
                                  );
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem<String>(
                                    value: 'edit',
                                    child: Text('Edit Mark'),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Text('Delete Mark'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickExamDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
      initialDate: _selectedExamDate,
    );

    if (picked == null) return;
    setState(() {
      _selectedExamDate = picked;
    });
  }

  Future<void> _saveExamSchedule() async {
    final examName = _examNameController.text.trim();
    final subjectName = _subjectNameController.text.trim();
    final maxMarks = double.tryParse(_maxMarksController.text.trim());

    if (examName.isEmpty || subjectName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exam name and subject are required.')),
      );
      return;
    }

    if (maxMarks == null || maxMarks <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid max marks value.')),
      );
      return;
    }

    setState(() {
      _isSavingSchedule = true;
    });

    final isEditing = _editingSchedule != null;

    try {
      if (!isEditing) {
        await _repository.createExamSchedule(
          examName: examName,
          subjectName: subjectName,
          maxMarks: maxMarks,
          examDate: _selectedExamDate,
        );
      } else {
        await _repository.updateExamSchedule(
          schedule: _editingSchedule!,
          examName: examName,
          subjectName: subjectName,
          maxMarks: maxMarks,
          examDate: _selectedExamDate,
        );
      }

      if (mounted) {
        setState(_resetScheduleForm);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !isEditing
                  ? 'Exam schedule saved locally and queued for sync.'
                  : 'Exam schedule updated locally and queued for sync.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save exam schedule: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingSchedule = false;
        });
      }
    }
  }

  Future<void> _captureMark({
    required String studentId,
    required ExamScheduleEntry schedule,
  }) async {
    final draft = await _promptMarkDraft(
      title: 'Set Mark: ${schedule.examName}',
      maxMarks: schedule.maxMarks,
    );
    if (draft == null) return;

    if (draft.marksObtained < 0 || draft.marksObtained > schedule.maxMarks) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Marks must be between 0 and ${schedule.maxMarks.toStringAsFixed(1)}.',
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _markingScheduleId = schedule.id;
    });

    try {
      await _repository.setStudentMark(
        studentId: studentId,
        schedule: schedule,
        marksObtained: draft.marksObtained,
        grade: draft.grade,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student mark saved locally and queued for sync.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save mark: $error')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _markingScheduleId = null;
        });
      }
    }
  }

  void _resetScheduleForm() {
    _examNameController.clear();
    _subjectNameController.clear();
    _maxMarksController.text = '100';
    _selectedExamDate = DateTime.now();
    _editingSchedule = null;
  }

  void _handleScheduleAction(String action, ExamScheduleEntry schedule) {
    if (action == 'edit') {
      _startScheduleEdit(schedule);
      return;
    }

    if (action == 'delete') {
      _deleteSchedule(schedule);
    }
  }

  void _startScheduleEdit(ExamScheduleEntry schedule) {
    setState(() {
      _editingSchedule = schedule;
      _examNameController.text = schedule.examName;
      _subjectNameController.text = schedule.subjectName;
      _maxMarksController.text = schedule.maxMarks.toStringAsFixed(1);
      _selectedExamDate = schedule.examDate.toLocal();
    });
  }

  Future<void> _deleteSchedule(ExamScheduleEntry schedule) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Exam Schedule'),
          content: Text(
            'Delete ${schedule.examName} - ${schedule.subjectName}? This will remove linked marks.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    setState(() {
      _processingScheduleId = schedule.id;
    });

    try {
      await _repository.deleteExamSchedule(schedule: schedule);
      if (_editingSchedule?.id == schedule.id) {
        setState(_resetScheduleForm);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exam schedule deleted locally and queued for sync.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete schedule: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingScheduleId = null;
        });
      }
    }
  }

  void _handleMarkAction(
    String action,
    StudentExamMarkView mark,
    String studentId,
  ) {
    if (action == 'edit') {
      _editMark(mark, studentId);
      return;
    }

    if (action == 'delete') {
      _deleteMark(mark, studentId);
    }
  }

  Future<void> _editMark(StudentExamMarkView mark, String studentId) async {
    final draft = await _promptMarkDraft(
      title: 'Edit Mark: ${mark.examName}',
      maxMarks: mark.maxMarks,
      initialMarks: mark.marksObtained,
      initialGrade: mark.grade,
    );
    if (draft == null) return;

    if (draft.marksObtained < 0 || draft.marksObtained > mark.maxMarks) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Marks must be between 0 and ${mark.maxMarks.toStringAsFixed(1)}.',
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _processingMarkId = mark.markId;
    });

    try {
      await _repository.upsertStudentMark(
        studentId: studentId,
        scheduleId: mark.scheduleId,
        scheduleMaxMarks: mark.maxMarks,
        marksObtained: draft.marksObtained,
        grade: draft.grade,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student mark updated locally and queued for sync.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update mark: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingMarkId = null;
        });
      }
    }
  }

  Future<void> _deleteMark(StudentExamMarkView mark, String studentId) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Mark'),
          content: Text(
            'Delete mark for ${mark.examName} - ${mark.subjectName}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    setState(() {
      _processingMarkId = mark.markId;
    });

    try {
      await _repository.deleteStudentMark(
        markId: mark.markId,
        scheduleId: mark.scheduleId,
        studentId: studentId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student mark deleted locally and queued for sync.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete mark: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingMarkId = null;
        });
      }
    }
  }

  Future<_MarkDraft?> _promptMarkDraft({
    required String title,
    required double maxMarks,
    double? initialMarks,
    String? initialGrade,
  }) async {
    final marksController = TextEditingController(
      text: initialMarks?.toStringAsFixed(1) ?? '',
    );
    final gradeController = TextEditingController(text: initialGrade ?? '');

    final draft = await showDialog<_MarkDraft>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: marksController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Marks Obtained',
                  helperText: 'Max: ${maxMarks.toStringAsFixed(1)}',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: gradeController,
                decoration: const InputDecoration(
                  labelText: 'Grade (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final marks = double.tryParse(marksController.text.trim());
                if (marks == null) {
                  return;
                }
                Navigator.of(context).pop(
                  _MarkDraft(
                    marksObtained: marks,
                    grade: gradeController.text.trim().isEmpty
                        ? null
                        : gradeController.text.trim(),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    marksController.dispose();
    gradeController.dispose();
    return draft;
  }

  String _resolveSelectedStudentId(List<StudentDirectoryEntry> students) {
    final activeId = _selectedStudentId;
    if (activeId != null && students.any((student) => student.id == activeId)) {
      return activeId;
    }

    final fallback = students.first.id;
    if (activeId != fallback) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedStudentId = fallback;
        });
      });
    }

    return fallback;
  }
}

class _MarkDraft {
  const _MarkDraft({required this.marksObtained, required this.grade});

  final double marksObtained;
  final String? grade;
}
