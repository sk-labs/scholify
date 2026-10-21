import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/services/local_notification_service.dart';

void main() {
  group('LocalNotificationService.audienceMatches', () {
    test('all reaches every role', () {
      for (final role in [
        'student',
        'guardian',
        'teacher',
        'school_owner',
        'school_admin',
        'superadmin',
      ]) {
        expect(LocalNotificationService.audienceMatches('all', role), isTrue,
            reason: role);
      }
    });

    test('students audience reaches students only', () {
      expect(
          LocalNotificationService.audienceMatches('students', 'student'),
          isTrue);
      expect(
          LocalNotificationService.audienceMatches('students', 'guardian'),
          isFalse);
      expect(LocalNotificationService.audienceMatches('students', 'teacher'),
          isFalse);
    });

    test('parents audience reaches guardians', () {
      expect(LocalNotificationService.audienceMatches('parents', 'guardian'),
          isTrue);
      expect(LocalNotificationService.audienceMatches('parents', 'student'),
          isFalse);
    });

    test('staff audience reaches staff roles', () {
      for (final role in [
        'teacher',
        'school_owner',
        'school_admin',
        'superadmin',
      ]) {
        expect(LocalNotificationService.audienceMatches('staff', role), isTrue,
            reason: role);
      }
      expect(LocalNotificationService.audienceMatches('staff', 'student'),
          isFalse);
      expect(LocalNotificationService.audienceMatches('staff', 'guardian'),
          isFalse);
    });

    test('matching is case-insensitive and unknown roles get nothing', () {
      expect(LocalNotificationService.audienceMatches('ALL', 'STUDENT'),
          isTrue);
      expect(LocalNotificationService.audienceMatches('students', 'guest'),
          isFalse);
    });
  });

  group('LocalNotificationService.isDueSoon', () {
    final now = DateTime(2026, 10, 21, 19, 30);

    test('null due date is not due soon', () {
      expect(LocalNotificationService.isDueSoon(null, now), isFalse);
    });

    test('due today counts even late in the day', () {
      expect(
          LocalNotificationService.isDueSoon(DateTime(2026, 10, 21), now),
          isTrue);
    });

    test('due tomorrow counts', () {
      expect(
          LocalNotificationService.isDueSoon(DateTime(2026, 10, 22), now),
          isTrue);
    });

    test('due in two days does not count', () {
      expect(
          LocalNotificationService.isDueSoon(DateTime(2026, 10, 23), now),
          isFalse);
    });

    test('overdue (yesterday) does not count', () {
      expect(
          LocalNotificationService.isDueSoon(DateTime(2026, 10, 20), now),
          isFalse);
    });
  });

  group('LocalNotificationService.stableNotificationId', () {
    test('is deterministic and within 31 bits', () {
      final a = LocalNotificationService.stableNotificationId('notice_x');
      final b = LocalNotificationService.stableNotificationId('notice_x');
      expect(a, b);
      expect(a, inInclusiveRange(0, 0x7fffffff));
    });

    test('different keys usually differ', () {
      expect(
        LocalNotificationService.stableNotificationId('notice_a'),
        isNot(LocalNotificationService.stableNotificationId('notice_b')),
      );
    });
  });
}
