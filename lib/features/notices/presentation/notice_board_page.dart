import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/local_database.dart';
import '../../../core/services/local_notification_service.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../../../core/theme/scholify_colors.dart';
import '../../../core/widgets/scholify_empty_state.dart';
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

  /// Staff and management compose and moderate notices; family
  /// roles (guardian/student) are readers only.
  bool get _canManage {
    final role = widget.tenantContext.role.toLowerCase();
    return role == 'superadmin' ||
        role == 'school_owner' ||
        role == 'school_admin' ||
        role == 'teacher';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notice Board',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _canManage
                  ? 'Publish announcements and keep everyone informed.'
                  : 'Announcements from your school.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (_canManage) ...[
              _buildComposerCard(),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: StreamBuilder<List<NoticeBoardEntry>>(
                stream: _repository.watchNotices(publishedOnly: !_canManage),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Failed to load notices: ${snapshot.error}'),
                    );
                  }

                  var notices = snapshot.data ?? const <NoticeBoardEntry>[];
                  if (!_canManage) {
                    // Readers only see notices addressed to their
                    // audience that have not expired - the same rule
                    // the notification service applies.
                    final role = widget.tenantContext.role;
                    final now = DateTime.now();
                    notices = notices
                        .where((n) =>
                            LocalNotificationService.audienceMatches(
                                n.audience, role) &&
                            (n.expiresAt == null ||
                                n.expiresAt!.isAfter(now)))
                        .toList();
                  }
                  if (notices.isEmpty) {
                    return ScholifyEmptyState(
                      icon: Icons.campaign_outlined,
                      title: 'No notices yet',
                      message: _canManage
                          ? 'Publish your first announcement using the card above.'
                          : 'Notices from your school will appear here.',
                    );
                  }

                  return ListView.separated(
                    itemCount: notices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _buildNoticeCard(theme, notices[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeCard(ThemeData theme, NoticeBoardEntry notice) {
    final scheme = theme.colorScheme;
    final dateFormat = DateFormat('dd MMM yyyy');
    final audienceColor = _audienceColor(notice.audience);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notice.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: ScholifyColors.tintOf(
                              audienceColor, theme.brightness),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _audienceLabel(notice.audience),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: ScholifyColors.onTint(
                                audienceColor, theme.brightness),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        dateFormat.format(notice.publishAt.toLocal()),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (_canManage && !notice.isPublished)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: ScholifyColors.tintOf(
                                ScholifyColors.slate600, theme.brightness),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Draft',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: ScholifyColors.onTint(
                                  ScholifyColors.slate600,
                                  theme.brightness),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (_canManage && notice.expiresAt != null)
                        Text(
                          'Expires ${dateFormat.format(notice.expiresAt!.toLocal())}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (_canManage)
              IconButton(
                tooltip: 'Delete notice',
                icon: const Icon(Icons.delete_outline),
                onPressed: _isSaving ? null : () => _deleteNotice(notice),
              ),
          ],
        ),
      ),
    );
  }

  String _audienceLabel(String audience) => switch (audience) {
        'students' => 'Students',
        'parents' => 'Parents',
        'staff' => 'Staff',
        _ => 'Everyone',
      };

  Color _audienceColor(String audience) => switch (audience) {
        'students' => ScholifyColors.accentStudents,
        'parents' => ScholifyColors.achievementAmber,
        'staff' => ScholifyColors.scholarTeal,
        _ => ScholifyColors.academicNavy,
      };

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
                  selectedColor: ScholifyColors.academicNavy,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: _isPublished
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                  ),
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
