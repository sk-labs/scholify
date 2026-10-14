import 'package:flutter/material.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../data/hostel_repository.dart';

class HostelPage extends StatefulWidget {
  const HostelPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<HostelPage> createState() => _HostelPageState();
}

class _HostelPageState extends State<HostelPage> {
  late final HostelRepository _repository;

  final TextEditingController _studentController = TextEditingController();
  final TextEditingController _hostelController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _roomTypeController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _bedController = TextEditingController();
  final TextEditingController _wardenController = TextEditingController();
  final TextEditingController _wardenContactController =
      TextEditingController();
  final TextEditingController _monthlyFeesController = TextEditingController();

  bool _isActive = true;
  bool _includeInactive = false;
  bool _isSaving = false;
  String? _editingRoomId;

  @override
  void initState() {
    super.initState();
    _repository = HostelRepository(
      database: widget.syncEngine.database,
      syncEngine: widget.syncEngine,
      tenantContext: widget.tenantContext,
    );
  }

  @override
  void dispose() {
    _studentController.dispose();
    _hostelController.dispose();
    _roomController.dispose();
    _roomTypeController.dispose();
    _floorController.dispose();
    _bedController.dispose();
    _wardenController.dispose();
    _wardenContactController.dispose();
    _monthlyFeesController.dispose();
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
                  'Hostel Rooms',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage hostel allocations and room assignments.',
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
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: _studentController,
                            decoration: const InputDecoration(
                              labelText: 'Student ID',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: _hostelController,
                            decoration: const InputDecoration(
                              labelText: 'Hostel Name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 180,
                          child: TextField(
                            controller: _roomController,
                            decoration: const InputDecoration(
                              labelText: 'Room No',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 180,
                          child: TextField(
                            controller: _roomTypeController,
                            decoration: const InputDecoration(
                              labelText: 'Room Type',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 160,
                          child: TextField(
                            controller: _floorController,
                            decoration: const InputDecoration(
                              labelText: 'Floor No',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 160,
                          child: TextField(
                            controller: _bedController,
                            decoration: const InputDecoration(
                              labelText: 'Bed No',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: _wardenController,
                            decoration: const InputDecoration(
                              labelText: 'Warden Name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: _wardenContactController,
                            decoration: const InputDecoration(
                              labelText: 'Warden Contact',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 160,
                          child: TextField(
                            controller: _monthlyFeesController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Monthly Fees',
                              border: OutlineInputBorder(),
                            ),
                          ),
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
                          onPressed: _isSaving ? null : _saveRoom,
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
                            _editingRoomId == null
                                ? 'Save Room'
                                : 'Update Room',
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
              title: const Text('Include inactive rooms'),
              value: _includeInactive,
              onChanged: (value) {
                setState(() {
                  _includeInactive = value;
                });
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<HostelRoomEntry>>(
                stream: _repository.watchHostelRooms(
                  includeInactive: _includeInactive,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Failed to load hostel rooms: ${snapshot.error}',
                      ),
                    );
                  }

                  final rows = snapshot.data ?? const <HostelRoomEntry>[];
                  if (rows.isEmpty) {
                    return const Center(child: Text('No hostel rooms yet.'));
                  }

                  return ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      final title = [row.hostelName, row.roomNo]
                          .whereType<String>()
                          .where((value) => value.trim().isNotEmpty)
                          .join(' • ');
                      final detailParts = <String>[
                        if (row.roomType != null && row.roomType!.isNotEmpty)
                          row.roomType!,
                        if (row.floorNo != null && row.floorNo!.isNotEmpty)
                          'Floor ${row.floorNo}',
                        if (row.bedNo != null && row.bedNo!.isNotEmpty)
                          'Bed ${row.bedNo}',
                      ];
                      final detailLine = detailParts.join(' | ');

                      return Card(
                        child: ListTile(
                          title: Text(title.isEmpty ? 'Hostel Room' : title),
                          subtitle: Text(
                            '${row.studentId ?? 'No student'} | ${detailLine.isEmpty ? 'No room details' : detailLine} | Fees ${row.monthlyFees.toStringAsFixed(2)}',
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) => _handleAction(action, row),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
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

  Future<void> _saveRoom() async {
    final monthlyFees =
        double.tryParse(_monthlyFeesController.text.trim()) ?? 0;

    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.saveRoom(
        roomId: _editingRoomId,
        studentId: _studentController.text.trim().isEmpty
            ? null
            : _studentController.text.trim(),
        hostelName: _hostelController.text.trim().isEmpty
            ? null
            : _hostelController.text.trim(),
        roomNo: _roomController.text.trim().isEmpty
            ? null
            : _roomController.text.trim(),
        roomType: _roomTypeController.text.trim().isEmpty
            ? null
            : _roomTypeController.text.trim(),
        floorNo: _floorController.text.trim().isEmpty
            ? null
            : _floorController.text.trim(),
        bedNo: _bedController.text.trim().isEmpty
            ? null
            : _bedController.text.trim(),
        wardenName: _wardenController.text.trim().isEmpty
            ? null
            : _wardenController.text.trim(),
        wardenContact: _wardenContactController.text.trim().isEmpty
            ? null
            : _wardenContactController.text.trim(),
        monthlyFees: monthlyFees,
        isActive: _isActive,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hostel room saved locally.')),
        );
      }

      _clearForm();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save hostel room: $error')),
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

  Future<void> _handleAction(String action, HostelRoomEntry entry) async {
    if (action == 'edit') {
      _loadEntry(entry);
      return;
    }

    if (action == 'delete') {
      await _repository.deleteRoom(entry);
    }
  }

  void _loadEntry(HostelRoomEntry entry) {
    setState(() {
      _editingRoomId = entry.id;
      _studentController.text = entry.studentId ?? '';
      _hostelController.text = entry.hostelName ?? '';
      _roomController.text = entry.roomNo ?? '';
      _roomTypeController.text = entry.roomType ?? '';
      _floorController.text = entry.floorNo ?? '';
      _bedController.text = entry.bedNo ?? '';
      _wardenController.text = entry.wardenName ?? '';
      _wardenContactController.text = entry.wardenContact ?? '';
      _monthlyFeesController.text = entry.monthlyFees.toStringAsFixed(2);
      _isActive = entry.isActive;
    });
  }

  void _clearForm() {
    setState(() {
      _editingRoomId = null;
      _studentController.clear();
      _hostelController.clear();
      _roomController.clear();
      _roomTypeController.clear();
      _floorController.clear();
      _bedController.clear();
      _wardenController.clear();
      _wardenContactController.clear();
      _monthlyFeesController.clear();
      _isActive = true;
    });
  }
}
