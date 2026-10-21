import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/constants/branding.dart';
import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../../../core/theme/scholify_colors.dart';
import '../../../core/widgets/scholify_empty_state.dart';
import '../../sync/presentation/sync_failure_page.dart';
import '../../plan_upgrade/presentation/plan_upgrade_page.dart';
import '../../branding/presentation/branding_settings_page.dart';
import '../../timetable/data/timetable_repository.dart';
import '../../homework/data/homework_repository.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../family/family_links.dart';

class BootstrapHomePage extends StatelessWidget {
  const BootstrapHomePage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
    this.onSignOut,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([tenantContext, syncEngine]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;

        // Dedicated dashboards for guardian and student roles.
        final role = tenantContext.role.toLowerCase();
        if (role == 'guardian') {
          return _buildGuardianDashboard(context, theme, scheme);
        }
        if (role == 'student') {
          return _buildStudentDashboard(context, theme, scheme);
        }
        if (role == 'teacher') {
          return _buildTeacherDashboard(context, theme, scheme);
        }

        final tenantLabel = tenantContext.hasTenant
            ? '${tenantContext.tenantName} (${tenantContext.role})'
            : 'No active tenant selected';

        final syncState = syncEngine.isSyncing
            ? 'Sync in progress'
            : syncEngine.isBackgroundSyncEnabled
            ? 'Background sync running'
            : 'Background sync stopped';

        final statusCards = [
          _StatusCard(
            icon: Icons.school,
            color: ScholifyColors.academicNavy,
            title: 'Product',
            value: '${AppBranding.appName} (Desktop-first + Web)',
          ),
          _StatusCard(
            icon: Icons.business,
            color: ScholifyColors.scholarTeal,
            title: 'Tenant Context',
            value: tenantLabel,
          ),
          _StatusCard(
            icon: Icons.sync,
            color: ScholifyColors.scholarTeal,
            title: 'Sync State',
            value: syncState,
          ),
          _StatusCard(
            icon: Icons.pending_actions,
            color: ScholifyColors.achievementAmber,
            title: 'Pending Sync Jobs',
            value: '${syncEngine.pendingJobs}',
          ),
        ];

        // No page-level AppBar: the shell already provides the top bar with
        // product branding. The in-page header below is the page title.
        return Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Page header: title + subtitle + sync-failure warning.
                  _buildHeader(context, theme),
                  const SizedBox(height: 20),
                  // Status cards: 2-column grid on wide screens.
                  if (isWide)
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 2.9,
                      children: statusCards,
                    )
                  else
                    Column(
                      children: [
                        for (var i = 0; i < statusCards.length; i++) ...[
                          statusCards[i],
                          if (i < statusCards.length - 1)
                            const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  const SizedBox(height: 28),
                  Text('Quick Actions', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    'Common workspace tasks',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Action cards: 2-column grid on wide screens.
                  if (isWide)
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 2.2,
                      children: [
                        for (final spec in _buildActionSpecs(context))
                          _ActionCard(spec: spec),
                      ],
                    )
                  else
                    Column(
                      children: [
                        for (var i = 0;
                            i < _buildActionSpecs(context).length;
                            i++) ...[
                          _ActionCard(
                              spec: _buildActionSpecs(context)[i]),
                          if (i < _buildActionSpecs(context).length - 1)
                            const SizedBox(height: 12),
                        ],
                      ],
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// Action buttons for common workspace tasks.
  /// Debug/superadmin tools (Set Demo Tenant, Queue Demo Job) are only
  /// visible to superadmins. Regular tenant users see sync controls plus
  /// their own actions (Plan Upgrade, Branding Settings).
  /// Quick action definitions with icons, colors, and handlers.
  /// Returns a list of (_ActionSpec) for the current user role.
  List<_ActionSpec> _buildActionSpecs(BuildContext context) {
    final specs = <_ActionSpec>[];

    // Superadmin-only debug tools.
    if (tenantContext.isSuperAdmin) {
      specs.addAll([
        _ActionSpec(
          icon: Icons.business_outlined,
          color: ScholifyColors.academicNavy,
          title: 'Set Demo Tenant',
          subtitle: 'Switch to demo workspace',
          onTap: () {
            tenantContext.setTenant(
              tenantId: 'school_demo',
              tenantName: 'Demo School',
              role: 'superadmin',
              isSuperAdmin: true,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Demo tenant applied.')),
            );
          },
        ),
        _ActionSpec(
          icon: Icons.playlist_add_outlined,
          color: ScholifyColors.accentOperations,
          title: 'Queue Demo Job',
          subtitle: 'Enqueue test sync op',
          onTap: () async {
            await syncEngine.enqueueOperation(
              entityType: 'tenant_license',
              entityId: DateTime.now().millisecondsSinceEpoch.toString(),
              operation: 'upsert',
              payload: jsonEncode({
                'tenantId': tenantContext.tenantId ?? 'school_demo',
                'plan': 'professional',
                'updatedAt': DateTime.now().toIso8601String(),
              }),
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Demo sync operation queued.'),
                ),
              );
            }
          },
        ),
      ]);
    }

    // Sync controls: visible to everyone.
    specs.addAll([
      _ActionSpec(
        icon: syncEngine.isBackgroundSyncEnabled
            ? Icons.pause_circle_outline
            : Icons.play_circle_outline,
        color: ScholifyColors.scholarTeal,
        title: syncEngine.isBackgroundSyncEnabled
            ? 'Stop Background Sync'
            : 'Start Background Sync',
        subtitle: syncEngine.isBackgroundSyncEnabled
            ? 'Pause automatic syncing'
            : 'Enable automatic syncing',
        onTap: syncEngine.isBackgroundSyncEnabled
            ? syncEngine.stopBackgroundSync
            : syncEngine.startBackgroundSync,
      ),
      _ActionSpec(
        icon: Icons.sync_outlined,
        color: ScholifyColors.info,
        title: 'Run Manual Sync',
        subtitle: 'Sync now with server',
        onTap: syncEngine.manualSync,
      ),
    ]);

    if (!tenantContext.isSuperAdmin) {
      specs.addAll([
        _ActionSpec(
          icon: Icons.upgrade_outlined,
          color: ScholifyColors.achievementAmber,
          title: 'Request Plan Upgrade',
          subtitle: 'Unlock more features',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PlanUpgradePage(
                  tenantContext: tenantContext,
                  syncEngine: syncEngine,
                ),
              ),
            );
          },
        ),
        _ActionSpec(
          icon: Icons.palette_outlined,
          color: ScholifyColors.accentComms,
          title: 'Branding Settings',
          subtitle: 'Logo, colors, name',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BrandingSettingsPage(
                  tenantContext: tenantContext,
                  syncEngine: syncEngine,
                ),
              ),
            );
          },
        ),
      ]);
    }

    final signOut = onSignOut;
    if (signOut != null) {
      specs.add(
        _ActionSpec(
          icon: Icons.logout_outlined,
          color: ScholifyColors.slate600,
          title: 'Sign Out',
          subtitle: 'End this session',
          onTap: () async {
            await signOut.call();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Signed out from this device.'),
                ),
              );
            }
          },
        ),
      );
    }

    return specs;
  }

  /// Dedicated dashboard for guardians: children's overview, attendance,
  /// homework, and fees at a glance.
  Widget _buildGuardianDashboard(
      BuildContext context, ThemeData theme, ColorScheme scheme) {
    final homeworkRepo = HomeworkRepository(
      database: syncEngine.database,
      syncEngine: syncEngine,
      tenantContext: tenantContext,
    );
    final attendanceRepo = AttendanceRepository(
      database: syncEngine.database,
      syncEngine: syncEngine,
      tenantContext: tenantContext,
    );
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildRoleBanner(
            context,
            theme,
            title: 'My Children',
            subtitle: 'Attendance, homework, and fees for your students',
            icon: Icons.family_restroom_outlined,
            badgeLabel: 'Guardian',
          ),
          const SizedBox(height: 20),
          _buildTeacherSectionShell(
            context,
            theme,
            scheme,
            title: 'Children',
            icon: Icons.child_care_outlined,
            color: ScholifyColors.academicNavy,
            child: StreamBuilder<List<StudentDirectoryEntry>>(
              stream: watchLinkedChildren(
                syncEngine.database,
                identity: FamilyIdentity.fromGateway(
                    syncEngine.pocketbaseGateway),
                tenantId: tenantContext.tenantId,
              ),
              builder: (context, snapshot) {
                final students = snapshot.data ?? const [];
                if (students.isEmpty) {
                  return ScholifyEmptyState(
                    icon: Icons.family_restroom_outlined,
                    title: 'No children linked',
                    message:
                        'Contact the school office to link your children to this account.',
                  );
                }
                return Column(
                  children: [
                    for (var i = 0; i < students.length; i++) ...[
                      _buildChildRow(theme, scheme, students[i]),
                      if (i < students.length - 1) const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _buildTeacherSectionShell(
            context,
            theme,
            scheme,
            title: 'Attendance This Month',
            icon: Icons.fact_check_outlined,
            color: ScholifyColors.scholarTeal,
            child: _buildMyAttendanceSummary(theme, scheme, attendanceRepo),
          ),
          const SizedBox(height: 16),
          _buildTeacherSectionShell(
            context,
            theme,
            scheme,
            title: 'Homework Due',
            icon: Icons.assignment_outlined,
            color: ScholifyColors.achievementAmber,
            child: _buildHomeworkDueList(theme, homeworkRepo),
          ),
          const SizedBox(height: 28),
          Text('Quick Actions', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildRoleQuickActions(context, [
            _ActionSpec(
              icon: Icons.calendar_month_outlined,
              color: ScholifyColors.academicNavy,
              title: 'View Timetable',
              subtitle: 'Class schedules',
              onTap: () {},
            ),
            _ActionSpec(
              icon: Icons.notifications_outlined,
              color: ScholifyColors.accentComms,
              title: 'Notices',
              subtitle: 'School announcements',
              onTap: () {},
            ),
            _ActionSpec(
              icon: Icons.logout_outlined,
              color: ScholifyColors.slate600,
              title: 'Sign Out',
              subtitle: 'End this session',
              onTap: () async {
                final signOut = onSignOut;
                if (signOut != null) await signOut.call();
              },
            ),
          ]),
        ],
      ),
    );
  }

  /// Dedicated dashboard for students: today's classes, homework due,
  /// and attendance summary.
  Widget _buildStudentDashboard(
      BuildContext context, ThemeData theme, ColorScheme scheme) {
    final timetableRepo = TimetableRepository(
      database: syncEngine.database,
      syncEngine: syncEngine,
      tenantContext: tenantContext,
    );
    final homeworkRepo = HomeworkRepository(
      database: syncEngine.database,
      syncEngine: syncEngine,
      tenantContext: tenantContext,
    );
    final attendanceRepo = AttendanceRepository(
      database: syncEngine.database,
      syncEngine: syncEngine,
      tenantContext: tenantContext,
    );
    final todayName = _weekdayName(DateTime.now().weekday);
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildRoleBanner(
            context,
            theme,
            title: 'My School Day',
            subtitle: 'Classes, homework, and your progress',
            icon: Icons.backpack_outlined,
            badgeLabel: 'Student',
          ),
          const SizedBox(height: 20),
          _buildTeacherSectionShell(
            context,
            theme,
            scheme,
            title: "Today's Classes",
            icon: Icons.schedule_outlined,
            color: ScholifyColors.academicNavy,
            child: StreamBuilder<List<TimetableSlotEntry>>(
              stream: timetableRepo.watchDaySlots(todayName),
              builder: (context, snapshot) {
                final slots = (snapshot.data ?? const [])
                    .where((s) => s.isActive)
                    .toList()
                  ..sort((a, b) => a.periodIndex.compareTo(b.periodIndex));
                if (slots.isEmpty) {
                  return ScholifyEmptyState(
                    icon: Icons.schedule_outlined,
                    title: 'No classes today',
                    message: 'Your timetable will appear here once published.',
                  );
                }
                return Column(
                  children: [
                    for (var i = 0; i < slots.length; i++) ...[
                      _buildClassRow(theme, scheme, slots[i]),
                      if (i < slots.length - 1) const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _buildTeacherSectionShell(
            context,
            theme,
            scheme,
            title: 'Homework Due',
            icon: Icons.assignment_outlined,
            color: ScholifyColors.achievementAmber,
            child: _buildHomeworkDueList(theme, homeworkRepo),
          ),
          const SizedBox(height: 16),
          _buildTeacherSectionShell(
            context,
            theme,
            scheme,
            title: 'My Attendance',
            icon: Icons.fact_check_outlined,
            color: ScholifyColors.scholarTeal,
            child: _buildMyAttendanceSummary(theme, scheme, attendanceRepo),
          ),
          const SizedBox(height: 28),
          Text('Quick Actions', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildRoleQuickActions(context, [
            _ActionSpec(
              icon: Icons.calendar_month_outlined,
              color: ScholifyColors.academicNavy,
              title: 'My Timetable',
              subtitle: 'Weekly schedule',
              onTap: () {},
            ),
            _ActionSpec(
              icon: Icons.grade_outlined,
              color: ScholifyColors.scholarTeal,
              title: 'My Grades',
              subtitle: 'Results & report cards',
              onTap: () {},
            ),
            _ActionSpec(
              icon: Icons.notifications_outlined,
              color: ScholifyColors.accentComms,
              title: 'Notices',
              subtitle: 'School announcements',
              onTap: () {},
            ),
            _ActionSpec(
              icon: Icons.logout_outlined,
              color: ScholifyColors.slate600,
              title: 'Sign Out',
              subtitle: 'End this session',
              onTap: () async {
                final signOut = onSignOut;
                if (signOut != null) await signOut.call();
              },
            ),
          ]),
        ],
      ),
    );
  }

  /// Dedicated dashboard for teachers: today's classes, attendance to mark,
  /// and homework awaiting review — the daily teaching workflow.
  Widget _buildTeacherDashboard(
      BuildContext context, ThemeData theme, ColorScheme scheme) {
    final timetableRepo = TimetableRepository(
      database: syncEngine.database,
      syncEngine: syncEngine,
      tenantContext: tenantContext,
    );
    final homeworkRepo = HomeworkRepository(
      database: syncEngine.database,
      syncEngine: syncEngine,
      tenantContext: tenantContext,
    );
    final todayName = _weekdayName(DateTime.now().weekday);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildRoleBanner(
            context,
            theme,
            title: 'My Teaching Day',
            subtitle: 'Classes, attendance, and homework to review',
            icon: Icons.menu_book_outlined,
            badgeLabel: 'Teacher',
          ),
          const SizedBox(height: 20),
          _buildTeacherSectionShell(
            context,
            theme,
            scheme,
            title: "Today's Classes",
            icon: Icons.schedule_outlined,
            color: ScholifyColors.academicNavy,
            child: StreamBuilder<List<TimetableSlotEntry>>(
              stream: timetableRepo.watchDaySlots(todayName),
              builder: (context, snapshot) {
                final slots = (snapshot.data ?? const [])
                    .where((s) => s.isActive)
                    .toList()
                  ..sort((a, b) =>
                      a.periodIndex.compareTo(b.periodIndex));
                if (slots.isEmpty) {
                  return ScholifyEmptyState(
                    icon: Icons.schedule_outlined,
                    title: 'No classes today',
                    message:
                        'Your timetable for today will appear here once published.',
                  );
                }
                return Column(
                  children: [
                    for (var i = 0; i < slots.length; i++) ...[
                      _buildClassRow(theme, scheme, slots[i]),
                      if (i < slots.length - 1)
                        const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _buildDashboardSection(
            context,
            theme,
            scheme,
            title: 'Attendance to Mark',
            icon: Icons.fact_check_outlined,
            color: ScholifyColors.scholarTeal,
            emptyTitle: 'All caught up',
            emptyMessage:
                'Mark attendance from the Attendance page for today\u2019s classes.',
          ),
          const SizedBox(height: 16),
          _buildTeacherSectionShell(
            context,
            theme,
            scheme,
            title: 'Homework to Review',
            icon: Icons.rate_review_outlined,
            color: ScholifyColors.achievementAmber,
            child: StreamBuilder<List<HomeworkAssignmentEntry>>(
              stream: homeworkRepo.watchAssignments(),
              builder: (context, snapshot) {
                final items = (snapshot.data ?? const [])
                    .where((a) => a.isActive && a.isPublished)
                    .toList();
                if (items.isEmpty) {
                  return ScholifyEmptyState(
                    icon: Icons.rate_review_outlined,
                    title: 'Nothing to review',
                    message:
                        'Student submissions awaiting your feedback will appear here.',
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${items.length} active assignment${items.length == 1 ? '' : 's'}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0;
                        i < items.length && i < 3;
                        i++) ...[
                      _buildAssignmentRow(theme, items[i]),
                      if (i < 2 && i < items.length - 1)
                        const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 28),
          Text('Quick Actions', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildRoleQuickActions(context, [
            _ActionSpec(
              icon: Icons.fact_check_outlined,
              color: ScholifyColors.scholarTeal,
              title: 'Mark Attendance',
              subtitle: "Today's classes",
              onTap: () {},
            ),
            _ActionSpec(
              icon: Icons.add_task_outlined,
              color: ScholifyColors.academicNavy,
              title: 'New Homework',
              subtitle: 'Create assignment',
              onTap: () {},
            ),
            _ActionSpec(
              icon: Icons.calendar_month_outlined,
              color: ScholifyColors.academicNavy,
              title: 'My Timetable',
              subtitle: 'Weekly schedule',
              onTap: () {},
            ),
            _ActionSpec(
              icon: Icons.notifications_outlined,
              color: ScholifyColors.accentComms,
              title: 'Notices',
              subtitle: 'School announcements',
              onTap: () {},
            ),
            _ActionSpec(
              icon: Icons.logout_outlined,
              color: ScholifyColors.slate600,
              title: 'Sign Out',
              subtitle: 'End this session',
              onTap: () async {
                final signOut = onSignOut;
                if (signOut != null) await signOut.call();
              },
            ),
          ]),
        ],
      ),
    );
  }

  /// Section shell that takes a live child instead of an empty state.
  /// Live homework list shared by the guardian/student dashboards: published,
  /// active assignments sorted by due date, soonest first (max 3 shown).
  Widget _buildHomeworkDueList(ThemeData theme, HomeworkRepository repo) {
    return StreamBuilder<List<HomeworkAssignmentEntry>>(
      stream: repo.watchAssignments(),
      builder: (context, snapshot) {
        final items = (snapshot.data ?? const [])
            .where((a) => a.isActive && a.isPublished)
            .toList()
          ..sort((a, b) {
            final ad = a.dueDate ?? DateTime(9999);
            final bd = b.dueDate ?? DateTime(9999);
            return ad.compareTo(bd);
          });
        if (items.isEmpty) {
          return ScholifyEmptyState(
            icon: Icons.assignment_outlined,
            title: 'No homework due',
            message: 'All caught up! New assignments will appear here.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < items.length && i < 3; i++) ...[
              _buildAssignmentRow(theme, items[i]),
              if (i < 2 && i < items.length - 1) const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }

  /// Attendance summary for the first linked student (current month):
  /// percentage plus present/absent/late counts. Used by both the student
  /// ("My Attendance") and guardian dashboards.
  /// Attendance summary for the family dashboards: the guardian's
  /// selected (or primary) linked child, or the student's own record.
  /// Resolution goes through the family link directory — never the
  /// first student in the school directory.
  Widget _buildMyAttendanceSummary(
      ThemeData theme, ColorScheme scheme, AttendanceRepository repo) {
    final identity = FamilyIdentity.fromGateway(syncEngine.pocketbaseGateway);
    final role = tenantContext.role.toLowerCase();
    if (role == 'student') {
      return StreamBuilder<StudentDirectoryEntry?>(
        stream: watchOwnStudentRecord(
          syncEngine.database,
          identity: identity,
          tenantId: tenantContext.tenantId,
        ),
        builder: (context, snapshot) {
          final student = snapshot.data;
          if (student == null) {
            return ScholifyEmptyState(
              icon: Icons.fact_check_outlined,
              title: 'No attendance records',
              message:
                  'Attendance will appear here once the school marks it.',
            );
          }
          return _buildAttendanceSummaryFor(theme, scheme, repo, student);
        },
      );
    }
    // Guardian (and any other family role): linked children + selection.
    return StreamBuilder<List<StudentDirectoryEntry>>(
      stream: watchLinkedChildren(
        syncEngine.database,
        identity: identity,
        tenantId: tenantContext.tenantId,
      ),
      builder: (context, studentSnapshot) {
        final children = studentSnapshot.data ?? const [];
        if (children.isEmpty) {
          return ScholifyEmptyState(
            icon: Icons.fact_check_outlined,
            title: 'No attendance records',
            message: 'Attendance will appear here once the school marks it.',
          );
        }
        return ValueListenableBuilder<String?>(
          valueListenable: FamilyChildSelection.selectedStudentId,
          builder: (context, _, _) {
            final child = effectiveChild(children)!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (children.length > 1) ...[
                  FamilyChildSwitcher(children: children),
                  const SizedBox(height: 12),
                ],
                _buildAttendanceSummaryFor(theme, scheme, repo, child),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAttendanceSummaryFor(
    ThemeData theme,
    ColorScheme scheme,
    AttendanceRepository repo,
    StudentDirectoryEntry child,
  ) {
    return StreamBuilder<List<StudentAttendanceRecord>>(
      stream: repo.watchStudentMonth(
        studentId: child.id,
        month: DateTime.now(),
      ),
      builder: (context, snapshot) {
        final records = snapshot.data ?? const [];
        if (records.isEmpty) {
          return ScholifyEmptyState(
            icon: Icons.fact_check_outlined,
            title: 'No attendance records',
            message:
                'Attendance will appear here once the school marks it.',
          );
        }
        final present = records.where((r) => r.status == 'present').length;
        final absent = records.where((r) => r.status == 'absent').length;
        final late = records.where((r) => r.status == 'late').length;
        final pct = (present / records.length * 100).round();
        return Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: ScholifyColors.scholarTeal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  '$pct%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: ScholifyColors.scholarTeal,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child.fullName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$present present \u00b7 $absent absent \u00b7 $late late this month',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChildRow(
      ThemeData theme, ColorScheme scheme, StudentDirectoryEntry student) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: ScholifyColors.academicNavy.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.child_care_outlined,
                size: 20, color: ScholifyColors.academicNavy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (student.classSection?.isNotEmpty ?? false)
                  Text(
                    student.classSection!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherSectionShell(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme, {
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  /// Single class row for the teacher's today list.
  Widget _buildClassRow(
      ThemeData theme, ColorScheme scheme, TimetableSlotEntry slot) {
    final time = [
      if (slot.timeFrom != null) slot.timeFrom!,
      if (slot.timeTo != null) slot.timeTo!,
    ].join(' \u2013 ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: ScholifyColors.academicNavy.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                'P${slot.periodIndex + 1}',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: ScholifyColors.academicNavy,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.subjectName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (time.isNotEmpty ||
                    (slot.roomNo?.isNotEmpty ?? false))
                  Text(
                    [
                      if (time.isNotEmpty) time,
                      if (slot.roomNo?.isNotEmpty ?? false)
                        'Room ${slot.roomNo}',
                    ].join(' \u00b7 '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (slot.classSection?.isNotEmpty ?? false)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:
                    ScholifyColors.scholarTeal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                slot.classSection!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: ScholifyColors.scholarTeal,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Single assignment row for the review list.
  Widget _buildAssignmentRow(
      ThemeData theme, HomeworkAssignmentEntry assignment) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.assignment_outlined,
            color: ScholifyColors.achievementAmber,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              assignment.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Maps DateTime weekday (1=Mon .. 7=Sun) to the timetable day names.
  String _weekdayName(int weekday) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[(weekday - 1).clamp(0, 6)];
  }

  /// Gradient welcome banner for role-specific dashboards.
  Widget _buildRoleBanner(
    BuildContext context,
    ThemeData theme, {
    required String title,
    required String subtitle,
    required IconData icon,
    required String badgeLabel,
  }) {
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
                  'Welcome back',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tenantContext.tenantName ?? 'Scholify',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    badgeLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
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
            child: Icon(icon, color: Colors.white, size: 36),
          ),
        ],
      ),
    );
  }

  /// A dashboard section card with title header and empty state.
  Widget _buildDashboardSection(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme, {
    required String title,
    required IconData icon,
    required Color color,
    required String emptyTitle,
    required String emptyMessage,
  }) {
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ScholifyEmptyState(
              icon: icon,
              title: emptyTitle,
              message: emptyMessage,
            ),
          ],
        ),
      ),
    );
  }

  /// Quick action cards grid for role dashboards.
  Widget _buildRoleQuickActions(
      BuildContext context, List<_ActionSpec> specs) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        if (isWide) {
          return GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: [for (final spec in specs) _ActionCard(spec: spec)],
          );
        }
        return Column(
          children: [
            for (var i = 0; i < specs.length; i++) ...[
              _ActionCard(spec: specs[i]),
              if (i < specs.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  /// Page header with welcome banner for the dashboard.
  Widget _buildHeader(BuildContext context, ThemeData theme) {
    final tenantName = tenantContext.tenantName ?? 'Scholify';
    final roleLabel = tenantContext.isSuperAdmin
        ? 'Superadmin'
        : tenantContext.role.replaceAll('_', ' ').split(' ').map((w) =>
            w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome banner with gradient
        Container(
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
                      'Welcome back',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tenantName,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            tenantContext.isSuperAdmin
                                ? Icons.admin_panel_settings_outlined
                                : Icons.business_outlined,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            roleLabel,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Sync failure badge (if any)
              StreamBuilder<List<dynamic>>(
                stream: syncEngine.database.watchFailedSyncEntries(),
                builder: (context, snapshot) {
                  final failedCount = snapshot.data?.length ?? 0;
                  if (failedCount == 0) {
                    return Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.school_outlined,
                        color: Colors.white,
                        size: 36,
                      ),
                    );
                  }
                  return Container(
                    decoration: BoxDecoration(
                      color: ScholifyColors.error.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      icon: Badge(
                        label: Text('$failedCount'),
                        backgroundColor: Colors.white,
                        textColor: ScholifyColors.error,
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                        ),
                      ),
                      tooltip: 'Sync Failures ($failedCount)',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SyncFailurePage(),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A polished status card: gradient icon medallion + label + value,
/// 16px radius with a subtle border.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, color.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Specification for a quick action card.
class _ActionSpec {
  const _ActionSpec({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

/// A polished quick action card: icon medallion + title + subtitle,
/// 16px radius with subtle border and hover effect.
class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.spec});

  final _ActionSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: spec.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: spec.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(spec.icon, color: spec.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      spec.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      spec.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
