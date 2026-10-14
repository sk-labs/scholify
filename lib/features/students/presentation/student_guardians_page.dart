import 'package:flutter/material.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../../../core/theme/scholify_colors.dart';
import '../../../core/widgets/scholify_empty_state.dart';
import '../data/student_repository.dart';

class StudentGuardiansPage extends StatefulWidget {
  const StudentGuardiansPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<StudentGuardiansPage> createState() => _StudentGuardiansPageState();
}

class _StudentGuardiansPageState extends State<StudentGuardiansPage> {
  late final StudentRepository _repository;

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _relationController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  String? _selectedStudentId;
  String? _editingGuardianId;
  bool _isPrimary = false;
  bool _isSaving = false;
  String? _processingGuardianId;

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
    _fullNameController.dispose();
    _relationController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No page-level AppBar: the shell provides the top bar.
      body: Padding(
        padding: const EdgeInsets.all(20),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Guardians', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  'Link guardians to students and manage contact details.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStudentSelector(students, selectedStudentId),
                const SizedBox(height: 12),
                _buildGuardianForm(selectedStudentId),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<List<StudentGuardianEntry>>(
                    stream: _repository.watchStudentGuardians(
                      studentId: selectedStudentId,
                    ),
                    builder: (context, guardiansSnapshot) {
                      if (guardiansSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (guardiansSnapshot.hasError) {
                        return Center(
                          child: Text(
                            'Failed to load guardians: ${guardiansSnapshot.error}',
                          ),
                        );
                      }

                      final guardians = guardiansSnapshot.data ?? const [];
                      if (guardians.isEmpty) {
                        return const ScholifyEmptyState(
                          icon: Icons.family_restroom_outlined,
                          title: 'No guardians yet',
                          message: 'Link a guardian to the selected student to get started.',
                          accent: ScholifyColors.academicNavy,
                        );
                      }

                      return ListView.separated(
                        itemCount: guardians.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final guardian = guardians[index];
                          final meta = <String>[
                            guardian.relation,
                            if (guardian.phone != null &&
                                guardian.phone!.isNotEmpty)
                              guardian.phone!,
                            if (guardian.email != null &&
                                guardian.email!.isNotEmpty)
                              guardian.email!,
                          ].join(' | ');

                          final isProcessing =
                              _processingGuardianId == guardian.id;

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
                              ),
                            ),
                            child: ListTile(
                              title: Text(guardian.fullName),
                              subtitle: Text(meta),
                              trailing: Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (guardian.isPrimary)
                                    const Chip(label: Text('PRIMARY')),
                                  Chip(
                                    label: Text(
                                      guardian.isActive ? 'ACTIVE' : 'INACTIVE',
                                    ),
                                  ),
                                  if (isProcessing)
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else
                                    PopupMenuButton<String>(
                                      onSelected: (action) {
                                        _handleGuardianAction(action, guardian);
                                      },
                                      itemBuilder: (context) {
                                        return [
                                          const PopupMenuItem<String>(
                                            value: 'edit',
                                            child: Text('Edit Guardian'),
                                          ),
                                          PopupMenuItem<String>(
                                            value: guardian.isActive
                                                ? 'deactivate'
                                                : 'activate',
                                            child: Text(
                                              guardian.isActive
                                                  ? 'Deactivate Guardian'
                                                  : 'Activate Guardian',
                                            ),
                                          ),
                                        ];
                                      },
                                    ),
                                ],
                              ),
                              onTap: () => _startEditing(guardian),
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

  Widget _buildGuardianForm(String selectedStudentId) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: TextField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Guardian Name',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 180,
              child: TextField(
                controller: _relationController,
                decoration: const InputDecoration(
                  labelText: 'Relation',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 170,
              child: TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 220,
              child: TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 170,
              child: CheckboxListTile(
                value: _isPrimary,
                onChanged: (value) {
                  setState(() {
                    _isPrimary = value ?? false;
                  });
                },
                title: const Text('Primary'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
            FilledButton.icon(
              onPressed: _isSaving
                  ? null
                  : () => _saveGuardian(selectedStudentId),
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving...' : 'Save Guardian'),
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

  void _startEditing(StudentGuardianEntry guardian) {
    setState(() {
      _editingGuardianId = guardian.id;
      _fullNameController.text = guardian.fullName;
      _relationController.text = guardian.relation;
      _phoneController.text = guardian.phone ?? '';
      _emailController.text = guardian.email ?? '';
      _isPrimary = guardian.isPrimary;
    });
  }

  void _resetForm() {
    _editingGuardianId = null;
    _fullNameController.clear();
    _relationController.clear();
    _phoneController.clear();
    _emailController.clear();
    _isPrimary = false;
  }

  Future<void> _saveGuardian(String studentId) async {
    final fullName = _fullNameController.text.trim();
    final relation = _relationController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    if (fullName.isEmpty || relation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guardian name and relation are required.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.createOrUpdateGuardian(
        guardianId: _editingGuardianId,
        studentId: studentId,
        fullName: fullName,
        relation: relation,
        phone: phone.isEmpty ? null : phone,
        email: email.isEmpty ? null : email,
        isPrimary: _isPrimary,
        isActive: true,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _editingGuardianId == null
                  ? 'Guardian saved locally and queued for sync.'
                  : 'Guardian updated locally and queued for sync.',
            ),
          ),
        );
        setState(_resetForm);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save guardian: $error')),
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

  Future<void> _handleGuardianAction(
    String action,
    StudentGuardianEntry guardian,
  ) async {
    if (action == 'edit') {
      _startEditing(guardian);
      return;
    }

    final shouldActivate = action == 'activate';
    final shouldDeactivate = action == 'deactivate';
    if (!shouldActivate && !shouldDeactivate) {
      return;
    }

    setState(() {
      _processingGuardianId = guardian.id;
    });

    try {
      await _repository.setGuardianStatus(
        guardian: guardian,
        isActive: shouldActivate,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              shouldActivate
                  ? 'Guardian activated and queued for sync.'
                  : 'Guardian deactivated and queued for sync.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update guardian: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingGuardianId = null;
        });
      }
    }
  }
}
