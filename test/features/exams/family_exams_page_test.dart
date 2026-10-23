import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/features/exams/presentation/family_exams_page.dart';

StudentExamMarkView _mark({
  required String scheduleId,
  required String subject,
  required double obtained,
  double max = 50,
  String examName = 'Monthly Test',
  DateTime? date,
  String? grade,
}) {
  return StudentExamMarkView(
    markId: 'mark_$scheduleId',
    scheduleId: scheduleId,
    examName: examName,
    subjectName: subject,
    maxMarks: max,
    examDate: date ?? DateTime(2026, 10, 13),
    marksObtained: obtained,
    grade: grade,
    updatedAt: DateTime(2026, 10, 20),
  );
}

ExamScheduleEntry _schedule({
  required String id,
  required String subject,
  String examName = 'Monthly Test',
  DateTime? date,
}) {
  return ExamScheduleEntry(
    id: id,
    tenantId: 'tenant1',
    examName: examName,
    subjectName: subject,
    maxMarks: 50,
    examDate: date ?? DateTime(2026, 10, 13),
    source: 'remote',
    updatedAt: DateTime(2026, 10, 1),
  );
}

void main() {
  group('gradeForMarks', () {
    test('matches the staff grade scale boundaries', () {
      expect(gradeForMarks(45, 50), 'A+'); // 90%
      expect(gradeForMarks(44, 50), 'A'); // 88%
      expect(gradeForMarks(40, 50), 'A'); // 80%
      expect(gradeForMarks(35, 50), 'B+'); // 70%
      expect(gradeForMarks(30, 50), 'B'); // 60%
      expect(gradeForMarks(25, 50), 'C'); // 50%
      expect(gradeForMarks(18, 50), 'D'); // 36%
      expect(gradeForMarks(17, 50), 'F'); // 34%
    });

    test('zero max marks is N/A', () {
      expect(gradeForMarks(0, 0), 'N/A');
    });
  });

  group('percentOf', () {
    test('computes percentage and guards zero max', () {
      expect(percentOf(42, 50), 84);
      expect(percentOf(0, 0), 0);
    });
  });

  group('buildExamGroups', () {
    test('merges marks and unscored schedules without duplicating', () {
      final groups = buildExamGroups(
        marks: [_mark(scheduleId: 's1', subject: 'Mathematics', obtained: 42)],
        schedules: [
          _schedule(id: 's1', subject: 'Mathematics'),
          _schedule(
            id: 's2',
            subject: 'English',
            date: DateTime(2026, 10, 14),
          ),
        ],
      );

      expect(groups, hasLength(1));
      expect(groups.single.rows, hasLength(2));
      final math = groups.single.rows.first;
      expect(math.subjectName, 'Mathematics');
      expect(math.mark, isNotNull);
      final english = groups.single.rows.last;
      expect(english.subjectName, 'English');
      expect(english.mark, isNull);
    });

    test('separates different exams and orders rows by date', () {
      final groups = buildExamGroups(
        marks: [
          _mark(
            scheduleId: 's2',
            subject: 'English',
            obtained: 40,
            date: DateTime(2026, 10, 14),
          ),
          _mark(scheduleId: 's1', subject: 'Mathematics', obtained: 42),
        ],
        schedules: [
          _schedule(
            id: 's3',
            subject: 'Mathematics',
            examName: 'November Assessment',
            date: DateTime(2026, 11, 10),
          ),
        ],
      );

      expect(groups, hasLength(2));
      expect(groups.first.examName, 'Monthly Test');
      expect(groups.first.rows.first.subjectName, 'Mathematics');
      expect(groups.last.examName, 'November Assessment');
      expect(groups.last.rows.single.mark, isNull);
    });

    test('empty inputs produce no groups', () {
      expect(buildExamGroups(marks: const [], schedules: const []), isEmpty);
    });
  });
}
