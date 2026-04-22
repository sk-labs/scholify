import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../data/student_repository.dart';

class StudentEnrollmentPage extends StatefulWidget {
  const StudentEnrollmentPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<StudentEnrollmentPage> createState() => _StudentEnrollmentPageState();
}

class _StudentEnrollmentPageState extends State<StudentEnrollmentPage> {
  late final StudentRepository _repository;

  final TextEditingController _sessionController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  String? _selectedStudentId;
  String? _editingEnrollmentId;
  String _selectedStatus = 'enrolled';
  DateTime? _enrolledOn;
  DateTime? _leftOn;
  bool _isSaving = false;

  static const List<String> _statusOptions = [
    'enrolled',
    'promoted',
    'transferred',
    'graduated',
    'inactive',
  ];

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
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Enrollment (Offline-First)')),
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
                _buildEnrollmentForm(selectedStudentId),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<List<StudentEnrollmentEntry>>(
                    stream: _repository.watchStudentEnrollments(
                      studentId: selectedStudentId,
                    ),
                    builder: (context, enrollmentSnapshot) {
                      if (enrollmentSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (enrollmentSnapshot.hasError) {
                        return Center(
                          child: Text(
                            'Failed to load enrollments: ${enrollmentSnapshot.error}',
                          ),
                        );
                      }

                      final rows = enrollmentSnapshot.data ?? const [];
                      if (rows.isEmpty) {
                        return const Center(
                          child: Text(
                            'No enrollment records for this student yet.',
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          final enrolledText = row.enrolledOn == null
                              ? '-'
                              : DateFormat(
                                  'dd MMM yyyy',
                                ).format(row.enrolledOn!.toLocal());
                          final leftText = row.leftOn == null
                              ? '-'
                              : DateFormat(
                                  'dd MMM yyyy',
                                ).format(row.leftOn!.toLocal());

                          return Card(
                            child: ListTile(
                              title: Text(
                                '${row.academicSession} - ${row.enrollmentStatus.toUpperCase()}',
                              ),
                              subtitle: Text(
                                'Enrolled: $enrolledText | Left: $leftText${row.remarks == null || row.remarks!.isEmpty ? '' : ' | ${row.remarks}'}',
                              ),
                              trailing: Text(
                                DateFormat(
                                  'dd/MM HH:mm',
                                ).format(row.updatedAt.toLocal()),
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

  Widget _buildEnrollmentForm(String selectedStudentId) {
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
              child: DropdownButtonFormField<String>(
                initialValue: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: _statusOptions
                    .map(
                      (status) => DropdownMenuItem<String>(
                        value: status,
                        child: Text(status.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedStatus = value;
                  });
                },
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickDate(isEnrolledDate: true),
              icon: const Icon(Icons.event),
              label: Text(
                _enrolledOn == null
                    ? 'Enrolled Date'
                    : DateFormat('dd MMM yyyy').format(_enrolledOn!),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickDate(isEnrolledDate: false),
              icon: const Icon(Icons.event_busy),
              label: Text(
                _leftOn == null
                    ? 'Left Date'
                    : DateFormat('dd MMM yyyy').format(_leftOn!),
              ),
            ),
            SizedBox(
              width: 240,
              child: TextField(
                controller: _remarksController,
                decoration: const InputDecoration(
                  labelText: 'Remarks',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _isSaving
                  ? null
                  : () => _saveEnrollment(selectedStudentId),
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving...' : 'Save Enrollment'),
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

  void _startEditing(StudentEnrollmentEntry enrollment) {
    setState(() {
      _editingEnrollmentId = enrollment.id;
      _sessionController.text = enrollment.academicSession;
      _selectedStatus = enrollment.enrollmentStatus;
      _enrolledOn = enrollment.enrolledOn?.toLocal();
      _leftOn = enrollment.leftOn?.toLocal();
      _remarksController.text = enrollment.remarks ?? '';
    });
  }

  void _resetForm() {
    _editingEnrollmentId = null;
    _sessionController.clear();
    _selectedStatus = _statusOptions.first;
    _enrolledOn = null;
    _leftOn = null;
    _remarksController.clear();
  }

  Future<void> _pickDate({required bool isEnrolledDate}) async {
    final now = DateTime.now();
    final initial = isEnrolledDate ? _enrolledOn : _leftOn;

    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
      initialDate: initial ?? now,
    );

    if (picked == null) return;

    setState(() {
      if (isEnrolledDate) {
        _enrolledOn = picked;
      } else {
        _leftOn = picked;
      }
    });
  }

  Future<void> _saveEnrollment(String studentId) async {
    final session = _sessionController.text.trim();
    final remarks = _remarksController.text.trim();

    if (session.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Academic session is required.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.createOrUpdateEnrollment(
        enrollmentId: _editingEnrollmentId,
        studentId: studentId,
        academicSession: session,
        enrollmentStatus: _selectedStatus,
        enrolledOn: _enrolledOn,
        leftOn: _leftOn,
        remarks: remarks.isEmpty ? null : remarks,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _editingEnrollmentId == null
                  ? 'Enrollment saved locally and queued for sync.'
                  : 'Enrollment updated locally and queued for sync.',
            ),
          ),
        );
        setState(_resetForm);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save enrollment: $error')),
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
