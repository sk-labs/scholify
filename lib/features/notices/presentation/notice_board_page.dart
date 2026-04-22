import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../data/notice_board_repository.dart';

class NoticeBoardPage extends StatefulWidget {
  const NoticeBoardPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<NoticeBoardPage> createState() => _NoticeBoardPageState();
}

class _NoticeBoardPageState extends State<NoticeBoardPage> {
  late final NoticeBoardRepository _repository;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  String _audience = 'all';
  bool _isPublished = true;
  bool _isSaving = false;

  static const List<String> _audiences = <String>[
    'all',
    'students',
    'parents',
    'staff',
  ];

  @override
  void initState() {
    super.initState();
    _repository = NoticeBoardRepository(
      database: widget.syncEngine.database,
      syncEngine: widget.syncEngine,
      tenantContext: widget.tenantContext,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Notice Board (Offline-First)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildComposerCard(),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<NoticeBoardEntry>>(
                stream: _repository.watchNotices(publishedOnly: false),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Failed to load notices: ${snapshot.error}'),
                    );
                  }

                  final notices = snapshot.data ?? const <NoticeBoardEntry>[];
                  if (notices.isEmpty) {
                    return const Center(
                      child: Text(
                        'No notices yet. Publish announcements from the card above.',
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: notices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final notice = notices[index];
                      final publishText = dateFormat.format(
                        notice.publishAt.toLocal(),
                      );
                      final expiryText = notice.expiresAt == null
                          ? 'No expiry'
                          : 'Expires ${dateFormat.format(notice.expiresAt!.toLocal())}';

                      return Card(
                        child: ListTile(
                          title: Text(notice.title),
                          subtitle: Text(
                            '${notice.message}\nAudience: ${notice.audience.toUpperCase()} | ${notice.isPublished ? 'Published' : 'Draft'}\nPublished: $publishText | $expiryText',
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            tooltip: 'Delete notice',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _isSaving
                                ? null
                                : () => _deleteNotice(notice),
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

  Widget _buildComposerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create Notice',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _messageController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: _audience,
                    decoration: const InputDecoration(
                      labelText: 'Audience',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _audiences
                        .map(
                          (audience) => DropdownMenuItem<String>(
                            value: audience,
                            child: Text(audience.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _audience = value;
                      });
                    },
                  ),
                ),
                FilterChip(
                  label: const Text('Published'),
                  selected: _isPublished,
                  onSelected: (value) {
                    setState(() {
                      _isPublished = value;
                    });
                  },
                ),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveNotice,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.campaign_outlined),
                  label: Text(_isSaving ? 'Saving...' : 'Save Notice'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveNotice() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and message are required.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.saveNotice(
        title: title,
        message: message,
        audience: _audience,
        isPublished: _isPublished,
      );

      _titleController.clear();
      _messageController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notice saved locally and queued for sync.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save notice: $error')),
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

  Future<void> _deleteNotice(NoticeBoardEntry notice) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.deleteNotice(notice);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notice deleted and sync queued.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete notice: $error')),
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
