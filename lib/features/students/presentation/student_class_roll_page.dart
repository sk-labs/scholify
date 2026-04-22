import 'package:flutter/material.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../data/student_repository.dart';

class StudentClassRollPage extends StatefulWidget {
  const StudentClassRollPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<StudentClassRollPage> createState() => _StudentClassRollPageState();
}

class _StudentClassRollPageState extends State<StudentClassRollPage> {
  late final StudentRepository _repository;

  final TextEditingController _sessionController = TextEditingController();
  final TextEditingController _classNameController = TextEditingController();
  final TextEditingController _sectionNameController = TextEditingController();
  final TextEditingController _rollNoController = TextEditingController();

  String? _selectedStudentId;
  String? _editingClassRollId;
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _repository = StudentRepository(
      database: widget.syncEngine.database,
      syncEngine: widget.syncEngine,
      tenantContext: widget.tenantContext,
    );
  }

  @override
  void dispose() {
    _sessionController.dispose();
    _classNameController.dispose();
    _sectionNameController.dispose();
    _rollNoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Class Roll (Offline-First)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
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
              return const Center(
                child: Text(
                  'No students found. Add students in Students tab first.',
                ),
              );
            }

            final selectedStudentId = _resolveSelectedStudentId(students);

            return Column(
              children: [
                _buildStudentSelector(students, selectedStudentId),
                const SizedBox(height: 12),
                _buildClassRollForm(selectedStudentId),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<List<StudentClassRollEntry>>(
                    stream: _repository.watchStudentClassRolls(
                      studentId: selectedStudentId,
                    ),
                    builder: (context, classRollSnapshot) {
                      if (classRollSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (classRollSnapshot.hasError) {
                        return Center(
                          child: Text(
                            'Failed to load class rolls: ${classRollSnapshot.error}',
                          ),
                        );
                      }

                      final rows = classRollSnapshot.data ?? const [];
                      if (rows.isEmpty) {
                        return const Center(
                          child: Text(
                            'No class roll records for this student yet.',
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          final classLabel =
                              row.sectionName == null ||
                                  row.sectionName!.isEmpty
                              ? row.className
                              : '${row.className} - ${row.sectionName}';

                          return Card(
                            child: ListTile(
                              title: Text(
                                '${row.academicSession} | $classLabel',
                              ),
                              subtitle: Text(
                                row.rollNo == null || row.rollNo!.isEmpty
                                    ? 'Roll: -'
                                    : 'Roll: ${row.rollNo}',
                              ),
                              trailing: Chip(
                                label: Text(
                                  row.isActive ? 'ACTIVE' : 'INACTIVE',
                                ),
                              ),
                              onTap: () => _startEditing(row),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStudentSelector(
    List<StudentDirectoryEntry> students,
    String selectedStudentId,
  ) {
    return InputDecorator(
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
              _resetForm();
            });
          },
        ),
      ),
    );
  }

  Widget _buildClassRollForm(String selectedStudentId) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 170,
              child: TextField(
                controller: _sessionController,
                decoration: const InputDecoration(
                  labelText: 'Academic Session',
                  hintText: '2026-2027',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 170,
              child: TextField(
                controller: _classNameController,
                decoration: const InputDecoration(
                  labelText: 'Class',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 170,
              child: TextField(
                controller: _sectionNameController,
                decoration: const InputDecoration(
                  labelText: 'Section',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _rollNoController,
                decoration: const InputDecoration(
                  labelText: 'Roll No',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 170,
              child: CheckboxListTile(
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value ?? true;
                  });
                },
                title: const Text('Active'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
            FilledButton.icon(
              onPressed: _isSaving
                  ? null
                  : () => _saveClassRoll(selectedStudentId),
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving...' : 'Save Class Roll'),
            ),
            OutlinedButton.icon(
              onPressed: _isSaving
                  ? null
                  : () {
                      setState(_resetForm);
                    },
              icon: const Icon(Icons.refresh),
              label: const Text('Reset'),
            ),
          ],
        ),
      ),
    );
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
          _resetForm();
        });
      });
    }

    return fallback;
  }

  void _startEditing(StudentClassRollEntry row) {
    setState(() {
      _editingClassRollId = row.id;
      _sessionController.text = row.academicSession;
      _classNameController.text = row.className;
      _sectionNameController.text = row.sectionName ?? '';
      _rollNoController.text = row.rollNo ?? '';
      _isActive = row.isActive;
    });
  }

  void _resetForm() {
    _editingClassRollId = null;
    _sessionController.clear();
    _classNameController.clear();
    _sectionNameController.clear();
    _rollNoController.clear();
    _isActive = true;
  }

  Future<void> _saveClassRoll(String studentId) async {
    final academicSession = _sessionController.text.trim();
    final className = _classNameController.text.trim();
    final sectionName = _sectionNameController.text.trim();
    final rollNo = _rollNoController.text.trim();

    if (academicSession.isEmpty || className.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Academic session and class are required.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.createOrUpdateClassRoll(
        classRollId: _editingClassRollId,
        studentId: studentId,
        academicSession: academicSession,
        className: className,
        sectionName: sectionName.isEmpty ? null : sectionName,
        rollNo: rollNo.isEmpty ? null : rollNo,
        isActive: _isActive,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _editingClassRollId == null
                  ? 'Class roll saved locally and queued for sync.'
                  : 'Class roll updated locally and queued for sync.',
            ),
          ),
        );
        setState(_resetForm);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save class roll: $error')),
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
}
