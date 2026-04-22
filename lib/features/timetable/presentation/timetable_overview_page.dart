import 'package:flutter/material.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../data/timetable_repository.dart';

class TimetableOverviewPage extends StatefulWidget {
  const TimetableOverviewPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<TimetableOverviewPage> createState() => _TimetableOverviewPageState();
}

class _TimetableOverviewPageState extends State<TimetableOverviewPage> {
  late final TimetableRepository _repository;

  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _teacherController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _timeFromController = TextEditingController();
  final TextEditingController _timeToController = TextEditingController();

  String _selectedDay = TimetableRepository.weekdays.first;
  int _periodIndex = 1;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _repository = TimetableRepository(
      database: widget.syncEngine.database,
      syncEngine: widget.syncEngine,
      tenantContext: widget.tenantContext,
    );
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _teacherController.dispose();
    _roomController.dispose();
    _timeFromController.dispose();
    _timeToController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Class Timetable (Offline-First)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildDaySelector(),
            const SizedBox(height: 12),
            _buildComposerCard(),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<TimetableSlotEntry>>(
                stream: _repository.watchDaySlots(_selectedDay),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Failed to load timetable: ${snapshot.error}',
                      ),
                    );
                  }

                  final rows = snapshot.data ?? const <TimetableSlotEntry>[];
                  if (rows.isEmpty) {
                    return Center(
                      child: Text('No periods scheduled for $_selectedDay.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      final timeText = _formatTimeRange(row);

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text('${row.periodIndex}'),
                          ),
                          title: Text(row.subjectName),
                          subtitle: Text(
                            '${timeText.isEmpty ? 'Time TBD' : timeText} | ${row.roomNo ?? 'Room TBD'}\nTeacher: ${row.teacherName ?? 'Unassigned'}',
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            tooltip: 'Delete slot',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _isSaving
                                ? null
                                : () => _deleteSlot(row),
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

  Widget _buildDaySelector() {
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final day in TimetableRepository.weekdays)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(day),
                  selected: _selectedDay == day,
                  onSelected: (selected) {
                    if (!selected) return;
                    setState(() {
                      _selectedDay = day;
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Period Slot',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 130,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Period #',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      final parsed = int.tryParse(value.trim());
                      if (parsed == null || parsed <= 0) return;
                      _periodIndex = parsed;
                    },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _timeFromController,
                    decoration: const InputDecoration(
                      labelText: 'From (e.g. 08:30)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _timeToController,
                    decoration: const InputDecoration(
                      labelText: 'To (e.g. 09:10)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _roomController,
                    decoration: const InputDecoration(
                      labelText: 'Room',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _teacherController,
                    decoration: const InputDecoration(
                      labelText: 'Teacher',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveSlot,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: Text(_isSaving ? 'Saving...' : 'Add Slot'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeRange(TimetableSlotEntry row) {
    final from = row.timeFrom?.trim() ?? '';
    final to = row.timeTo?.trim() ?? '';
    if (from.isEmpty && to.isEmpty) {
      return '';
    }
    if (from.isNotEmpty && to.isNotEmpty) {
      return '$from - $to';
    }
    return from.isNotEmpty ? from : to;
  }

  Future<void> _saveSlot() async {
    final subject = _subjectController.text.trim();
    if (subject.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Subject is required.')));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.saveSlot(
        dayOfWeek: _selectedDay,
        periodIndex: _periodIndex,
        subjectName: subject,
        teacherName: _teacherController.text.trim().isEmpty
            ? null
            : _teacherController.text.trim(),
        roomNo: _roomController.text.trim().isEmpty
            ? null
            : _roomController.text.trim(),
        timeFrom: _timeFromController.text.trim().isEmpty
            ? null
            : _timeFromController.text.trim(),
        timeTo: _timeToController.text.trim().isEmpty
            ? null
            : _timeToController.text.trim(),
      );

      _subjectController.clear();
      _teacherController.clear();
      _roomController.clear();
      _timeFromController.clear();
      _timeToController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Timetable slot saved locally and queued for sync.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save timetable slot: $error')),
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

  Future<void> _deleteSlot(TimetableSlotEntry slot) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.deleteSlot(slot);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Timetable slot deleted and sync queued.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete timetable slot: $error')),
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
