import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../data/notification_repository.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  late final NotificationRepository _repository;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  String _notificationType = 'general';
  String _audience = 'all';
  bool _unreadOnly = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _repository = NotificationRepository(
      database: widget.syncEngine.database,
      syncEngine: widget.syncEngine,
      tenantContext: widget.tenantContext,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildComposerCard(),
            const SizedBox(height: 12),
            Row(
              children: [
                FilterChip(
                  label: const Text('Unread Only'),
                  selected: _unreadOnly,
                  onSelected: (value) {
                    setState(() {
                      _unreadOnly = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<NotificationEntry>>(
                stream: _repository.watchNotifications(unreadOnly: _unreadOnly),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Failed to load notifications: ${snapshot.error}',
                      ),
                    );
                  }

                  final rows = snapshot.data ?? const <NotificationEntry>[];
                  if (rows.isEmpty) {
                    return const Center(
                      child: Text(
                        'No notifications yet. Create one to test delivery states.',
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = rows[index];
                      final sentText = item.sentAt == null
                          ? 'N/A'
                          : dateFormat.format(item.sentAt!.toLocal());

                      return Card(
                        child: ListTile(
                          title: Text(item.title),
                          subtitle: Text(
                            '${item.body ?? 'No body'}\nType: ${item.notificationType} | Audience: ${item.audience} | Status: ${item.deliveryStatus} | Sent: $sentText',
                          ),
                          isThreeLine: true,
                          leading: Icon(
                            item.isRead
                                ? Icons.mark_email_read_outlined
                                : Icons.mark_email_unread_outlined,
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                tooltip: 'Mark as read',
                                icon: const Icon(Icons.done_all),
                                onPressed: _isSaving || item.isRead
                                    ? null
                                    : () => _markRead(item),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: _isSaving
                                    ? null
                                    : () => _deleteNotification(item),
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

  Widget _buildComposerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create Notification',
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
              controller: _bodyController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Body',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: _notificationType,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'general',
                        child: Text('General'),
                      ),
                      DropdownMenuItem(value: 'event', child: Text('Event')),
                      DropdownMenuItem(value: 'alert', child: Text('Alert')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _notificationType = value;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: _audience,
                    decoration: const InputDecoration(
                      labelText: 'Audience',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(
                        value: 'students',
                        child: Text('Students'),
                      ),
                      DropdownMenuItem(
                        value: 'parents',
                        child: Text('Parents'),
                      ),
                      DropdownMenuItem(value: 'staff', child: Text('Staff')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _audience = value;
                      });
                    },
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveNotification,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.notifications_active_outlined),
                  label: Text(_isSaving ? 'Saving...' : 'Save Notification'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveNotification() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

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
      await _repository.saveNotification(
        title: title,
        body: body.isEmpty ? null : body,
        notificationType: _notificationType,
        audience: _audience,
        deliveryStatus: 'queued',
      );

      _titleController.clear();
      _bodyController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification saved locally and queued for sync.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save notification: $error')),
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

  Future<void> _markRead(NotificationEntry entry) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.markRead(entry);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification marked as read.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark as read: $error')),
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

  Future<void> _deleteNotification(NotificationEntry entry) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.deleteNotification(entry);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Notification deleted.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete notification: $error')),
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
