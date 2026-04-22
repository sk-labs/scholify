import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../data/attendance_repository.dart';

class AttendanceOverviewPage extends StatefulWidget {
  const AttendanceOverviewPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<AttendanceOverviewPage> createState() => _AttendanceOverviewPageState();
}

class _AttendanceOverviewPageState extends State<AttendanceOverviewPage> {
  late final AttendanceRepository _repository;

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String? _selectedStudentId;
  String _selectedStatus = 'present';
  bool _isSaving = false;

  static const List<String> _statusOptions = [
    'present',
    'absent',
    'late',
    'half_day',
  ];

  @override
  void initState() {
    super.initState();
    _repository = AttendanceRepository(
      database: widget.syncEngine.database,
      syncEngine: widget.syncEngine,
      tenantContext: widget.tenantContext,
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance (Offline-First)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
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

            final students = snapshot.data ?? const <StudentDirectoryEntry>[];
            if (students.isEmpty) {
              return const Center(
                child: Text(
                  'No students found. Add students in the Students tab or sync from server.',
                ),
              );
            }

            final selectedStudentId = _resolveSelectedStudentId(students);

            return Column(
              children: [
                _buildToolbar(monthLabel, students, selectedStudentId),
                const SizedBox(height: 12),
                _buildMarkCard(selectedStudentId),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder(
                    stream: _repository.watchStudentMonth(
                      studentId: selectedStudentId,
                      month: _selectedMonth,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Failed to load attendance: ${snapshot.error}',
                          ),
                        );
                      }

                      final records = snapshot.data ?? const [];
                      if (records.isEmpty) {
                        return const Center(
                          child: Text('No attendance records for this month.'),
                        );
                      }

                      return ListView.separated(
                        itemCount: records.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final row = records[index];
                          final dateText = DateFormat(
                            'dd MMM yyyy',
                          ).format(row.attendanceDate.toLocal());

                          return Card(
                            child: ListTile(
                              title: Text(dateText),
                              subtitle: Text(
                                'Status: ${row.status.toUpperCase()} | Source: ${row.source}',
                              ),
                              trailing: Text(
                                DateFormat(
                                  'HH:mm',
                                ).format(row.updatedAt.toLocal()),
                              ),
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

  Widget _buildToolbar(
    String monthLabel,
    List<StudentDirectoryEntry> students,
    String selectedStudentId,
  ) {
    return Row(
      children: [
        Expanded(
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
        const SizedBox(width: 12),
        SizedBox(
          width: 220,
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
              Expanded(child: Text(monthLabel, textAlign: TextAlign.center)),
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
      ],
    );
  }

  Widget _buildMarkCard(String selectedStudentId) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Mark Today:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: _selectedStatus,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _statusOptions
                    .map(
                      (status) => DropdownMenuItem(
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
            ElevatedButton.icon(
              onPressed: _isSaving ? null : () => _markToday(selectedStudentId),
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_isSaving ? 'Saving...' : 'Save'),
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
        });
      });
    }

    return fallback;
  }

  Future<void> _markToday(String studentId) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.markAttendance(
        studentId: studentId,
        attendanceDate: DateTime.now(),
        status: _selectedStatus,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance saved locally and queued for sync.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save attendance: $error')),
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
