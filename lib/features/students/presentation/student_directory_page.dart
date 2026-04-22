import 'package:flutter/material.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../data/student_repository.dart';

class StudentDirectoryPage extends StatefulWidget {
  const StudentDirectoryPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<StudentDirectoryPage> createState() => _StudentDirectoryPageState();
}

class _StudentDirectoryPageState extends State<StudentDirectoryPage> {
  late final StudentRepository _repository;

  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _admissionNoController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _classSectionController = TextEditingController();

  String? _editingStudentId;
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
    _studentIdController.dispose();
    _admissionNoController.dispose();
    _fullNameController.dispose();
    _classSectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Students (Offline-First)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildFormCard(),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<StudentDirectoryEntry>>(
                stream: _repository.watchStudents(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Failed to load students: ${snapshot.error}'),
                    );
                  }

                  final students =
                      snapshot.data ?? const <StudentDirectoryEntry>[];
                  if (students.isEmpty) {
                    return const Center(
                      child: Text(
                        'No students yet. Create one and it will sync when online.',
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: students.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final student = students[index];
                      final subtitle =
                          student.classSection == null ||
                              student.classSection!.trim().isEmpty
                          ? 'Admission: ${student.admissionNo}'
                          : 'Admission: ${student.admissionNo} | Class: ${student.classSection}';

                      return Card(
                        child: ListTile(
                          title: Text(student.fullName),
                          subtitle: Text(subtitle),
                          trailing: Text(student.id),
                          onTap: () => _startEditing(student),
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

  Widget _buildFormCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 180,
              child: TextField(
                controller: _studentIdController,
                readOnly: _editingStudentId != null,
                decoration: const InputDecoration(
                  labelText: 'Student ID',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 200,
              child: TextField(
                controller: _admissionNoController,
                decoration: const InputDecoration(
                  labelText: 'Admission No',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 240,
              child: TextField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 200,
              child: TextField(
                controller: _classSectionController,
                decoration: const InputDecoration(
                  labelText: 'Class / Section',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveStudent,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving...' : 'Save'),
            ),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _resetForm,
              icon: const Icon(Icons.add),
              label: const Text('New'),
            ),
          ],
        ),
      ),
    );
  }

  void _startEditing(StudentDirectoryEntry student) {
    setState(() {
      _editingStudentId = student.id;
      _studentIdController.text = student.id;
      _admissionNoController.text = student.admissionNo;
      _fullNameController.text = student.fullName;
      _classSectionController.text = student.classSection ?? '';
    });
  }

  void _resetForm() {
    setState(() {
      _editingStudentId = null;
      _studentIdController.clear();
      _admissionNoController.clear();
      _fullNameController.clear();
      _classSectionController.clear();
    });
  }

  Future<void> _saveStudent() async {
    final studentId = _studentIdController.text.trim();
    final admissionNo = _admissionNoController.text.trim();
    final fullName = _fullNameController.text.trim();
    final classSection = _classSectionController.text.trim();

    if (studentId.isEmpty || admissionNo.isEmpty || fullName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Student ID, Admission No, and Full Name are required.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.createOrUpdateStudent(
        studentId: studentId,
        admissionNo: admissionNo,
        fullName: fullName,
        classSection: classSection.isEmpty ? null : classSection,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student saved locally and queued for sync.'),
          ),
        );
      }

      _resetForm();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save student: $error')),
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
