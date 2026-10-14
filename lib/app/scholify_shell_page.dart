import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/access/module_access_policy.dart';
import '../core/database/local_database.dart';
import '../core/services/audit_log_service.dart';
import '../core/services/impersonation_service.dart';
import '../core/services/license_alert_service.dart';
import '../core/services/seat_limit_enforcement_service.dart';
import '../core/sync/sync_engine.dart';
import '../core/tenant/tenant_context.dart';
import '../core/theme/theme_controller.dart';
import '../core/theme/scholify_colors.dart';
import '../features/impersonation/presentation/impersonation_banner.dart';
import '../features/attendance/presentation/attendance_overview_page.dart';
import '../features/bootstrap/presentation/bootstrap_home_page.dart';
import '../features/curriculum/presentation/curriculum_page.dart';
import '../features/documents/presentation/document_center_page.dart';
import '../features/exams/presentation/exam_overview_page.dart';
import '../features/hostel/presentation/hostel_page.dart';
import '../features/leave/presentation/leave_requests_page.dart';
import '../features/fees/presentation/fee_overview_page.dart';
import '../features/notices/presentation/notice_board_page.dart';
import '../features/homework/presentation/homework_assignments_page.dart';
import '../features/library/presentation/library_page.dart';
import '../features/live_classes/presentation/live_classes_page.dart';
import '../features/student_behaviour/presentation/student_behaviour_page.dart';
import '../features/teachers/presentation/teachers_page.dart';
import '../features/online_learning/presentation/online_learning_page.dart';
import '../features/notifications/presentation/notification_center_page.dart';
import '../features/pending_tasks/presentation/pending_tasks_page.dart';
import '../features/students/presentation/student_class_roll_page.dart';
import '../features/students/presentation/student_guardians_page.dart';
import '../features/students/presentation/student_enrollment_page.dart';
import '../features/students/presentation/student_directory_page.dart';
import '../features/superadmin/presentation/superadmin_dashboard_page.dart';
import '../features/timetable/presentation/timetable_overview_page.dart';
import '../features/transport/presentation/transport_routes_page.dart';
import '../features/visitor_communication/presentation/visitor_communication_page.dart';

class ScholifyShellPage extends StatefulWidget {
  const ScholifyShellPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
    this.onSignOut,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;
  final Future<void> Function()? onSignOut;

  @override
  State<ScholifyShellPage> createState() => _ScholifyShellPageState();
}

class _ScholifyShellPageState extends State<ScholifyShellPage> {
  int _selectedIndex = 0;
  late final ImpersonationService _impersonationService;
  final TextEditingController _navSearchController = TextEditingController();
  String _navSearchQuery = '';
  // All sections start expanded; user can collapse them.
  final Set<_ShellSection> _expandedSections = Set.of(_ShellSection.values);

  @override
  void initState() {
    super.initState();
    _impersonationService = ImpersonationService(
      tenantContext: widget.tenantContext,
      auditLogService: AuditLogService(
        database: widget.syncEngine.database,
        tenantContext: widget.tenantContext,
        gateway: widget.syncEngine.pocketbaseGateway,
      ),
    );
    _impersonationService.addListener(_onImpersonationChanged);
    // Load persisted branding into TenantContext so the app bar reflects it
    // immediately on shell mount (B3.3, B3.4, B3.5, B3.6)
    _loadBrandingIntoContext();
  }

  /// Loads the tenant's branding from the local DB and seeds TenantContext.
  Future<void> _loadBrandingIntoContext() async {
    final tenantId = widget.tenantContext.tenantId;
    if (tenantId == null || tenantId.isEmpty) return;
    try {
      final branding = await (widget.syncEngine.database
              .select(widget.syncEngine.database.tenantBrandingEntries)
            ..where((tbl) => tbl.tenantId.equals(tenantId))
            ..limit(1))
          .getSingleOrNull();
      if (!mounted) return;
      widget.tenantContext.setBranding(
        displayName: branding?.displayName,
        logoBase64: branding?.logoBase64,
      );
    } catch (_) {
      // Non-fatal: branding will just show defaults
    }
  }

  @override
  void dispose() {
    _impersonationService.removeListener(_onImpersonationChanged);
    _navSearchController.dispose();
    super.dispose();
  }

