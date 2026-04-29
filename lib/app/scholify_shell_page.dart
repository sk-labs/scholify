import 'package:flutter/material.dart';

import '../core/access/module_access_policy.dart';
import '../core/database/local_database.dart';
import '../core/services/license_alert_service.dart';
import '../core/services/seat_limit_enforcement_service.dart';
import '../core/sync/sync_engine.dart';
import '../core/tenant/tenant_context.dart';
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
        ),
      if (access[ScholifyModuleFeature.students] ?? false)
        _ShellDestination(
          label: 'Students',
          icon: Icons.groups,
          page: StudentDirectoryPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        ),
      if (access[ScholifyModuleFeature.guardians] ?? false)
        _ShellDestination(
          label: 'Guardians',
          icon: Icons.family_restroom,
          page: StudentGuardiansPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
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
        ),
      if (access[ScholifyModuleFeature.classRoll] ?? false)
        _ShellDestination(
          label: 'Class Roll',
          icon: Icons.format_list_numbered,
          page: StudentClassRollPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        ),
      if (access[ScholifyModuleFeature.leaveRequests] ?? false)
        _ShellDestination(
          label: 'Leave',
          icon: Icons.event_busy,
          page: LeaveRequestsPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        ),
      if (access[ScholifyModuleFeature.pendingTasks] ?? false)
        _ShellDestination(
          label: 'Tasks',
          icon: Icons.checklist,
          page: PendingTasksPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        ),
      if (access[ScholifyModuleFeature.hostel] ?? false)
        _ShellDestination(
          label: 'Hostel',
          icon: Icons.bed,
          page: HostelPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        ),
      if (access[ScholifyModuleFeature.fees] ?? false)
        _ShellDestination(
          label: 'Fees',
          icon: Icons.receipt_long,
          page: FeeOverviewPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        ),
      if (access[ScholifyModuleFeature.attendance] ?? false)
        _ShellDestination(
          label: 'Attendance',
          icon: Icons.fact_check,
          page: AttendanceOverviewPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        ),
      if (access[ScholifyModuleFeature.exams] ?? false)
        _ShellDestination(
          label: 'Exams',
          icon: Icons.quiz,
          page: ExamOverviewPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        ),
      if (access[ScholifyModuleFeature.notices] ?? false)
        _ShellDestination(
          label: 'Notices',
          icon: Icons.campaign,
          page: NoticeBoardPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        ),
      if (access[ScholifyModuleFeature.timetable] ?? false)
        _ShellDestination(
          label: 'Timetable',
          icon: Icons.view_week,
          page: TimetableOverviewPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        ),
      if (access[ScholifyModuleFeature.transport] ?? false)
        _ShellDestination(
          label: 'Transport',
          icon: Icons.directions_bus,
          page: TransportRoutesPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        ),
      if (access[ScholifyModuleFeature.homework] ?? false)
        _ShellDestination(
          label: 'Homework',
          icon: Icons.assignment,
          page: HomeworkAssignmentsPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        ),
      if (access[ScholifyModuleFeature.onlineLearning] ?? false)
        _ShellDestination(
          label: 'Online Learning',
          icon: Icons.play_lesson,
          page: OnlineLearningPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        ),
      if (access[ScholifyModuleFeature.curriculum] ?? false)
        _ShellDestination(
          label: 'Curriculum',
          icon: Icons.menu_book,
          page: CurriculumPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        ),
      if (access[ScholifyModuleFeature.library] ?? false)
        _ShellDestination(
          label: 'Library',
          icon: Icons.local_library,
          page: LibraryPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        ),
      if (access[ScholifyModuleFeature.documentCenter] ?? false)
        _ShellDestination(
          label: 'Documents',
          icon: Icons.folder_copy_outlined,
          page: DocumentCenterPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        ),
      if (access[ScholifyModuleFeature.visitorCommunication] ?? false)
        _ShellDestination(
          label: 'Visitors',
          icon: Icons.badge_outlined,
          page: VisitorCommunicationPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        ),
      if (access[ScholifyModuleFeature.notifications] ?? false)
        _ShellDestination(
          label: 'Notifications',
          icon: Icons.notifications_active_outlined,
          page: NotificationCenterPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        ),
      if (access[ScholifyModuleFeature.liveClasses] ?? false)
        _ShellDestination(
          label: 'Live Classes',
          icon: Icons.videocam_outlined,
          page: LiveClassesPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        ),
      if (access[ScholifyModuleFeature.teachers] ?? false)
        _ShellDestination(
          label: 'Teachers',
          icon: Icons.people_outline,
          page: TeachersPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
        ),
      if (access[ScholifyModuleFeature.studentBehaviour] ?? false)
        _ShellDestination(
          label: 'Behaviour',
          icon: Icons.psychology_outlined,
          page: StudentBehaviourPage(
            tenantContext: widget.tenantContext,
            syncEngine: widget.syncEngine,
          ),
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
        if (constraints.maxWidth < 900) {
          return Scaffold(
            body: destinations[activeIndex].page,
            bottomNavigationBar: NavigationBar(
              selectedIndex: activeIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              destinations: [
                for (final destination in destinations)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    label: destination.label,
                  ),
              ],
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: activeIndex,
                onDestinationSelected: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                scrollable: true,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final destination in destinations)
                    NavigationRailDestination(
                      icon: Icon(destination.icon),
                      label: Text(destination.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: destinations[activeIndex].page),
            ],
          ),
        );
      },
    );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.page,
  });

  final String label;
  final IconData icon;
  final Widget page;
}
