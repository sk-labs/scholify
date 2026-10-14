import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../../../core/theme/scholify_colors.dart';
import '../../../core/widgets/scholify_empty_state.dart';
import '../data/live_class_repository.dart';

class LiveClassesPage extends StatefulWidget {
  const LiveClassesPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<LiveClassesPage> createState() => _LiveClassesPageState();
}

class _LiveClassesPageState extends State<LiveClassesPage> {
  late final LiveClassRepository _repository;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _sectionController = TextEditingController();
  final TextEditingController _joinUrlController = TextEditingController();

  String _providerType = LiveClassRepository.zoomProvider;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _repository = LiveClassRepository(
      database: widget.syncEngine.database,
      syncEngine: widget.syncEngine,
      tenantContext: widget.tenantContext,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _hostController.dispose();
    _sectionController.dispose();
    _joinUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    // No page-level AppBar: the shell provides the top bar.
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Live Classes', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                'Schedule and join live Zoom and Google Meet classes.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TabBar(
                labelColor: scheme.primary,
                unselectedLabelColor: scheme.onSurfaceVariant,
                indicatorColor: scheme.secondary,
                tabs: const [
                  Tab(text: 'Zoom'),
                  Tab(text: 'Gmeet'),
                ],
              ),
              const SizedBox(height: 16),
              _buildComposerCard(theme, scheme),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildList(
                      stream: _repository.watchZoomClasses(),
                      emptyTitle: 'No Zoom classes yet',
                      emptyMessage:
                          'Schedule your first Zoom class with the form above.',
                      dateFormat: dateFormat,
                    ),
                    _buildList(
                      stream: _repository.watchGmeetClasses(),
                      emptyTitle: 'No Gmeet classes yet',
                      emptyMessage:
                          'Schedule your first Gmeet class with the form above.',
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

  Widget _buildComposerCard(ThemeData theme, ColorScheme scheme) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Schedule Live Class',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    initialValue: _providerType,
                    decoration: const InputDecoration(
                      labelText: 'Provider',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: LiveClassRepository.zoomProvider,
                        child: Text('Zoom'),
                      ),
                      DropdownMenuItem(
                        value: LiveClassRepository.gmeetProvider,
                        child: Text('Gmeet'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _providerType = value;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Class Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _hostController,
                    decoration: const InputDecoration(
                      labelText: 'Host',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _sectionController,
                    decoration: const InputDecoration(
                      labelText: 'Class/Section',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _joinUrlController,
              decoration: const InputDecoration(
                labelText: 'Join URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveClass,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.video_call_outlined),
              label: Text(_isSaving ? 'Saving...' : 'Save Class'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList({
    required Stream<List<LiveClassEntry>> stream,
    required String emptyTitle,
    required String emptyMessage,
    required DateFormat dateFormat,
  }) {
    return StreamBuilder<List<LiveClassEntry>>(
      stream: stream,
      builder: (context, snapshot) {
        final scheme = Theme.of(context).colorScheme;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Failed to load live classes: ${snapshot.error}'),
          );
        }

        final rows = snapshot.data ?? const <LiveClassEntry>[];
        if (rows.isEmpty) {
          return ScholifyEmptyState(
            icon: Icons.videocam_outlined,
            title: emptyTitle,
            message: emptyMessage,
            accent: ScholifyColors.scholarTeal,
          );
        }

        return ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = rows[index];
            final startText = item.startAt == null
                ? 'TBD'
                : dateFormat.format(item.startAt!.toLocal());

            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: ScholifyColors.tint(
                      ScholifyColors.scholarTeal,
                      0.12,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.videocam_outlined,
                    color: ScholifyColors.scholarTeal,
                  ),
                ),
                title: Text(item.title),
                subtitle: Text(
                  'Provider: ${item.providerType.toUpperCase()} | Host: ${item.hostName ?? 'N/A'} | Section: ${item.classSection ?? 'N/A'}\nStart: $startText | Status: ${item.statusLabel}',
                ),
                isThreeLine: true,
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      tooltip: 'Join Class',
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => _joinClass(item.joinUrl),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _isSaving ? null : () => _deleteClass(item),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveClass() async {
    final title = _titleController.text.trim();
    final joinUrl = _joinUrlController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Class title is required.')));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.saveClass(
        providerType: _providerType,
        title: title,
        hostName: _hostController.text.trim().isEmpty
            ? null
            : _hostController.text.trim(),
        classSection: _sectionController.text.trim().isEmpty
            ? null
            : _sectionController.text.trim(),
        joinUrl: joinUrl.isEmpty ? null : joinUrl,
      );

      _titleController.clear();
      _hostController.clear();
      _sectionController.clear();
      _joinUrlController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Live class saved and sync queued.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save class: $error')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteClass(LiveClassEntry item) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.deleteClass(item);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Live class deleted.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete class: $error')),
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

  Future<void> _joinClass(String? rawUrl) async {
    if (rawUrl == null || rawUrl.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join URL is not available.')),
      );
      return;
    }

    final resolved =
        rawUrl.startsWith('http://') || rawUrl.startsWith('https://')
        ? rawUrl
        : 'https://$rawUrl';
    final uri = Uri.tryParse(resolved);

    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid join URL.')));
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to open join URL.')));
    }
  }
}
