import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';

class SuperadminAuditPage extends StatefulWidget {
  const SuperadminAuditPage({
    super.key,
    required this.syncEngine,
  });

  final SyncEngine syncEngine;

  @override
  State<SuperadminAuditPage> createState() => _SuperadminAuditPageState();
}

class _SuperadminAuditPageState extends State<SuperadminAuditPage> {
  int _currentPage = 0;
  static const int _entriesPerPage = 50;
  String? _entityTypeFilter;
  String? _actorIdFilter;
  List<String> _availableEntityTypes = [];
  List<String> _availableActorIds = [];

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
  }

  Future<void> _loadFilterOptions() async {
    final entityTypes = await widget.syncEngine.database.getDistinctAuditEntityTypes();
    final actorIds = await widget.syncEngine.database.getDistinctAuditActorIds();
    
    if (mounted) {
      setState(() {
        _availableEntityTypes = entityTypes;
        _availableActorIds = actorIds;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm:ss');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Log'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Page info header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Displaying audit entries in reverse chronological order',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Filter dropdowns
            _buildFilterRow(),
            const SizedBox(height: 16),
            // Audit log entries list
            Expanded(
              child: StreamBuilder<List<AuditLogEntry>>(
                stream: widget.syncEngine.database.watchAuditLogEntries(
                  limit: _entriesPerPage,
                  offset: _currentPage * _entriesPerPage,
                  entityTypeFilter: _entityTypeFilter,
                  actorIdFilter: _actorIdFilter,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Failed to load audit log: ${snapshot.error}'),
                    );
                  }

                  final entries = snapshot.data ?? const [];

                  if (entries.isEmpty && _currentPage == 0) {
                    return const Center(
                      child: Text('No audit log entries yet.'),
                    );
                  }

                  if (entries.isEmpty && _currentPage > 0) {
                    // No more entries, go back to previous page
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _currentPage = _currentPage - 1;
                        });
                      }
                    });
                    return const Center(child: CircularProgressIndicator());
                  }

                  return ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _buildAuditEntryCard(entry, dateFormat);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // Pagination controls
            _buildPaginationControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Entity Type Filter
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Entity Type',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String?>(
                    initialValue: _entityTypeFilter,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All'),
                      ),
                      ..._availableEntityTypes.map((type) => DropdownMenuItem<String?>(
                        value: type,
                        child: Text(type),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _entityTypeFilter = value;
                        _currentPage = 0; // Reset pagination
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Actor Filter
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Actor',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String?>(
                    initialValue: _actorIdFilter,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All'),
                      ),
                      ..._availableActorIds.map((actorId) => DropdownMenuItem<String?>(
                        value: actorId,
                        child: Text(actorId),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _actorIdFilter = value;
                        _currentPage = 0; // Reset pagination
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditEntryCard(AuditLogEntry entry, DateFormat dateFormat) {
    return Card(
      child: ExpansionTile(
        title: Row(
          children: [
            _buildOperationChip(entry.operation),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${entry.entityType} (${entry.entityId})',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Timestamp: ${dateFormat.format(entry.timestamp.toLocal())}',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                'Actor: ${entry.actorId} (${entry.actorRole})',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Changed Fields:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SelectableText(
                    _formatJson(entry.changedFields),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationChip(String operation) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (operation.toLowerCase()) {
      case 'create':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade900;
        icon = Icons.add_circle_outline;
        break;
      case 'update':
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade900;
        icon = Icons.edit_outlined;
        break;
      case 'delete':
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade900;
        icon = Icons.delete_outline;
        break;
      default:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade900;
        icon = Icons.info_outline;
    }

    return Chip(
      avatar: Icon(icon, size: 16, color: textColor),
      label: Text(
        operation.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      backgroundColor: backgroundColor,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildPaginationControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Previous button
            ElevatedButton.icon(
              onPressed: _currentPage > 0
                  ? () {
                      setState(() {
                        _currentPage--;
                      });
                    }
                  : null,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Previous'),
            ),
            // Page indicator
            Text(
              'Page ${_currentPage + 1}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            // Next button
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _currentPage++;
                });
              },
              icon: const Icon(Icons.chevron_right),
              label: const Text('Next'),
              iconAlignment: IconAlignment.end,
            ),
          ],
        ),
      ),
    );
  }

  String _formatJson(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(decoded);
    } catch (e) {
      // If JSON parsing fails, return the original string
      return jsonString;
    }
  }
}
