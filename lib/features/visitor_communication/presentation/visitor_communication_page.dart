import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../data/visitor_communication_repository.dart';

class VisitorCommunicationPage extends StatefulWidget {
  const VisitorCommunicationPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<VisitorCommunicationPage> createState() =>
      _VisitorCommunicationPageState();
}

class _VisitorCommunicationPageState extends State<VisitorCommunicationPage> {
  late final VisitorCommunicationRepository _repository;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String _entryType = VisitorCommunicationRepository.visitorBookType;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _repository = VisitorCommunicationRepository(
      database: widget.syncEngine.database,
      syncEngine: widget.syncEngine,
      tenantContext: widget.tenantContext,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _purposeController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Visitor & Communication'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Visitor Book'),
              Tab(text: 'Timeline'),
              Tab(text: 'Comments'),
            ],
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildComposerCard(),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildList(
                      stream: _repository.watchVisitorBook(),
                      emptyText: 'No visitor-book entries yet.',
                      dateFormat: dateFormat,
                    ),
                    _buildList(
                      stream: _repository.watchTimeline(),
                      emptyText: 'No timeline records yet.',
                      dateFormat: dateFormat,
                    ),
                    _buildList(
                      stream: _repository.watchComments(),
                      emptyText: 'No communication comments yet.',
                      dateFormat: dateFormat,
                    ),
                  ],
                ),
              ),
            ],
          ),
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
              'Add Entry',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: _entryType,
                    decoration: const InputDecoration(
                      labelText: 'Entry Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: VisitorCommunicationRepository.visitorBookType,
                        child: Text('Visitor Book'),
                      ),
                      DropdownMenuItem(
                        value: VisitorCommunicationRepository.timelineType,
                        child: Text('Timeline'),
                      ),
                      DropdownMenuItem(
                        value: VisitorCommunicationRepository.commentType,
                        child: Text('Comment'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _entryType = value;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Visitor/Author Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _purposeController,
              decoration: const InputDecoration(
                labelText: 'Purpose/Subject',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Note',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveEntry,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_alt_1),
              label: Text(_isSaving ? 'Saving...' : 'Save Entry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList({
    required Stream<List<VisitorCommunicationEntry>> stream,
    required String emptyText,
    required DateFormat dateFormat,
  }) {
    return StreamBuilder<List<VisitorCommunicationEntry>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Failed to load visitor records: ${snapshot.error}'),
          );
        }

        final rows = snapshot.data ?? const <VisitorCommunicationEntry>[];
        if (rows.isEmpty) {
          return Center(child: Text(emptyText));
        }

        return ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final entry = rows[index];
            final checkInText = entry.checkInAt == null
                ? 'N/A'
                : dateFormat.format(entry.checkInAt!.toLocal());

            return Card(
              child: ListTile(
                title: Text(entry.purpose ?? entry.visitorName ?? 'Entry'),
                subtitle: Text(
                  'Type: ${entry.entryType} | Visitor: ${entry.visitorName ?? 'N/A'} | Phone: ${entry.phone ?? 'N/A'}\nStatus: ${entry.statusLabel} | Check-in: $checkInText\n${entry.note ?? ''}',
                ),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _isSaving ? null : () => _deleteEntry(entry),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveEntry() async {
    final purpose = _purposeController.text.trim();
    final note = _noteController.text.trim();

    if (purpose.isEmpty && note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purpose or note is required.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.saveEntry(
        entryType: _entryType,
        visitorName: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        purpose: purpose.isEmpty ? null : purpose,
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        note: note.isEmpty ? null : note,
      );

      _nameController.clear();
      _purposeController.clear();
      _phoneController.clear();
      _noteController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry saved and queued for sync.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save entry: $error')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteEntry(VisitorCommunicationEntry entry) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.deleteEntry(entry);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry deleted and sync queued.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete entry: $error')),
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
