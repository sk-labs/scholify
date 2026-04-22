import 'package:flutter/material.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../data/library_repository.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late final LibraryRepository _repository;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _ratingController = TextEditingController();
  final TextEditingController _issueCountController = TextEditingController();

  String _selectedType = LibraryRepository.issuedType;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _repository = LibraryRepository(
      database: widget.syncEngine.database,
      syncEngine: widget.syncEngine,
      tenantContext: widget.tenantContext,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _categoryController.dispose();
    _ratingController.dispose();
    _issueCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final item in const [
                  LibraryRepository.issuedType,
                  LibraryRepository.topType,
                  LibraryRepository.generalType,
                ])
                  ChoiceChip(
                    label: Text(_labelForType(item)),
                    selected: _selectedType == item,
                    onSelected: (_) {
                      setState(() {
                        _selectedType = item;
                      });
                    },
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
                        labelText: 'Book Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: 200,
                          child: TextField(
                            controller: _authorController,
                            decoration: const InputDecoration(
                              labelText: 'Author',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 180,
                          child: TextField(
                            controller: _categoryController,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 130,
                          child: TextField(
                            controller: _ratingController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Rating',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 130,
                          child: TextField(
                            controller: _issueCountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Issues',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: const Icon(Icons.add),
                      label: Text(_isSaving ? 'Saving...' : 'Save Book'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<LibraryBookEntry>>(
                stream: _streamForType(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Failed to load books: ${snapshot.error}'),
                    );
                  }

                  final books = snapshot.data ?? const <LibraryBookEntry>[];
                  if (books.isEmpty) {
                    return Center(
                      child: Text('No ${_labelForType(_selectedType)} books.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: books.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final row = books[index];
                      return Card(
                        child: ListTile(
                          title: Text(row.title),
                          subtitle: Text(
                            '${row.authorName ?? 'Author TBD'} | ${row.categoryName ?? 'Category TBD'}\nRating ${row.ratingScore.toStringAsFixed(1)} | Issues ${row.issueCount}',
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

  Stream<List<LibraryBookEntry>> _streamForType() {
    switch (_selectedType) {
      case LibraryRepository.issuedType:
        return _repository.watchIssuedBooks();
      case LibraryRepository.topType:
        return _repository.watchTopBooks();
      case LibraryRepository.generalType:
      default:
        return _repository.watchAllBooks();
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
      await _repository.saveBook(
        title: title,
        bookType: _selectedType,
        authorName: _emptyToNull(_authorController.text),
        categoryName: _emptyToNull(_categoryController.text),
        ratingScore: double.tryParse(_ratingController.text.trim()) ?? 0,
        issueCount: int.tryParse(_issueCountController.text.trim()) ?? 0,
        isIssued: _selectedType == LibraryRepository.issuedType,
      );

      _titleController.clear();
      _authorController.clear();
      _categoryController.clear();
      _ratingController.clear();
      _issueCountController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Library entry saved and queued.')),
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

  Future<void> _delete(LibraryBookEntry row) async {
    setState(() {
      _isSaving = true;
    });
    try {
      await _repository.deleteBook(row);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _labelForType(String type) {
    switch (type) {
      case LibraryRepository.issuedType:
        return 'Issued';
      case LibraryRepository.topType:
        return 'Top';
      case LibraryRepository.generalType:
        return 'General';
      default:
        return type;
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }
}
