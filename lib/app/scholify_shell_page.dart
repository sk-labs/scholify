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
import '../features/attendance/presentation/guardian_attendance_page.dart';
import '../features/timetable/presentation/guardian_timetable_page.dart';
import '../features/homework/presentation/guardian_homework_page.dart';
import '../features/profile/presentation/guardian_profile_page.dart';
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
  bool _showingProfile = false;
  bool _familyLandingApplied = false;
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
    // Check if guardian/student needs to complete their profile on first login.
    _checkProfileCompletion();
  }

  /// Shows a blocking profile-completion dialog for guardians/students
  /// logging in for the first time (profile_completed = false).
  Future<void> _checkProfileCompletion() async {
    if (!_isFamilyRole()) return;
    try {
      final gateway = widget.syncEngine.pocketbaseGateway;
      final authModel = gateway.client.authStore.model;
      final userId = authModel?.id;
      if (userId == null || userId.isEmpty) return;
      final record =
          await gateway.client.collection('users').getOne(userId);
      final completed = record.getBoolValue('profile_completed');
      if (!completed && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showProfileCompletionDialog();
        });
      }
    } catch (_) {
      // If we can't check, don't block the user.
    }
  }

  /// Blocking dialog that forces profile completion before using the panel.
  /// Contains the profile form directly — guardian must complete it to proceed.
  void _showProfileCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Cannot dismiss by tapping outside.
      builder: (context) => PopScope(
        canPop: false, // Cannot dismiss with back button.
        child: Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            width: 500,
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        ScholifyColors.academicNavy,
                        ScholifyColors.scholarTeal.withValues(alpha: 0.85),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_add_outlined,
                          color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Complete Your Profile',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            Text(
                              'Required before using the panel',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.white
                                        .withValues(alpha: 0.8),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _ProfileCompletionForm(
                      syncEngine: widget.syncEngine,
                      onCompleted: () {
                        Navigator.pop(context);
                        if (mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Profile completed. Welcome!'),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
              role: widget.tenantContext.role,
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

  /// Returns true if the current user is a guardian or student.
  bool _isFamilyRole() {
    final role = widget.tenantContext.role.toLowerCase();
    return role == 'guardian' || role == 'student';
  }

  bool _isTeacherRole() {
    return widget.tenantContext.role.toLowerCase() == 'teacher';
  }

  /// Returns the timetable page appropriate for the current user's role.
  Widget _timetablePageForRole() {
    final role = widget.tenantContext.role.toLowerCase();
    if (role == 'guardian' || role == 'student') {
      return GuardianTimetablePage(
        tenantContext: widget.tenantContext,
        syncEngine: widget.syncEngine,
      );
    }
    return TimetableOverviewPage(
      tenantContext: widget.tenantContext,
      syncEngine: widget.syncEngine,
    );
  }

  /// Returns the homework page appropriate for the current user's role.
  Widget _homeworkPageForRole() {
    final role = widget.tenantContext.role.toLowerCase();
    if (role == 'guardian' || role == 'student') {
      return GuardianHomeworkPage(
        tenantContext: widget.tenantContext,
        syncEngine: widget.syncEngine,
      );
    }
    return HomeworkAssignmentsPage(
      tenantContext: widget.tenantContext,
      syncEngine: widget.syncEngine,
    );
  }

  /// Returns the attendance page appropriate for the current user's role.
  /// Guardians get analytics; teachers/staff get the marking interface.
  Widget _attendancePageForRole() {
    final role = widget.tenantContext.role.toLowerCase();
    if (role == 'guardian' || role == 'student') {
      return GuardianAttendancePage(
        tenantContext: widget.tenantContext,
        syncEngine: widget.syncEngine,
      );
    }
    return AttendanceOverviewPage(
      tenantContext: widget.tenantContext,
      syncEngine: widget.syncEngine,
    );
  }

  Widget _buildShellForAccess(Map<String, bool> access) {
    final destinations = <_ShellDestination>[
      _ShellDestination(
        label: 'Foundation',
        icon: Icons.dashboard_customize,
        color: ScholifyColors.academicNavy,
        page: BootstrapHomePage(
          tenantContext: widget.tenantContext,
          syncEngine: widget.syncEngine,
          onSignOut: widget.onSignOut,
        ),
        section: _ShellSection.foundation
      ),      if (widget.tenantContext.isSuperAdmin)
        _ShellDestination(
          label: 'Superadmin',
          icon: Icons.admin_panel_settings,
        color: ScholifyColors.accentAdmin,
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
        color: ScholifyColors.accentStudents,
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
        color: ScholifyColors.info,
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
        color: ScholifyColors.achievementAmber,
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
        color: ScholifyColors.accentAcademics,
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
        color: ScholifyColors.warning,
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
        color: ScholifyColors.accentOperations,
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
        color: ScholifyColors.academicNavy,
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
        color: ScholifyColors.accentFinance,
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
        color: ScholifyColors.success,
          page: _attendancePageForRole(),
        section: _ShellSection.academics
      ),
      if (access[ScholifyModuleFeature.exams] ?? false)
        _ShellDestination(
          label: 'Exams',
          icon: Icons.quiz,
        color: ScholifyColors.academicNavy,
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
        color: ScholifyColors.achievementAmber,
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
        color: ScholifyColors.scholarTeal,
          page: _timetablePageForRole(),
        section: _ShellSection.academics
      ),
      if (access[ScholifyModuleFeature.transport] ?? false)
        _ShellDestination(
          label: 'Transport',
          icon: Icons.directions_bus,
        color: ScholifyColors.info,
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
        color: ScholifyColors.achievementAmber,
          page: _homeworkPageForRole(),
        section: _ShellSection.academics
      ),
      if (access[ScholifyModuleFeature.onlineLearning] ?? false)
        _ShellDestination(
          label: 'Online Learning',
          icon: Icons.play_lesson,
        color: ScholifyColors.accentComms,
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
        color: ScholifyColors.academicNavy,
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
        color: ScholifyColors.amberSoft,
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
        color: ScholifyColors.slate600,
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
        color: ScholifyColors.accentComms,
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
        color: ScholifyColors.error,
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
        color: ScholifyColors.error,
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
        color: ScholifyColors.accentAcademics,
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
        color: ScholifyColors.accentOperations,
          page: StudentBehaviourPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        section: _ShellSection.academics
      ),
    ];

    // For guardians/students/teachers, Foundation sits last in the sidebar
    // (just above the pinned My Profile tile for family roles) — but stays
    // the landing page. It's moved to the end of the list and into the
    // Operations section (the last grouped section).
    if (_isFamilyRole() || _isTeacherRole()) {
      final foundationIdx =
          destinations.indexWhere((d) => d.label == 'Foundation');
      if (foundationIdx != -1) {
        final foundation = destinations.removeAt(foundationIdx);
        destinations.add(
          _ShellDestination(
            label: foundation.label,
            icon: foundation.icon,
            color: foundation.color,
            page: foundation.page,
            section: _ShellSection.operations,
          ),
        );
        if (!_familyLandingApplied) {
          _familyLandingApplied = true;
          _selectedIndex = destinations.length - 1;
        }
      }
    }

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
                Expanded(
                  child: _showingProfile && _isFamilyRole()
                      ? GuardianProfilePage(
                          tenantContext: widget.tenantContext,
                          syncEngine: widget.syncEngine,
                        )
                      : destinations[activeIndex].page,
                ),
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
                    Expanded(
                      child: _showingProfile && _isFamilyRole()
                          ? GuardianProfilePage(
                              tenantContext: widget.tenantContext,
                              syncEngine: widget.syncEngine,
                            )
                          : destinations[activeIndex].page,
                    ),
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
        _showingProfile = false;
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
          // Bottom-pinned Profile for guardians/students.
          if (_isFamilyRole())
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  _buildProfileTile(context, inDrawer),
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
                        ? destination.color
                        : destination.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    destination.icon,
                    size: 20,
                    color: selected
                        ? Colors.white
                        : destination.color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    destination.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: selected
                          ? destination.color
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
                      color: destination.color,
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

  /// Bottom-pinned Profile tile for guardians/students.
  Widget _buildProfileTile(BuildContext context, bool inDrawer) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = _showingProfile;
    const color = ScholifyColors.academicNavy;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              _showingProfile = true;
            });
            if (inDrawer) Navigator.of(context).pop();
          },
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
                        ? color
                        : color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.person_outlined,
                    size: 20,
                    color: selected ? Colors.white : color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'My Profile',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: selected ? color : scheme.onSurface,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color,
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
    // identity. For tenants, the Scholify wordmark stays left and the
    // tenant name is centered (see centeredTenantName below).

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
    // Always shown on the left; tenant name is centered for non-superadmins.
    final Widget logoWidget = RichText(
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
            style: TextStyle(color: ScholifyColors.achievementAmber),
          ),
        ],
      ),
    );

    // Centered tenant name for non-superadmin users.
    final String? centeredTenantName = widget.tenantContext.isSuperAdmin
        ? null
        : (widget.tenantContext.brandingDisplayName ??
            widget.tenantContext.tenantName);

    // Title row: logo left. Tenant name is centered via flexibleSpace below.
    final Widget titleWidget = logoWidget;

    return AppBar(
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: leadingLogo,
      ),
      title: titleWidget,
      centerTitle: false,
      // Centered tenant name overlay for non-superadmin users.
      flexibleSpace: (centeredTenantName != null &&
              centeredTenantName.isNotEmpty)
          ? SafeArea(
              child: Center(
                child: Padding(
                  // Offset for the leading logo + actions so text is truly centered.
                  padding: const EdgeInsets.symmetric(horizontal: 120),
                  child: Text(
                    centeredTenantName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          : null,
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
    required this.color,
  });

  final String label;
  final IconData icon;
  final Widget page;
  final _ShellSection section;
  final Color color;
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

/// Form embedded in the first-login blocking dialog.
/// Guardian must complete all fields to unlock the panel.
class _ProfileCompletionForm extends StatefulWidget {
  const _ProfileCompletionForm({
    required this.syncEngine,
    required this.onCompleted,
  });

  final SyncEngine syncEngine;
  final VoidCallback onCompleted;

  @override
  State<_ProfileCompletionForm> createState() =>
      _ProfileCompletionFormState();
}

class _ProfileCompletionFormState
    extends State<_ProfileCompletionForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _relationshipController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final gateway = widget.syncEngine.pocketbaseGateway;
      final userId = gateway.client.authStore.model?.id;
      if (userId == null || userId.isEmpty) {
        throw Exception('Not signed in');
      }
      await gateway.client.collection('users').update(userId, body: {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'relationship': _relationshipController.text.trim(),
        'profile_completed': true,
      });
      widget.onCompleted();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Full name is required'
                : null,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Phone number is required'
                : null,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              prefixIcon: Icon(Icons.phone_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _relationshipController,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Relationship is required'
                : null,
            decoration: const InputDecoration(
              labelText: 'Relationship with Student',
              hintText: 'e.g. Father, Mother, Guardian',
              prefixIcon:
                  Icon(Icons.family_restroom_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _addressController,
            maxLines: 2,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Home address is required'
                : null,
            decoration: const InputDecoration(
              labelText: 'Home Address',
              prefixIcon: Icon(Icons.home_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _submit,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outlined),
              label: Text(
                  _isSaving ? 'Saving...' : 'Complete Profile'),
            ),
          ),
        ],
      ),
    );
  }
}
