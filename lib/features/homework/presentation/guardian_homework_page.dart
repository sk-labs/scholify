import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../../../core/theme/scholify_colors.dart';
import '../../../core/widgets/scholify_empty_state.dart';
import '../data/homework_repository.dart';

/// Guardian/student-facing homework: read-only list of assignments.
/// No creating or editing — that's the teacher's job.
class GuardianHomeworkPage extends StatefulWidget {
  const GuardianHomeworkPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<GuardianHomeworkPage> createState() => _GuardianHomeworkPageState();
}

class _GuardianHomeworkPageState extends State<GuardianHomeworkPage> {
  late final HomeworkRepository _repository;
  String _filter = 'all'; // all | due_soon | overdue

  @override
  void initState() {
    super.initState();
    _repository = HomeworkRepository(
      database: widget.syncEngine.database,
      syncEngine: widget.syncEngine,
      tenantContext: widget.tenantContext,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = widget.tenantContext.role.toLowerCase();
    final isGuardian = role == 'guardian';

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeader(theme, isGuardian),
          const SizedBox(height: 20),
          _buildFilterChips(theme),
          const SizedBox(height: 16),
          StreamBuilder<List<HomeworkAssignmentEntry>>(
            stream: _repository.watchAssignments(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              var items = (snapshot.data ?? const [])
                  .where((a) => a.isActive && a.isPublished)
                  .toList();
              items = _applyFilter(items);
              items.sort((a, b) {
                final da = a.dueDate ?? DateTime(2100);
                final db = b.dueDate ?? DateTime(2100);
                return da.compareTo(db);
              });

              if (items.isEmpty) {
                return ScholifyEmptyState(
                  icon: Icons.assignment_outlined,
                  title: 'No homework',
                  message: isGuardian
                      ? 'No homework assigned to your child right now.'
                      : 'No homework assigned right now. Enjoy!',
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    _buildHomeworkCard(theme, items[i]),
                    if (i < items.length - 1) const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<HomeworkAssignmentEntry> _applyFilter(
      List<HomeworkAssignmentEntry> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_filter) {
      case 'due_soon':
        return items.where((a) {
          if (a.dueDate == null) return false;
          final d = DateTime(
              a.dueDate!.year, a.dueDate!.month, a.dueDate!.day);
          final diff = d.difference(today).inDays;
          return diff >= 0 && diff <= 3;
        }).toList();
      case 'overdue':
        return items.where((a) {
          if (a.dueDate == null) return false;
          final d = DateTime(
              a.dueDate!.year, a.dueDate!.month, a.dueDate!.day);
          return d.isBefore(today);
        }).toList();
      default:
        return items;
    }
  }

  Widget _buildHeader(ThemeData theme, bool isGuardian) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ScholifyColors.academicNavy,
            ScholifyColors.navyLight,
            ScholifyColors.scholarTeal.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ScholifyColors.academicNavy.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Homework',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Assignments',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isGuardian
                      ? 'What your child needs to work on'
                      : 'What you need to work on',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.assignment_outlined,
                color: Colors.white, size: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme) {
    final chips = [
      ('all', 'All'),
      ('due_soon', 'Due Soon'),
      ('overdue', 'Overdue'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final chip in chips)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(chip.$2),
                selected: _filter == chip.$1,
                onSelected: (_) =>
                    setState(() => _filter = chip.$1),
                selectedColor: ScholifyColors.academicNavy,
                labelStyle: TextStyle(
                  color: _filter == chip.$1
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHomeworkCard(
      ThemeData theme, HomeworkAssignmentEntry item) {
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    Color statusColor = ScholifyColors.scholarTeal;
    String statusLabel = 'Upcoming';
    IconData statusIcon = Icons.schedule_outlined;
    if (item.dueDate != null) {
      final d = DateTime(item.dueDate!.year, item.dueDate!.month,
          item.dueDate!.day);
      final diff = d.difference(today).inDays;
      if (diff < 0) {
        statusColor = ScholifyColors.error;
        statusLabel = 'Overdue';
        statusIcon = Icons.warning_amber_outlined;
      } else if (diff == 0) {
        statusColor = ScholifyColors.achievementAmber;
        statusLabel = 'Due today';
        statusIcon = Icons.today_outlined;
      } else if (diff <= 3) {
        statusColor = ScholifyColors.achievementAmber;
        statusLabel = 'Due in $diff days';
        statusIcon = Icons.upcoming_outlined;
      }
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusIcon,
                      color: statusColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700),
                      ),
                      if (item.subjectName != null)
                        Text(
                          item.subjectName!,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (item.details != null && item.details!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(item.details!,
                  style: theme.textTheme.bodyMedium),
            ],
            if (item.dueDate != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.event_outlined,
                      size: 14,
                      color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'Due ${DateFormat('EEE, d MMM yyyy').format(item.dueDate!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
