import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../../../core/theme/scholify_colors.dart';
import '../../../core/widgets/scholify_empty_state.dart';
import '../data/timetable_repository.dart';

/// Guardian/student-facing timetable: read-only weekly view.
/// No editing controls — that's the teacher's job.
class GuardianTimetablePage extends StatefulWidget {
  const GuardianTimetablePage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<GuardianTimetablePage> createState() => _GuardianTimetablePageState();
}

class _GuardianTimetablePageState extends State<GuardianTimetablePage> {
  late final TimetableRepository _repository;
  late String _selectedDay;

  @override
  void initState() {
    super.initState();
    _repository = TimetableRepository(
      database: widget.syncEngine.database,
      syncEngine: widget.syncEngine,
      tenantContext: widget.tenantContext,
    );
    final today = DateFormat('EEEE').format(DateTime.now());
    _selectedDay = TimetableRepository.weekdays.contains(today)
        ? today
        : TimetableRepository.weekdays.first;
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
          _buildDaySelector(theme),
          const SizedBox(height: 16),
          StreamBuilder<List<TimetableSlotEntry>>(
            stream: _repository.watchDaySlots(_selectedDay),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final slots = (snapshot.data ?? const [])
                  .where((s) => s.isActive)
                  .toList()
                ..sort((a, b) => a.periodIndex.compareTo(b.periodIndex));

              if (slots.isEmpty) {
                return ScholifyEmptyState(
                  icon: Icons.calendar_month_outlined,
                  title: 'No classes on $_selectedDay',
                  message: isGuardian
                      ? 'No periods scheduled for your child on this day.'
                      : 'No periods scheduled for this day.',
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < slots.length; i++) ...[
                    _buildSlotCard(theme, slots[i], i == 0),
                    if (i < slots.length - 1) const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
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
                  'Class Timetable',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Weekly Schedule',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isGuardian
                      ? 'Your child\'s class schedule for the week'
                      : 'Your class schedule for the week',
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
            child: const Icon(Icons.calendar_month_outlined,
                color: Colors.white, size: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final day in TimetableRepository.weekdays)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(day.substring(0, 3)),
                selected: _selectedDay == day,
                onSelected: (_) => setState(() => _selectedDay = day),
                selectedColor: ScholifyColors.academicNavy,
                labelStyle: TextStyle(
                  color: _selectedDay == day
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

  Widget _buildSlotCard(
      ThemeData theme, TimetableSlotEntry slot, bool isFirst) {
    final scheme = theme.colorScheme;
    final timeLabel = (slot.timeFrom != null && slot.timeTo != null)
        ? '${slot.timeFrom} – ${slot.timeTo}'
        : 'Period ${slot.periodIndex + 1}';

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
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: ScholifyColors.academicNavy.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  '${slot.periodIndex + 1}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: ScholifyColors.academicNavy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.subjectName,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time_outlined,
                          size: 14,
                          color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(timeLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant)),
                      if (slot.teacherName != null) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.person_outlined,
                            size: 14,
                            color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            slot.teacherName!,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (slot.roomNo != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.meeting_room_outlined,
                            size: 14,
                            color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text('Room ${slot.roomNo}',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
