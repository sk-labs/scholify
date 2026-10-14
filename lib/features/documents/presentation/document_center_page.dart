import 'package:flutter/material.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../data/document_center_repository.dart';

class DocumentCenterPage extends StatefulWidget {
  const DocumentCenterPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<DocumentCenterPage> createState() => _DocumentCenterPageState();
}

class _DocumentCenterPageState extends State<DocumentCenterPage> {
  late final DocumentCenterRepository _repository;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  String _selectedType = DocumentCenterRepository.contentTypeDownload;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _repository = DocumentCenterRepository(
      database: widget.syncEngine.database,
      syncEngine: widget.syncEngine,
      tenantContext: widget.tenantContext,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _urlController.dispose();
    _categoryController.dispose();
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
                  'Document Center',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Share resources, videos, and documents.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _typeChip(
                  DocumentCenterRepository.contentTypeDownload,
                  'Contents',
                ),
                _typeChip(DocumentCenterRepository.contentTypeVideo, 'Videos'),
                _typeChip(
                  DocumentCenterRepository.contentTypeMyDocument,
                  'My Documents',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        labelText:
                            _selectedType ==
                                DocumentCenterRepository.contentTypeMyDocument
                            ? 'Attachment URL (upload target)'
                            : 'Resource URL',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: const Icon(Icons.upload_file),
                      label: Text(
                        _isSaving
                            ? 'Saving...'
                            : _selectedType ==
                                  DocumentCenterRepository.contentTypeMyDocument
                            ? 'Upload Document Entry'
                            : 'Save Item',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<DocumentCenterEntry>>(
                stream: _streamForType(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Failed to load items: ${snapshot.error}'),
                    );
                  }

                  final rows = snapshot.data ?? const <DocumentCenterEntry>[];
                  if (rows.isEmpty) {
                    return Center(
                      child: Text('No ${_labelForType(_selectedType)} items.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      return Card(
                        child: ListTile(
                          leading: Icon(_iconForType(row.contentType)),
                          title: Text(row.title),
                          subtitle: Text(
                            '${row.categoryLabel ?? 'General'} | ${row.uploadState}\n${row.fileUrl ?? 'No URL'}',
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _isSaving ? null : () => _delete(row),
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

  Widget _typeChip(String value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedType == value,
      onSelected: (_) {
        setState(() {
          _selectedType = value;
        });
      },
    );
  }

  Stream<List<DocumentCenterEntry>> _streamForType() {
    switch (_selectedType) {
      case DocumentCenterRepository.contentTypeDownload:
        return _repository.watchDownloadContents();
      case DocumentCenterRepository.contentTypeVideo:
        return _repository.watchVideoTutorials();
      case DocumentCenterRepository.contentTypeMyDocument:
        return _repository.watchMyDocuments();
      default:
        return _repository.watchDownloadContents();
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Title is required.')));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.saveItem(
        contentType: _selectedType,
        title: title,
        description: _emptyToNull(_descriptionController.text),
        fileUrl: _emptyToNull(_urlController.text),
        categoryLabel: _emptyToNull(_categoryController.text),
        uploadState:
            _selectedType == DocumentCenterRepository.contentTypeMyDocument
            ? 'pending_upload'
            : 'uploaded',
      );

      _titleController.clear();
      _descriptionController.clear();
      _urlController.clear();
      _categoryController.clear();
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _delete(DocumentCenterEntry row) async {
    setState(() {
      _isSaving = true;
    });
    try {
      await _repository.deleteItem(row);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case DocumentCenterRepository.contentTypeDownload:
        return Icons.description_outlined;
      case DocumentCenterRepository.contentTypeVideo:
        return Icons.ondemand_video_outlined;
      case DocumentCenterRepository.contentTypeMyDocument:
        return Icons.folder_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  String _labelForType(String type) {
    switch (type) {
      case DocumentCenterRepository.contentTypeDownload:
        return 'content';
      case DocumentCenterRepository.contentTypeVideo:
        return 'video';
      case DocumentCenterRepository.contentTypeMyDocument:
        return 'document';
      default:
        return 'item';
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }
}
