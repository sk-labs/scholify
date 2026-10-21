import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/local_database.dart';
import '../remote/pocketbase_gateway.dart';
import '../tenant/tenant_context.dart';
import '../../features/family/family_links.dart';

/// Local (on-device) notifications for school events that would
/// otherwise sit silently in lists:
///
/// - **New notices** published to the notice board (per audience).
/// - **Homework due within 24 hours** that the student has not
///   submitted yet (for the student themself; for a guardian, their
///   primary linked child).
///
/// Checks run after a sync round completes (wired in the shell).
/// "Seen" bookkeeping lives in SharedPreferences so each event
/// notifies once: the first check seeds the notice ids silently
/// (no backlog spam), and homework reminders fire once per
/// assignment per day.
///
/// Everything is best-effort: any platform failure (no notification
/// daemon on desktop Linux, denied permission, missing plugin in
/// tests) disables the service quietly and never reaches the UI.
class LocalNotificationService {
  LocalNotificationService({
    required this.database,
    required this.tenantContext,
    required this.gateway,
  });

  final AppLocalDatabase database;
  final TenantContext tenantContext;
  final PocketbaseGateway gateway;

  static const _seenNoticesKey = 'notif_seen_notice_ids';
  static const _homeworkKeysKey = 'notif_homework_due_keys';
  static const _maxNoticeAlertsPerCheck = 3;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _available = false;
  bool _initialized = false;
  DateTime? _lastCheck;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
        linux: LinuxInitializationSettings(defaultActionName: 'Open'),
      );
      _available = await _plugin.initialize(settings) ?? false;
      if (_available) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await android?.requestPermission();
      }
    } catch (e) {
      _available = false;
      debugPrint('LocalNotificationService disabled: $e');
    }
  }

  /// Runs both checks. Throttled to one run per 45 seconds; sync
  /// rounds complete far more often than events change.
  Future<void> checkAndNotify() async {
    if (!_available) return;
    final now = DateTime.now();
    if (_lastCheck != null &&
        now.difference(_lastCheck!) < const Duration(seconds: 45)) {
      return;
    }
    _lastCheck = now;
    try {
      await _checkNewNotices(now);
      await _checkHomeworkDue(now);
    } catch (e) {
      debugPrint('LocalNotificationService check failed: $e');
    }
  }

  Future<void> _checkNewNotices(DateTime now) async {
    final tenantId = tenantContext.tenantId;
    final role = tenantContext.role.toLowerCase();
    final rows = await (database.select(database.noticeBoardEntries)
          ..where((t) => t.isPublished.equals(true)))
        .get();
    final visible = rows
        .where((n) => tenantId == null || n.tenantId == tenantId)
        .where((n) => n.expiresAt == null || n.expiresAt!.isAfter(now))
        .where((n) => audienceMatches(n.audience, role))
        .toList()
      ..sort((a, b) => b.publishAt.compareTo(a.publishAt));

    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList(_seenNoticesKey);
    if (seen == null) {
      // First run ever: record what exists, notify nothing.
      await prefs.setStringList(
          _seenNoticesKey, [for (final n in visible) n.id]);
      return;
    }
    final seenSet = seen.toSet();
    final fresh = visible.where((n) => !seenSet.contains(n.id)).toList();
    for (final notice in fresh.take(_maxNoticeAlertsPerCheck)) {
      await _show(
        id: stableNotificationId('notice_${notice.id}'),
        title: 'New notice from your school',
        body: notice.title,
      );
    }
    if (fresh.isNotEmpty) {
      await prefs.setStringList(_seenNoticesKey,
          [...seenSet, for (final n in visible) n.id]);
    }
  }

  Future<void> _checkHomeworkDue(DateTime now) async {
    final role = tenantContext.role.toLowerCase();
    final identity = FamilyIdentity.fromGateway(gateway);
    final tenantId = tenantContext.tenantId;

    // Resolve (student, label for the notification body) pairs.
    final targets = <({StudentDirectoryEntry student, bool isGuardian})>[];
    if (role == 'student') {
      final own = await watchOwnStudentRecord(
        database,
        identity: identity,
        tenantId: tenantId,
      ).first;
      if (own != null) targets.add((student: own, isGuardian: false));
    } else if (role == 'guardian') {
      final children = await watchLinkedChildren(
        database,
        identity: identity,
        tenantId: tenantId,
      ).first;
      if (children.isNotEmpty) {
        targets.add((student: children.first, isGuardian: true));
      }
    } else {
      return;
    }

    final assignments = await (database.select(
      database.homeworkAssignmentEntries,
    )..where((t) => t.isActive.equals(true) & t.isPublished.equals(true)))
        .get();
    final dueSoon = assignments
        .where((a) => tenantId == null || a.tenantId == tenantId)
        .where((a) => isDueSoon(a.dueDate, now))
        .toList();
    if (dueSoon.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final notifiedKeys =
        (prefs.getStringList(_homeworkKeysKey) ?? const []).toSet();
    var changed = false;
    final dayStamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    for (final target in targets) {
      final submissions = await (database.select(
        database.homeworkSubmissionEntries,
      )..where(
          (t) => t.studentId.equals(target.student.id) & t.isActive.equals(true)))
          .get();
      final submittedFor = {for (final s in submissions) s.assignmentId};
      for (final assignment in dueSoon) {
        if (submittedFor.contains(assignment.id)) continue;
        final key = 'hw_${assignment.id}_$dayStamp';
        if (notifiedKeys.contains(key)) continue;
        notifiedKeys.add(key);
        changed = true;
        final due = assignment.dueDate!;
        final dueDay = DateTime(due.year, due.month, due.day);
        final today = DateTime(now.year, now.month, now.day);
        final when = dueDay == today
            ? 'today'
            : dueDay.difference(today).inDays == 1
                ? 'tomorrow'
                : 'on ${due.day}/${due.month}';
        await _show(
          id: stableNotificationId('hw_${assignment.id}'),
          title: 'Homework due $when',
          body: target.isGuardian
              ? '${assignment.title} — for ${target.student.fullName}'
              : assignment.title,
        );
      }
    }
    if (changed) {
      // Keys embed their day stamp; the list stays small in practice
      // (a handful of assignments per day) — cap it defensively.
      final kept = notifiedKeys.take(200).toList();
      await prefs.setStringList(_homeworkKeysKey, kept);
    }
  }

  Future<void> _show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_available) return;
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'scholify_alerts',
          'Scholify alerts',
          channelDescription: 'Notices and homework reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
        linux: LinuxNotificationDetails(),
      );
      await _plugin.show(id, title, body, details);
    } catch (e) {
      debugPrint('LocalNotificationService show failed: $e');
    }
  }

  /// Whether a notice with [audience] should reach a user with
  /// [role]. Audiences come from the notice board: all / students /
  /// parents / staff.
  static bool audienceMatches(String audience, String role) {
    final a = audience.toLowerCase();
    if (a == 'all') return true;
    switch (role.toLowerCase()) {
      case 'student':
        return a == 'students';
      case 'guardian':
        return a == 'parents';
      case 'teacher':
      case 'school_owner':
      case 'school_admin':
      case 'superadmin':
        return a == 'staff';
      default:
        return false;
    }
  }

  /// A homework due date counts as "due soon" when its calendar day
  /// is today or tomorrow. (Due dates are date-only values, so this
  /// is a calendar comparison, not a 24-hour window.)
  static bool isDueSoon(DateTime? dueDate, DateTime now) {
    if (dueDate == null) return false;
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = dueDay.difference(today).inDays;
    return diff == 0 || diff == 1;
  }

  /// Deterministic 31-bit notification id for a string key, so
  /// re-notifying the same event replaces rather than stacks.
  static int stableNotificationId(String key) =>
      key.hashCode & 0x7fffffff;
}
