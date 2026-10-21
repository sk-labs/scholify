import 'package:drift/drift.dart';
import 'package:flutter/material.dart';

import '../../core/database/local_database.dart';
import '../../core/remote/pocketbase_gateway.dart';
import '../../core/theme/scholify_colors.dart';

/// Family link resolution: which students belong to the signed-in account.
///
/// Guardian accounts are linked to students through the student-guardian
/// directory: a guardian entry matches the account when its email equals
/// the account email, or its id equals the PocketBase auth user id (the
/// seed and the admin tooling store the account's user id there).
/// Student accounts map to their own directory record by email
/// (student_profiles carries the login email for exactly this purpose).
///
/// This replaces the old "first student in the directory" convention,
/// which showed an arbitrary child (whoever sorted first) on every
/// guardian/student surface.

/// The guardian's currently selected child, shared across the family
/// pages (dashboard, attendance, homework) for the session. Null means
/// "no explicit choice" — the primary (or first) linked child is used.
class FamilyChildSelection {
  FamilyChildSelection._();

  static final ValueNotifier<String?> selectedStudentId =
      ValueNotifier<String?>(null);

  static void reset() => selectedStudentId.value = null;
}

/// Identity of the signed-in account, as the family resolvers need it.
class FamilyIdentity {
  const FamilyIdentity({this.email, this.userId});

  factory FamilyIdentity.fromGateway(PocketbaseGateway gateway) {
    final model = gateway.currentAuthModelJson;
    return FamilyIdentity(
      email: model?['email']?.toString(),
      userId: model?['id']?.toString(),
    );
  }

  final String? email;
  final String? userId;
}

/// Streams the students linked to a guardian account, primary link first,
/// then by name. Emits an empty list when the account has no links.
Stream<List<StudentDirectoryEntry>> watchLinkedChildren(
  AppLocalDatabase database, {
  required FamilyIdentity identity,
  String? tenantId,
}) {
  final query = database.select(database.studentGuardianEntries).join([
    innerJoin(
      database.studentDirectoryEntries,
      database.studentDirectoryEntries.id
          .equalsExp(database.studentGuardianEntries.studentId),
    ),
  ]);
  return query.watch().map((rows) {
    final email = identity.email?.toLowerCase();
    final matches = <({StudentGuardianEntry guardian, StudentDirectoryEntry student})>[];
    final seen = <String>{};
    for (final row in rows) {
      final guardian = row.readTable(database.studentGuardianEntries);
      final student = row.readTable(database.studentDirectoryEntries);
      if (!guardian.isActive || !student.isActive) continue;
      if (tenantId != null && student.tenantId != tenantId) continue;
      final emailMatch = email != null &&
          email.isNotEmpty &&
          (guardian.email?.toLowerCase() == email);
      final idMatch = identity.userId != null &&
          identity.userId!.isNotEmpty &&
          guardian.id == identity.userId;
      if (!emailMatch && !idMatch) continue;
      if (!seen.add(student.id)) continue;
      matches.add((guardian: guardian, student: student));
    }
    matches.sort((a, b) {
      if (a.guardian.isPrimary != b.guardian.isPrimary) {
        return a.guardian.isPrimary ? -1 : 1;
      }
      return a.student.fullName.compareTo(b.student.fullName);
    });
    return [for (final m in matches) m.student];
  });
}

/// Streams the directory record belonging to a student account (matched
/// by login email), or null when the account is not mapped to a record.
Stream<StudentDirectoryEntry?> watchOwnStudentRecord(
  AppLocalDatabase database, {
  required FamilyIdentity identity,
  String? tenantId,
}) {
  final email = identity.email?.toLowerCase();
  if (email == null || email.isEmpty) {
    return Stream.value(null);
  }
  final query = database.select(database.studentDirectoryEntries)
    ..where((tbl) => tbl.isActive.equals(true));
  return query.watch().map((students) {
    for (final student in students) {
      if (tenantId != null && student.tenantId != tenantId) continue;
      if (student.email?.toLowerCase() == email) return student;
    }
    return null;
  });
}

/// The child to show: the explicitly selected one when it is still in
/// [children], otherwise the first (primary) linked child.
StudentDirectoryEntry? effectiveChild(List<StudentDirectoryEntry> children) {
  if (children.isEmpty) return null;
  final selected = FamilyChildSelection.selectedStudentId.value;
  for (final child in children) {
    if (child.id == selected) return child;
  }
  return children.first;
}

/// Horizontal child switcher shown on family surfaces when a guardian
/// has more than one linked child. Renders nothing for a single child.
class FamilyChildSwitcher extends StatelessWidget {
  const FamilyChildSwitcher({super.key, required this.children});

  final List<StudentDirectoryEntry> children;

  @override
  Widget build(BuildContext context) {
    if (children.length < 2) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ValueListenableBuilder<String?>(
      valueListenable: FamilyChildSelection.selectedStudentId,
      builder: (context, selectedId, _) {
        final active = effectiveChild(children);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final child in children) ...[
                _ChildPill(
                  name: child.fullName,
                  selected: active?.id == child.id,
                  scheme: scheme,
                  theme: theme,
                  onTap: () => FamilyChildSelection
                      .selectedStudentId.value = child.id,
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ChildPill extends StatelessWidget {
  const _ChildPill({
    required this.name,
    required this.selected,
    required this.scheme,
    required this.theme,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final ColorScheme scheme;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final label = name;
    return Material(
      color: selected
          ? ScholifyColors.academicNavy
          : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? ScholifyColors.academicNavy
                  : scheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: selected
                    ? Colors.white.withValues(alpha: 0.22)
                    : ScholifyColors.academicNavy.withValues(alpha: 0.12),
                child: Text(
                  initial,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected
                        ? Colors.white
                        : ScholifyColors.academicNavy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected ? Colors.white : scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
