import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../data/leave_request_repository.dart';

class LeaveRequestsPage extends StatefulWidget {
  const LeaveRequestsPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
    this.leaveData,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;
  final Map<String, dynamic>? leaveData;

  @override
  State<LeaveRequestsPage> createState() => _LeaveRequestsPageState();
}

class _LeaveRequestsPageState extends State<LeaveRequestsPage> {
  late final LeaveRequestRepository _repository;

  final TextEditingController _requesterController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _approverController = TextEditingController();
  final TextEditingController _attachmentController = TextEditingController();

  DateTime? _leaveFrom;
  DateTime? _leaveTo;
  DateTime? _appliedAt;
  DateTime? _approvedAt;
  String _statusLabel = 'pending';
  bool _isActive = true;
  bool _includeInactive = false;
  bool _isSaving = false;
  String? _editingLeaveId;

  @override
  void initState() {
    super.initState();
    _repository = LeaveRequestRepository(
      database: widget.syncEngine.database,
      syncEngine: widget.syncEngine,
      tenantContext: widget.tenantContext,
    );

    if (widget.leaveData != null) {
      _loadLegacyLeaveData(widget.leaveData!);
    }
  }

  @override
  void dispose() {
    _requesterController.dispose();
    _reasonController.dispose();
    _approverController.dispose();
    _attachmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
                        // Page header
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Leave Requests',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage student and staff leave applications.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: _requesterController,
                            decoration: const InputDecoration(
                              labelText: 'Requester ID',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: _reasonController,
                            decoration: const InputDecoration(
                              labelText: 'Reason',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: _approverController,
                            decoration: const InputDecoration(
                              labelText: 'Approver Name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: _attachmentController,
                            decoration: const InputDecoration(
                              labelText: 'Attachment URL',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _pickDate(
                            initialDate: _leaveFrom,
                            onPicked: (picked) {
                              setState(() {
                                _leaveFrom = picked;
                              });
                            },
                          ),
                          icon: const Icon(Icons.date_range),
                          label: Text(
                            _leaveFrom == null
                                ? 'Pick From'
                                : DateFormat('dd MMM yyyy').format(_leaveFrom!),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _pickDate(
                            initialDate: _leaveTo ?? _leaveFrom,
                            onPicked: (picked) {
                              setState(() {
                                _leaveTo = picked;
                              });
                            },
                          ),
                          icon: const Icon(Icons.event_available),
                          label: Text(
                            _leaveTo == null
                                ? 'Pick To'
                                : DateFormat('dd MMM yyyy').format(_leaveTo!),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _pickDate(
                            initialDate: _appliedAt,
                            onPicked: (picked) {
                              setState(() {
                                _appliedAt = picked;
                              });
                            },
                          ),
                          icon: const Icon(Icons.schedule),
                          label: Text(
                            _appliedAt == null
                                ? 'Applied At'
                                : DateFormat('dd MMM yyyy').format(_appliedAt!),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _pickDate(
                            initialDate: _approvedAt,
                            onPicked: (picked) {
                              setState(() {
                                _approvedAt = picked;
                              });
                            },
                          ),
                          icon: const Icon(Icons.verified),
                          label: Text(
                            _approvedAt == null
                                ? 'Approved At'
                                : DateFormat(
                                    'dd MMM yyyy',
                                  ).format(_approvedAt!),
                          ),
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: _statusLabel,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'pending',
                              child: Text('Pending'),
                            ),
                            DropdownMenuItem(
                              value: 'approved',
                              child: Text('Approved'),
                            ),
                            DropdownMenuItem(
                              value: 'rejected',
                              child: Text('Rejected'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _statusLabel = value;
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
                          onPressed: _isSaving ? null : _saveLeaveRequest,
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
                            _editingLeaveId == null
                                ? 'Save Leave'
                                : 'Update Leave',
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
              title: const Text('Include inactive requests'),
              value: _includeInactive,
              onChanged: (value) {
                setState(() {
                  _includeInactive = value;
                });
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<LeaveRequestEntry>>(
                stream: _repository.watchLeaveRequests(
                  includeInactive: _includeInactive,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Failed to load leave requests: ${snapshot.error}',
                      ),
                    );
                  }

                  final rows = snapshot.data ?? const <LeaveRequestEntry>[];
                  if (rows.isEmpty) {
                    return const Center(child: Text('No leave requests yet.'));
                  }

                  return ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      final rangeText = _dateRange(row.leaveFrom, row.leaveTo);
                      final appliedText = row.appliedAt == null
                          ? 'No applied date'
                          : 'Applied ${DateFormat('dd MMM yyyy').format(row.appliedAt!.toLocal())}';

                      return Card(
                        child: ListTile(
                          title: Text(row.reason ?? 'Leave Request'),
                          subtitle: Text(
                            '${row.statusLabel.toUpperCase()} | $rangeText | $appliedText',
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) => _handleAction(action, row),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              const PopupMenuItem(
                                value: 'approve',
                                child: Text('Approve'),
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

  Future<void> _pickDate({
    required DateTime? initialDate,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 5),
      initialDate: initialDate ?? now,
    );

    if (picked == null) return;
    onPicked(picked);
  }

  Future<void> _saveLeaveRequest() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a leave reason.')));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.saveLeaveRequest(
        leaveId: _editingLeaveId,
        requesterId: _requesterController.text.trim().isEmpty
            ? null
            : _requesterController.text.trim(),
        leaveFrom: _leaveFrom,
        leaveTo: _leaveTo,
        appliedAt: _appliedAt,
        reason: reason,
        statusLabel: _statusLabel,
        approverName: _approverController.text.trim().isEmpty
            ? null
            : _approverController.text.trim(),
        approvedAt: _approvedAt,
        attachmentUrl: _attachmentController.text.trim().isEmpty
            ? null
            : _attachmentController.text.trim(),
        isActive: _isActive,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave request saved locally.')),
        );
      }

      _clearForm();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save leave request: $error')),
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

  Future<void> _handleAction(String action, LeaveRequestEntry entry) async {
    if (action == 'edit') {
      _loadEntry(entry);
      return;
    }

    if (action == 'approve') {
      await _repository.approveLeaveRequest(
        entry: entry,
        approverName: _approverController.text.trim().isEmpty
            ? null
            : _approverController.text.trim(),
      );
      return;
    }

    if (action == 'delete') {
      await _repository.deleteLeaveRequest(entry);
    }
  }

  void _loadEntry(LeaveRequestEntry entry) {
    setState(() {
      _editingLeaveId = entry.id;
      _requesterController.text = entry.requesterId ?? '';
      _reasonController.text = entry.reason ?? '';
      _approverController.text = entry.approverName ?? '';
      _attachmentController.text = entry.attachmentUrl ?? '';
      _leaveFrom = entry.leaveFrom;
      _leaveTo = entry.leaveTo;
      _appliedAt = entry.appliedAt;
      _approvedAt = entry.approvedAt;
      _statusLabel = entry.statusLabel;
      _isActive = entry.isActive;
    });
  }

  void _clearForm() {
    setState(() {
      _editingLeaveId = null;
      _requesterController.clear();
      _reasonController.clear();
      _approverController.clear();
      _attachmentController.clear();
      _leaveFrom = null;
      _leaveTo = null;
      _appliedAt = null;
      _approvedAt = null;
      _statusLabel = 'pending';
      _isActive = true;
    });
  }

  void _loadLegacyLeaveData(Map<String, dynamic> leaveData) {
    setState(() {
      _editingLeaveId = _firstString(leaveData, ['leave_id', 'id', 'leaveId']);
      _requesterController.text = _firstString(leaveData, [
        'requester_id',
        'student_id',
        'studentId',
      ]);
      _reasonController.text = _firstString(leaveData, [
        'reason',
        'leave_reason',
        'description',
      ]);
      _approverController.text = _firstString(leaveData, [
        'approver_name',
        'approverName',
      ]);
      _attachmentController.text = _firstString(leaveData, [
        'attachment_url',
        'attachmentUrl',
        'leave_attachment',
      ]);
      _leaveFrom = _parseLegacyDate(leaveData, [
        'from_date',
        'leave_from_date',
        'leave_from',
        'start_date',
      ]);
      _leaveTo = _parseLegacyDate(leaveData, [
        'to_date',
        'leave_to_date',
        'leave_to',
        'end_date',
      ]);
      _appliedAt = _parseLegacyDate(leaveData, [
        'apply_date',
        'applied_date',
        'created_at',
        'created_date',
      ]);
      _approvedAt = _parseLegacyDate(leaveData, [
        'approved_at',
        'approvedAt',
      ]);
      _statusLabel = _firstString(leaveData, ['status', 'status_label'], fallback: 'pending');
      _isActive = _legacyActiveState(leaveData);
    });
  }

  String _firstString(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final raw = data[key];
      if (raw == null) continue;
      final text = raw.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return fallback;
  }

  DateTime? _parseLegacyDate(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final raw = data[key];
      if (raw == null) continue;
      final parsed = DateTime.tryParse(raw.toString());
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  bool _legacyActiveState(Map<String, dynamic> data) {
    final raw = data['is_active'] ?? data['active'] ?? data['status'];
    final text = raw?.toString().trim().toLowerCase();
    if (text == null || text.isEmpty) return true;
    if (text == 'no' || text == '0' || text == 'false' || text == '2') {
      return false;
    }
    return true;
  }

  String _dateRange(DateTime? from, DateTime? to) {
    if (from == null && to == null) {
      return 'No dates selected';
    }

    final fromText = from == null
        ? 'From ?'
        : 'From ${DateFormat('dd MMM yyyy').format(from.toLocal())}';
    final toText = to == null
        ? 'To ?'
        : 'To ${DateFormat('dd MMM yyyy').format(to.toLocal())}';
    return '$fromText | $toText';
  }
}