  void _onImpersonationChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tenantContext.isSuperAdmin || !widget.tenantContext.hasTenant) {
      final access = ModuleAccessPolicy.resolve(
        planCode: 'enterprise',
        overrides: const <String, bool>{},
        isSuperAdmin: true,
      );
      return _buildShellForAccess(access);
    }

    final activeTenantId = widget.tenantContext.tenantId!;

    return StreamBuilder<List<TenantLicenseView>>(
      stream: widget.syncEngine.database.watchTenantLicenseViews(),
      builder: (context, licenseSnapshot) {
        if (licenseSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final licenses = licenseSnapshot.data ?? const <TenantLicenseView>[];
        final tenantLicense = _tenantLicenseFor(licenses, activeTenantId);

        return StreamBuilder<List<TenantFeatureFlagEntry>>(
          stream: widget.syncEngine.database.watchTenantFeatureFlags(
            tenantId: activeTenantId,
          ),
          builder: (context, flagSnapshot) {
            if (flagSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final flags = flagSnapshot.data ?? const <TenantFeatureFlagEntry>[];
            final overrides = <String, bool>{
              for (final row in flags) row.featureKey: row.isEnabled,
            };

            final access = ModuleAccessPolicy.resolve(
              planCode: tenantLicense?.planCode,
              overrides: overrides,
              isSuperAdmin: false,
            );

            return _buildShellForAccess(access);
          },
        );
      },
    );
  }

  TenantLicenseView? _tenantLicenseFor(
    List<TenantLicenseView> licenses,
    String tenantId,
  ) {
    for (final license in licenses) {
      if (license.tenantId == tenantId) {
        return license;
      }
    }
    return null;
  }

  Widget _buildShellForAccess(Map<String, bool> access) {
    final destinations = <_ShellDestination>[
      _ShellDestination(
        label: 'Foundation',
        icon: Icons.dashboard_customize,
        page: BootstrapHomePage(
          tenantContext: widget.tenantContext,
          syncEngine: widget.syncEngine,
          onSignOut: widget.onSignOut,
        ),
        section: _ShellSection.foundation
      ),
      if (widget.tenantContext.isSuperAdmin)
        _ShellDestination(
          label: 'Superadmin',
          icon: Icons.admin_panel_settings,
          page: SuperadminDashboardPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
            licenseAlertService: LicenseAlertService(
              database: widget.syncEngine.database,
            ),
          ),
        section: _ShellSection.administration
      ),
      if (access[ScholifyModuleFeature.students] ?? false)
        _ShellDestination(
          label: 'Students',
          icon: Icons.groups,
          page: StudentDirectoryPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        section: _ShellSection.academics
      ),
      if (access[ScholifyModuleFeature.guardians] ?? false)
        _ShellDestination(
          label: 'Guardians',
          icon: Icons.family_restroom,
          page: StudentGuardiansPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        section: _ShellSection.academics
      ),
      if (access[ScholifyModuleFeature.enrollment] ?? false)
        _ShellDestination(
          label: 'Enrollment',
          icon: Icons.assignment_ind,
          page: StudentEnrollmentPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
            seatLimitEnforcementService: SeatLimitEnforcementService(
              database: widget.syncEngine.database,
            ),
          ),
        section: _ShellSection.academics
      ),
      if (access[ScholifyModuleFeature.classRoll] ?? false)
        _ShellDestination(
          label: 'Class Roll',
          icon: Icons.format_list_numbered,
          page: StudentClassRollPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        section: _ShellSection.academics
      ),
      if (access[ScholifyModuleFeature.leaveRequests] ?? false)
        _ShellDestination(
          label: 'Leave',
          icon: Icons.event_busy,
          page: LeaveRequestsPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        section: _ShellSection.operations
      ),
      if (access[ScholifyModuleFeature.pendingTasks] ?? false)
        _ShellDestination(
          label: 'Tasks',
          icon: Icons.checklist,
          page: PendingTasksPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        section: _ShellSection.operations
      ),
      if (access[ScholifyModuleFeature.hostel] ?? false)
        _ShellDestination(
          label: 'Hostel',
          icon: Icons.bed,
          page: HostelPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        section: _ShellSection.operations
      ),
      if (access[ScholifyModuleFeature.fees] ?? false)
        _ShellDestination(
          label: 'Fees',
          icon: Icons.receipt_long,
          page: FeeOverviewPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        section: _ShellSection.operations
      ),
      if (access[ScholifyModuleFeature.attendance] ?? false)
        _ShellDestination(
          label: 'Attendance',
          icon: Icons.fact_check,
          page: AttendanceOverviewPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        section: _ShellSection.academics
      ),
      if (access[ScholifyModuleFeature.exams] ?? false)
        _ShellDestination(
          label: 'Exams',
          icon: Icons.quiz,
          page: ExamOverviewPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        section: _ShellSection.academics
      ),
      if (access[ScholifyModuleFeature.notices] ?? false)
        _ShellDestination(
          label: 'Notices',
          icon: Icons.campaign,
          page: NoticeBoardPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        section: _ShellSection.operations
      ),
      if (access[ScholifyModuleFeature.timetable] ?? false)
        _ShellDestination(
          label: 'Timetable',
          icon: Icons.view_week,
          page: TimetableOverviewPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        section: _ShellSection.academics
      ),
      if (access[ScholifyModuleFeature.transport] ?? false)
        _ShellDestination(
          label: 'Transport',
          icon: Icons.directions_bus,
          page: TransportRoutesPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        section: _ShellSection.operations
      ),
      if (access[ScholifyModuleFeature.homework] ?? false)
        _ShellDestination(
          label: 'Homework',
          icon: Icons.assignment,
          page: HomeworkAssignmentsPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        section: _ShellSection.academics
      ),
      if (access[ScholifyModuleFeature.onlineLearning] ?? false)
        _ShellDestination(
          label: 'Online Learning',
          icon: Icons.play_lesson,
          page: OnlineLearningPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        section: _ShellSection.academics
      ),
      if (access[ScholifyModuleFeature.curriculum] ?? false)
        _ShellDestination(
          label: 'Curriculum',
          icon: Icons.menu_book,
          page: CurriculumPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        section: _ShellSection.academics
      ),
      if (access[ScholifyModuleFeature.library] ?? false)
        _ShellDestination(
          label: 'Library',
          icon: Icons.local_library,
          page: LibraryPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        section: _ShellSection.academics
      ),
      if (access[ScholifyModuleFeature.documentCenter] ?? false)
        _ShellDestination(
          label: 'Documents',
          icon: Icons.folder_copy_outlined,
          page: DocumentCenterPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        section: _ShellSection.operations
      ),
      if (access[ScholifyModuleFeature.visitorCommunication] ?? false)
        _ShellDestination(
          label: 'Visitors',
          icon: Icons.badge_outlined,
          page: VisitorCommunicationPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        section: _ShellSection.operations
      ),
      if (access[ScholifyModuleFeature.notifications] ?? false)
        _ShellDestination(
          label: 'Notifications',
          icon: Icons.notifications_active_outlined,
          page: NotificationCenterPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        section: _ShellSection.administration
      ),
      if (access[ScholifyModuleFeature.liveClasses] ?? false)
        _ShellDestination(
          label: 'Live Classes',
          icon: Icons.videocam_outlined,
          page: LiveClassesPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        section: _ShellSection.academics
      ),
      if (access[ScholifyModuleFeature.teachers] ?? false)
        _ShellDestination(
          label: 'Teachers',
          icon: Icons.people_outline,
          page: TeachersPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        section: _ShellSection.academics
      ),
      if (access[ScholifyModuleFeature.studentBehaviour] ?? false)
        _ShellDestination(
          label: 'Behaviour',
          icon: Icons.psychology_outlined,
          page: StudentBehaviourPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        section: _ShellSection.academics
      ),
    ];

    final maxIndex = destinations.length - 1;
    final activeIndex = _selectedIndex > maxIndex ? maxIndex : _selectedIndex;
    if (_selectedIndex != activeIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedIndex = activeIndex;
        });
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        if (!isWide) {
          // Mobile: hamburger drawer with grouped, searchable navigation.
          // A bottom bar cannot fit 25 destinations.
          return Scaffold(
            appBar: _buildBrandingAppBar(compact: true),
            drawer: Drawer(
              child: _buildGroupedNav(context, destinations, activeIndex,
                  inDrawer: true),
            ),
            body: Column(
              children: [
                ImpersonationBanner(
                  impersonationService: _impersonationService,
                ),
                Expanded(child: destinations[activeIndex].page),
              ],
            ),
          );
        }

        // Desktop: grouped sidebar with search + collapsible sections.
        return Scaffold(
          appBar: _buildBrandingAppBar(compact: false),
          body: Column(
            children: [
              ImpersonationBanner(
                impersonationService: _impersonationService,
              ),
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 280,
                      child: _buildGroupedNav(
                          context, destinations, activeIndex),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: destinations[activeIndex].page),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds the grouped, searchable navigation used by both the desktop
  /// sidebar and the mobile drawer.
  Widget _buildGroupedNav(
    BuildContext context,
    List<_ShellDestination> destinations,
    int activeIndex, {
    bool inDrawer = false,
  }) {
    final theme = Theme.of(context);
    final query = _navSearchQuery.trim().toLowerCase();

    // Filter destinations by the search query.
    List<_ShellDestination> visible = destinations;
    int? remappedActive;
    if (query.isNotEmpty) {
      visible = [];
      for (var i = 0; i < destinations.length; i++) {
        if (destinations[i].label.toLowerCase().contains(query)) {
          if (i == activeIndex) remappedActive = visible.length;
          visible.add(destinations[i]);
        }
      }
    }

    void select(int index) {
      // Map the visible index back to the full destinations list.
      final target = visible[index];
      final fullIndex = destinations.indexOf(target);
      setState(() {
        _selectedIndex = fullIndex;
      });
      if (inDrawer) Navigator.of(context).pop();
    }

    final currentVisibleActive =
        remappedActive ?? (query.isEmpty ? activeIndex : -1);

    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          // Search filter
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _navSearchController,
              decoration: InputDecoration(
                hintText: 'Search modules…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _navSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _navSearchController.clear();
                          setState(() => _navSearchQuery = '');
                        },
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) => setState(() => _navSearchQuery = v),
            ),
          ),
          // Grouped destinations
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No modules match "$_navSearchQuery".',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      for (final section in _ShellSection.values)
                        _buildNavSection(
                          context,
                          section,
                          visible,
                          currentVisibleActive,
                          select,
                          searching: query.isNotEmpty,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// A single collapsible navigation section.
  Widget _buildNavSection(
    BuildContext context,
    _ShellSection section,
    List<_ShellDestination> visible,
    int currentVisibleActive,
    void Function(int) select, {
    required bool searching,
  }) {
    // Collect (visibleIndex, destination) pairs for this section.
    final items = <MapEntry<int, _ShellDestination>>[];
    for (var i = 0; i < visible.length; i++) {
      if (visible[i].section == section) items.add(MapEntry(i, visible[i]));
    }
    if (items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    // While searching, force-expand so matches are visible.
    final expanded = searching || _expandedSections.contains(section);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: searching
              ? null
              : () => setState(() {
                    if (expanded) {
                      _expandedSections.remove(section);
                    } else {
                      _expandedSections.add(section);
                    }
                  }),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(section.icon,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    section.label.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                Text(
                  '${items.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (!searching)
                  Icon(
                    expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
        if (expanded)
          for (final entry in items)
            _buildNavTile(
              context,
              entry.value,
              selected: entry.key == currentVisibleActive,
              onTap: () => select(entry.key),
            ),
        const SizedBox(height: 4),
      ],
    );
  }

  /// A single navigation tile with a selected indicator.
  Widget _buildNavTile(
    BuildContext context,
    _ShellDestination destination, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primary
                        : scheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    destination.icon,
                    size: 20,
                    color: selected
                        ? scheme.onPrimary
                        : scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    destination.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: selected
                          ? scheme.primary
                          : scheme.onSurface,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the app bar with tenant branding (B3.3, B3.4, B3.5, B3.6).
  /// Shows tenant logo (if configured) and display name (if configured),
  /// falling back to the default Scholify icon and name.
  PreferredSizeWidget _buildBrandingAppBar({required bool compact}) {
    final logoBase64 = widget.tenantContext.brandingLogoBase64;
    // In superadmin mode the top-left brand is always the Scholify product
    // identity, not the "Global Superadmin" context label.
    final displayName = widget.tenantContext.isSuperAdmin
        ? 'Scholify'
        : (widget.tenantContext.brandingDisplayName ??
            widget.tenantContext.tenantName ??
            'Scholify');

    Widget leadingLogo;
    if (logoBase64 != null && logoBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(logoBase64);
        leadingLogo = Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Image.memory(bytes, fit: BoxFit.contain),
        );
      } catch (_) {
        leadingLogo = const Icon(Icons.school);
      }
    } else {
      leadingLogo = const Icon(Icons.school);
    }

    // Stylish Scholify wordmark: two-tone with tight tracking.
    // Regular tenants keep their plain school name.
    final Widget titleWidget;
    if (widget.tenantContext.isSuperAdmin) {
      titleWidget = RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            height: 1.0,
          ),
          children: [
            const TextSpan(
              text: 'Scholi',
              style: TextStyle(color: Colors.white),
            ),
            TextSpan(
              text: 'fy',
              style:
                  TextStyle(color: ScholifyColors.achievementAmber),
            ),
          ],
        ),
      );
    } else {
      titleWidget = Text(
        displayName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      );
    }

    return AppBar(
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: leadingLogo,
      ),
      title: titleWidget,
      centerTitle: false,
      actions: [
        // Dark mode toggle
        ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeController.mode,
          builder: (context, mode, _) {
            final isDark = mode == ThemeMode.dark;
            return IconButton(
              tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
              onPressed: ThemeController.toggle,
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            );
          },
        ),
      ],
    );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.page,
    required this.section,
  });

  final String label;
  final IconData icon;
  final Widget page;
  final _ShellSection section;
}

/// Sidebar sections for grouping the 25 navigation destinations.
enum _ShellSection {
  foundation('Foundation', Icons.home),
  academics('Academics', Icons.school),
  operations('Operations', Icons.business_center),
  administration('Administration', Icons.admin_panel_settings);

  const _ShellSection(this.label, this.icon);

  final String label;
  final IconData icon;
}
