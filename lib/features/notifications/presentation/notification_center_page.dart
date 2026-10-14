import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../../../core/theme/scholify_colors.dart';
import '../../../core/widgets/scholify_empty_state.dart';
import '../../../core/widgets/scholify_skeleton.dart';
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    // No page-level AppBar: the shell already provides the top bar with
    // product branding. The in-page header below is the page title.
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page header: title + subtitle.
            Text('Notifications', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              'Broadcast announcements and alerts to students, parents, and staff.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            _buildComposerCard(context, theme),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Inbox',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                FilterChip(
                  label: const Text('Unread only'),
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
                    return _buildLoadingList(context, theme);
                  }

                  if (snapshot.hasError) {
                    return _buildErrorState(context, theme, snapshot.error);
                  }

                  final rows = snapshot.data ?? const <NotificationEntry>[];
                  if (rows.isEmpty) {
                    return const ScholifyEmptyState(
                      icon: Icons.notifications_outlined,
                      title: 'No notifications yet',
                      message:
                          'Create your first notification above to reach students, parents, and staff.',
                      accent: ScholifyColors.accentComms,
                    );
                  }

                  return ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = rows[index];
                      final sentText = item.sentAt == null
                          ? 'Not sent yet'
                          : dateFormat.format(item.sentAt!.toLocal());
                      return _buildNotificationCard(
                        context,
                        theme,
                        item,
                        sentText,
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

  /// Shimmer skeleton list while notifications load.
  Widget _buildLoadingList(BuildContext context, ThemeData theme) {
    return ListView.separated(
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => _polishedCard(
        theme,
        const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScholifySkeleton(width: 180, height: 18),
              SizedBox(height: 10),
              ScholifySkeleton(width: double.infinity, height: 14),
              SizedBox(height: 6),
              ScholifySkeleton(width: 220, height: 14),
            ],
          ),
        ),
      ),
    );
  }

  /// Styled error state.
  Widget _buildErrorState(
      BuildContext context, ThemeData theme, Object? error) {
    final scheme = theme.colorScheme;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ScholifyColors.tint(ScholifyColors.error, 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: ScholifyColors.tint(ScholifyColors.error, 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: ScholifyColors.error),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Couldn\'t load notifications',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$error',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A polished notification card: icon medallion, bold title for unread,
  /// meta chips, and read/delete actions.
  Widget _buildNotificationCard(
    BuildContext context,
    ThemeData theme,
    NotificationEntry item,
    String sentText,
  ) {
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    const accent = ScholifyColors.accentComms;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: item.isRead
          ? null
          : ScholifyColors.tint(accent, isDark ? 0.1 : 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: item.isRead
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : scheme.outlineVariant.withValues(alpha: 0.6))
              : ScholifyColors.tint(accent, 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: ScholifyColors.tint(accent, isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                item.isRead
                    ? Icons.mark_email_read_outlined
                    : Icons.mark_email_unread_outlined,
                color: accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight:
                          item.isRead ? FontWeight.w600 : FontWeight.w800,
                    ),
                  ),
                  if (item.body?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.body!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _MetaChip(
                        label: item.notificationType,
                        color: accent,
                      ),
                      _MetaChip(
                        label: item.audience,
                        color: ScholifyColors.scholarTeal,
                      ),
                      _MetaChip(
                        label: item.deliveryStatus,
                        color: _deliveryStatusColor(item.deliveryStatus),
                      ),
                      _MetaChip(
                        label: sentText,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Mark as read',
                  icon: const Icon(Icons.done_all, size: 20),
                  onPressed: _isSaving || item.isRead
                      ? null
                      : () => _markRead(item),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed:
                      _isSaving ? null : () => _deleteNotification(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _deliveryStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'sent':
      case 'delivered':
        return ScholifyColors.success;
      case 'queued':
      case 'pending':
        return ScholifyColors.achievementAmber;
      case 'failed':
        return ScholifyColors.error;
      default:
        return ScholifyColors.slate400;
    }
  }

  /// Shared polished card surface: 16px radius + subtle border.
  Widget _polishedCard(ThemeData theme, Widget child) {
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : scheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: child,
    );
  }

  Widget _buildComposerCard(BuildContext context, ThemeData theme) {
    final scheme = theme.colorScheme;
    const accent = ScholifyColors.accentComms;

    return _polishedCard(
      theme,
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accent, accent.withValues(alpha: 0.7)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.campaign_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create Notification',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Compose and queue a new broadcast',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Body',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
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
                FilledButton.icon(
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

/// A small tinted label chip for notification metadata.
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ScholifyColors.tint(color, 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
