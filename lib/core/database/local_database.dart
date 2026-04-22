import 'package:drift/drift.dart';

import 'executors/database_executor_stub.dart'
    if (dart.library.io) 'executors/database_executor_io.dart'
    if (dart.library.html) 'executors/database_executor_web.dart';

part 'local_database.g.dart';

class TenantRecords extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class UserProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().references(TenantRecords, #id)();
  TextColumn get displayName => text()();
  TextColumn get role => text().withDefault(const Constant('guest'))();
  BoolColumn get isSuperAdmin => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TenantLicenseEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().references(TenantRecords, #id)();
  TextColumn get schoolOwnerEmail => text()();
  TextColumn get planCode => text().withDefault(const Constant('starter'))();
  IntColumn get seatLimit => integer().withDefault(const Constant(100))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get issuedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get expiresAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SchoolOwnerEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().references(TenantRecords, #id)();
  TextColumn get fullName => text()();
  TextColumn get email => text()();
  TextColumn get phone => text().nullable()();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(true))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get provisioningStatus =>
      text().withDefault(const Constant('provisioned'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TenantUsageMetricEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().references(TenantRecords, #id)();
  TextColumn get periodKey => text()();
  IntColumn get activeStudents => integer().withDefault(const Constant(0))();
  IntColumn get activeStaff => integer().withDefault(const Constant(0))();
  IntColumn get monthlyActiveUsers =>
      integer().withDefault(const Constant(0))();
  RealColumn get storageGb => real().withDefault(const Constant(0))();
  RealColumn get outstandingAmount => real().withDefault(const Constant(0))();
  RealColumn get collectedAmount => real().withDefault(const Constant(0))();
  IntColumn get overdueInvoices => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextBillingAt => dateTime().nullable()();
  TextColumn get billingStatus =>
      text().withDefault(const Constant('current'))();
  TextColumn get source => text().withDefault(const Constant('remote'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TenantFeatureFlagEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().references(TenantRecords, #id)();
  TextColumn get featureKey => text()();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  TextColumn get source => text().withDefault(const Constant('remote'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class NoticeBoardEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get title => text()();
  TextColumn get message => text()();
  TextColumn get audience => text().withDefault(const Constant('all'))();
  DateTimeColumn get publishAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get expiresAt => dateTime().nullable()();
  BoolColumn get isPublished => boolean().withDefault(const Constant(true))();
  TextColumn get source => text().withDefault(const Constant('local'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TimetableSlotEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get dayOfWeek => text()();
  IntColumn get periodIndex => integer()();
  TextColumn get subjectName => text()();
  TextColumn get teacherName => text().nullable()();
  TextColumn get roomNo => text().nullable()();
  TextColumn get timeFrom => text().nullable()();
  TextColumn get timeTo => text().nullable()();
  TextColumn get classSection => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get source => text().withDefault(const Constant('local'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TransportRouteEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get routeTitle => text()();
  TextColumn get vehicleNo => text().nullable()();
  TextColumn get vehicleModel => text().nullable()();
  TextColumn get driverName => text().nullable()();
  TextColumn get driverContact => text().nullable()();
  TextColumn get pickupPoint => text().nullable()();
  TextColumn get destinationPoint => text().nullable()();
  TextColumn get pickupTime => text().nullable()();
  TextColumn get dropTime => text().nullable()();
  RealColumn get monthlyFare => real().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get source => text().withDefault(const Constant('local'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class HomeworkAssignmentEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get assignmentType =>
      text().withDefault(const Constant('homework'))();
  TextColumn get title => text()();
  TextColumn get subjectName => text().nullable()();
  TextColumn get classSection => text().nullable()();
  TextColumn get details => text().nullable()();
  DateTimeColumn get assignedOn => dateTime().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get attachmentUrl => text().nullable()();
  BoolColumn get isPublished => boolean().withDefault(const Constant(true))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get source => text().withDefault(const Constant('local'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class OnlineLearningEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get itemType => text().withDefault(const Constant('course'))();
  TextColumn get title => text()();
  TextColumn get summary => text().nullable()();
  TextColumn get instructorName => text().nullable()();
  TextColumn get durationLabel => text().nullable()();
  TextColumn get accessLevel => text().withDefault(const Constant('open'))();
  RealColumn get priceAmount => real().withDefault(const Constant(0))();
  DateTimeColumn get publishedAt => dateTime().nullable()();
  BoolColumn get isPublished => boolean().withDefault(const Constant(true))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get source => text().withDefault(const Constant('local'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LessonEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get title => text()();
  TextColumn get classSection => text().nullable()();
  TextColumn get subjectName => text().nullable()();
  TextColumn get topicName => text().nullable()();
  TextColumn get lessonDateLabel => text().nullable()();
  TextColumn get attachmentUrl => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get source => text().withDefault(const Constant('local'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LessonPlanEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get title => text()();
  TextColumn get classSection => text().nullable()();
  TextColumn get subjectName => text().nullable()();
  TextColumn get objective => text().nullable()();
  TextColumn get periodLabel => text().nullable()();
  TextColumn get activities => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get source => text().withDefault(const Constant('local'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SubjectEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get subjectName => text()();
  TextColumn get subjectCode => text().nullable()();
  TextColumn get subjectType => text().withDefault(const Constant('theory'))();
  TextColumn get classSection => text().nullable()();
  TextColumn get teacherName => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get source => text().withDefault(const Constant('local'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SyllabusEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get title => text()();
  TextColumn get classSection => text().nullable()();
  TextColumn get subjectName => text().nullable()();
  TextColumn get statusLabel => text().withDefault(const Constant('pending'))();
  TextColumn get completionPercent => text().nullable()();
  DateTimeColumn get targetDate => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get source => text().withDefault(const Constant('local'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LibraryBookEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get bookType => text().withDefault(const Constant('general'))();
  TextColumn get title => text()();
  TextColumn get authorName => text().nullable()();
  TextColumn get categoryName => text().nullable()();
  DateTimeColumn get issuedOn => dateTime().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  DateTimeColumn get returnDate => dateTime().nullable()();
  RealColumn get ratingScore => real().withDefault(const Constant(0))();
  IntColumn get issueCount => integer().withDefault(const Constant(0))();
  BoolColumn get isIssued => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get source => text().withDefault(const Constant('local'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class DocumentCenterEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get contentType =>
      text().withDefault(const Constant('download_content'))();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get fileUrl => text().nullable()();
  TextColumn get thumbnailUrl => text().nullable()();
  TextColumn get categoryLabel => text().nullable()();
  TextColumn get uploadState =>
      text().withDefault(const Constant('uploaded'))();
  DateTimeColumn get publishedAt => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get source => text().withDefault(const Constant('local'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class VisitorCommunicationEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get entryType => text().withDefault(const Constant('visitor'))();
  TextColumn get visitorName => text().nullable()();
  TextColumn get purpose => text().nullable()();
  TextColumn get phone => text().nullable()();
  DateTimeColumn get checkInAt => dateTime().nullable()();
  DateTimeColumn get checkOutAt => dateTime().nullable()();
  TextColumn get statusLabel => text().withDefault(const Constant('open'))();
  TextColumn get note => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get source => text().withDefault(const Constant('local'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class NotificationEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get notificationType =>
      text().withDefault(const Constant('general'))();
  TextColumn get title => text()();
  TextColumn get body => text().nullable()();
  TextColumn get audience => text().withDefault(const Constant('all'))();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  TextColumn get deliveryStatus =>
      text().withDefault(const Constant('queued'))();
  DateTimeColumn get sentAt => dateTime().nullable()();
  DateTimeColumn get readAt => dateTime().nullable()();
  TextColumn get payloadJson => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get source => text().withDefault(const Constant('local'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LiveClassEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get providerType => text().withDefault(const Constant('zoom'))();
  TextColumn get title => text()();
  TextColumn get classSection => text().nullable()();
  TextColumn get hostName => text().nullable()();
  DateTimeColumn get startAt => dateTime().nullable()();
  DateTimeColumn get endAt => dateTime().nullable()();
  TextColumn get joinUrl => text().nullable()();
  TextColumn get meetingId => text().nullable()();
  TextColumn get meetingPassword => text().nullable()();
  TextColumn get statusLabel =>
      text().withDefault(const Constant('scheduled'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get source => text().withDefault(const Constant('local'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LeaveRequestEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get requesterId => text().nullable()();
  DateTimeColumn get leaveFrom => dateTime().nullable()();
  DateTimeColumn get leaveTo => dateTime().nullable()();
  DateTimeColumn get appliedAt => dateTime().nullable()();
  TextColumn get reason => text().nullable()();
  TextColumn get statusLabel => text().withDefault(const Constant('pending'))();
  TextColumn get approverName => text().nullable()();
  DateTimeColumn get approvedAt => dateTime().nullable()();
  TextColumn get attachmentUrl => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get source => text().withDefault(const Constant('local'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PendingTaskEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get title => text()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get statusLabel => text().withDefault(const Constant('pending'))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  TextColumn get priority => text().withDefault(const Constant('medium'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get source => text().withDefault(const Constant('local'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class HostelRoomEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get studentId => text().nullable()();
  TextColumn get hostelName => text().nullable()();
  TextColumn get roomNo => text().nullable()();
  TextColumn get roomType => text().nullable()();
  TextColumn get floorNo => text().nullable()();
  TextColumn get bedNo => text().nullable()();
  TextColumn get wardenName => text().nullable()();
  TextColumn get wardenContact => text().nullable()();
  RealColumn get monthlyFees => real().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get source => text().withDefault(const Constant('local'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class StudentAttendanceRecords extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get studentId => text()();
  DateTimeColumn get attendanceDate => dateTime()();
  TextColumn get status => text()();
  TextColumn get source => text().withDefault(const Constant('local'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class StudentDirectoryEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get admissionNo => text()();
  TextColumn get fullName => text()();
  TextColumn get classSection => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class StudentGuardianEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get studentId => text()();
  TextColumn get fullName => text()();
  TextColumn get relation => text().withDefault(const Constant('guardian'))();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get source => text().withDefault(const Constant('local'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class StudentEnrollmentEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get studentId => text()();
  TextColumn get academicSession => text()();
  TextColumn get enrollmentStatus =>
      text().withDefault(const Constant('enrolled'))();
  DateTimeColumn get enrolledOn => dateTime().nullable()();
  DateTimeColumn get leftOn => dateTime().nullable()();
  TextColumn get remarks => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('local'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class StudentClassRollEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get studentId => text()();
  TextColumn get academicSession => text()();
  TextColumn get className => text()();
  TextColumn get sectionName => text().nullable()();
  TextColumn get rollNo => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get source => text().withDefault(const Constant('local'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class FeeInvoiceEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get studentId => text()();
  TextColumn get invoiceNo => text()();
  RealColumn get amountDue => real()();
  RealColumn get amountPaid => real().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('due'))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get source => text().withDefault(const Constant('local'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class FeePaymentEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get invoiceId => text()();
  TextColumn get studentId => text()();
  RealColumn get amount => real()();
  DateTimeColumn get paidAt => dateTime()();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  TextColumn get referenceNo => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('local'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ExamScheduleEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get examName => text()();
  TextColumn get subjectName => text()();
  RealColumn get maxMarks => real().withDefault(const Constant(100))();
  DateTimeColumn get examDate => dateTime()();
  TextColumn get source => text().withDefault(const Constant('local'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class StudentExamMarkEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get studentId => text()();
  TextColumn get scheduleId => text()();
  RealColumn get marksObtained => real()();
  TextColumn get grade => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('local'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ── Enterprise Fee Groups (schema v28) ───────────────────────────────────

class FeeGroupEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get studentId => text()();
  TextColumn get feeTitle => text()();
  TextColumn get feeCode => text().nullable()();
  RealColumn get amount => real().withDefault(const Constant(0))();
  RealColumn get discount => real().withDefault(const Constant(0))();
  RealColumn get fine => real().withDefault(const Constant(0))();
  RealColumn get paid => real().withDefault(const Constant(0))();
  RealColumn get balance => real().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('unpaid'))();
  TextColumn get dueDate => text().nullable()();
  BoolColumn get isPayable => boolean().withDefault(const Constant(false))();
  TextColumn get paymentMode => text().nullable()();
  TextColumn get paymentId => text().nullable()();
  TextColumn get paymentDate => text().nullable()();
  TextColumn get feeType => text().withDefault(const Constant('fee'))(); // fee | processing | offline
  TextColumn get reference => text().nullable()();
  TextColumn get comments => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('remote'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ── CBSE Exam Results (schema v29) ────────────────────────────────────────

class CbseExamResultEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get studentId => text()();
  TextColumn get examName => text()();
  TextColumn get subjectName => text()();
  TextColumn get subjectCode => text().nullable()();
  TextColumn get assessmentName => text().nullable()();
  RealColumn get marksObtained => real().nullable()();
  RealColumn get maxMarks => real().nullable()();
  TextColumn get examDate => text().nullable()();
  TextColumn get grade => text().nullable()();
  TextColumn get rank => text().nullable()();
  TextColumn get percentage => text().nullable()();
  TextColumn get totalObtained => text().nullable()();
  TextColumn get totalMax => text().nullable()();
  TextColumn get resultType => text().withDefault(const Constant('result'))(); // result | schedule
  TextColumn get roomNo => text().nullable()();
  TextColumn get timeFrom => text().nullable()();
  TextColumn get duration => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('remote'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ── Online Exam Catalog (schema v30) ──────────────────────────────────────

class OnlineExamEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get examTitle => text()();
  TextColumn get description => text().nullable()();
  TextColumn get examFrom => text().nullable()();
  TextColumn get examTo => text().nullable()();
  IntColumn get totalQuestions => integer().withDefault(const Constant(0))();
  IntColumn get totalAttempt => integer().withDefault(const Constant(1))();
  IntColumn get durationMinutes => integer().withDefault(const Constant(0))();
  RealColumn get passingPercent => real().withDefault(const Constant(35))();
  BoolColumn get isQuiz => boolean().withDefault(const Constant(false))();
  TextColumn get statusLabel => text().withDefault(const Constant('upcoming'))();
  // Student-specific attempt state (denormalized for offline-first)
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  BoolColumn get isSubmitted => boolean().withDefault(const Constant(false))();
  RealColumn get lastScorePercent => real().nullable()();
  BoolColumn get isPassed => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get source => text().withDefault(const Constant('remote'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ── Student Behaviour (schema v31) ───────────────────────────────────────

class StudentBehaviourEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get studentId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get point => text().withDefault(const Constant('0'))();
  BoolColumn get isPositive => boolean().withDefault(const Constant(true))();
  TextColumn get assignedBy => text().nullable()();
  TextColumn get incidentDate => text().nullable()();
  IntColumn get commentCount => integer().withDefault(const Constant(0))();
  TextColumn get source => text().withDefault(const Constant('remote'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class BehaviourCommentEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get incidentId => text()();
  TextColumn get commentText => text()();
  TextColumn get commentedBy => text().nullable()();
  TextColumn get commentDate => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('remote'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ── Teacher Directory + Reviews (schema v32) ──────────────────────────────

class TeacherEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get fullName => text()();
  TextColumn get employeeNo => text().nullable()();
  TextColumn get subjectName => text().nullable()();
  TextColumn get qualification => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get designation => text().nullable()();
  BoolColumn get isClassTeacher => boolean().withDefault(const Constant(false))();
  TextColumn get imageUrl => text().nullable()();
  // Review state (per-student, denormalized for offline-first)
  IntColumn get ratingScore => integer().withDefault(const Constant(0))();
  TextColumn get reviewComment => text().nullable()();
  BoolColumn get hasReviewed => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get source => text().withDefault(const Constant('remote'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ── Online Learning Lessons (schema v32) ─────────────────────────────────

class OnlineLessonEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get itemId => text()(); // FK to OnlineLearningEntries
  TextColumn get title => text()();
  TextColumn get contentType => text().withDefault(const Constant('video'))(); // video | text | pdf
  TextColumn get contentUrl => text().nullable()();
  TextColumn get description => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get source => text().withDefault(const Constant('remote'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class HomeworkSubmissionEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get assignmentId => text()();
  TextColumn get studentId => text()();
  TextColumn get submissionText => text().nullable()();
  TextColumn get attachmentUrl => text().nullable()();
  TextColumn get statusLabel => text().withDefault(const Constant('submitted'))();
  TextColumn get teacherFeedback => text().nullable()();
  RealColumn get gradeScore => real().nullable()();
  DateTimeColumn get submittedAt => dateTime().nullable()();
  DateTimeColumn get reviewedAt => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get source => text().withDefault(const Constant('local'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class OnlineLearningAttemptEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get itemId => text()();
  TextColumn get studentId => text()();
  TextColumn get attemptStatus => text().withDefault(const Constant('in_progress'))();
  RealColumn get scorePercent => real().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  BoolColumn get isPassed => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get source => text().withDefault(const Constant('local'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SyncQueueEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tenantId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  TextColumn get payload => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
}

class SyncCheckpointEntries extends Table {
  TextColumn get entityType => text()();
  DateTimeColumn get lastPulledAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {entityType};
}

class TenantLicenseView {
  const TenantLicenseView({
    required this.licenseId,
    required this.tenantId,
    required this.tenantName,
    required this.schoolOwnerEmail,
    required this.planCode,
    required this.seatLimit,
    required this.isActive,
    required this.issuedAt,
    required this.expiresAt,
    required this.updatedAt,
  });

  final String licenseId;
  final String tenantId;
  final String tenantName;
  final String schoolOwnerEmail;
  final String planCode;
  final int seatLimit;
  final bool isActive;
  final DateTime issuedAt;
  final DateTime? expiresAt;
  final DateTime updatedAt;
}

class SchoolOwnerView {
  const SchoolOwnerView({
    required this.ownerId,
    required this.tenantId,
    required this.tenantName,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.isPrimary,
    required this.isActive,
    required this.provisioningStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  final String ownerId;
  final String tenantId;
  final String tenantName;
  final String fullName;
  final String email;
  final String? phone;
  final bool isPrimary;
  final bool isActive;
  final String provisioningStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class TenantUsageBillingView {
  const TenantUsageBillingView({
    required this.tenantId,
    required this.tenantName,
    required this.planCode,
    required this.seatLimit,
    required this.licenseActive,
    required this.licenseExpiresAt,
    required this.metricId,
    required this.periodKey,
    required this.activeStudents,
    required this.activeStaff,
    required this.monthlyActiveUsers,
    required this.storageGb,
    required this.outstandingAmount,
    required this.collectedAmount,
    required this.overdueInvoices,
    required this.nextBillingAt,
    required this.billingStatus,
    required this.updatedAt,
  });

  final String tenantId;
  final String tenantName;
  final String? planCode;
  final int? seatLimit;
  final bool? licenseActive;
  final DateTime? licenseExpiresAt;
  final String? metricId;
  final String? periodKey;
  final int? activeStudents;
  final int? activeStaff;
  final int? monthlyActiveUsers;
  final double? storageGb;
  final double? outstandingAmount;
  final double? collectedAmount;
  final int? overdueInvoices;
  final DateTime? nextBillingAt;
  final String? billingStatus;
  final DateTime? updatedAt;
}

class TenantFeatureFlagView {
  const TenantFeatureFlagView({
    required this.flagId,
    required this.tenantId,
    required this.tenantName,
    required this.featureKey,
    required this.isEnabled,
    required this.source,
    required this.updatedAt,
  });

  final String flagId;
  final String tenantId;
  final String tenantName;
  final String featureKey;
  final bool isEnabled;
  final String source;
  final DateTime updatedAt;
}

class StudentExamMarkView {
  const StudentExamMarkView({
    required this.markId,
    required this.scheduleId,
    required this.examName,
    required this.subjectName,
    required this.maxMarks,
    required this.examDate,
    required this.marksObtained,
    required this.grade,
    required this.updatedAt,
  });

  final String markId;
  final String scheduleId;
  final String examName;
  final String subjectName;
  final double maxMarks;
  final DateTime examDate;
  final double marksObtained;
  final String? grade;
  final DateTime updatedAt;
}

class ExamAnalyticsMarkRow {
  const ExamAnalyticsMarkRow({
    required this.markId,
    required this.studentId,
    required this.studentName,
    required this.admissionNo,
    required this.classSection,
    required this.scheduleId,
    required this.examName,
    required this.subjectName,
    required this.maxMarks,
    required this.examDate,
    required this.marksObtained,
    required this.grade,
    required this.updatedAt,
  });

  final String markId;
  final String studentId;
  final String? studentName;
  final String? admissionNo;
  final String? classSection;
  final String scheduleId;
  final String examName;
  final String subjectName;
  final double maxMarks;
  final DateTime examDate;
  final double marksObtained;
  final String? grade;
  final DateTime updatedAt;
}

@DriftDatabase(
  tables: [
    TenantRecords,
    UserProfiles,
    TenantLicenseEntries,
    SchoolOwnerEntries,
    TenantUsageMetricEntries,
    TenantFeatureFlagEntries,
    NoticeBoardEntries,
    TimetableSlotEntries,
    TransportRouteEntries,
    HomeworkAssignmentEntries,
    OnlineLearningEntries,
    LessonEntries,
    LessonPlanEntries,
    SubjectEntries,
    SyllabusEntries,
    LibraryBookEntries,
    DocumentCenterEntries,
    VisitorCommunicationEntries,
    NotificationEntries,
    LiveClassEntries,
    LeaveRequestEntries,
    PendingTaskEntries,
    HostelRoomEntries,
    StudentAttendanceRecords,
    StudentDirectoryEntries,
    StudentGuardianEntries,
    StudentEnrollmentEntries,
    StudentClassRollEntries,
    FeeInvoiceEntries,
    FeePaymentEntries,
    FeeGroupEntries,
    ExamScheduleEntries,
    StudentExamMarkEntries,
    CbseExamResultEntries,
    OnlineExamEntries,
    StudentBehaviourEntries,
    BehaviourCommentEntries,
    TeacherEntries,
    OnlineLessonEntries,
    HomeworkSubmissionEntries,
    OnlineLearningAttemptEntries,
    SyncQueueEntries,
    SyncCheckpointEntries,
  ],
)
class AppLocalDatabase extends _$AppLocalDatabase {
  AppLocalDatabase({QueryExecutor? executor})
    : super(executor ?? createDatabaseExecutor());

  @override
  int get schemaVersion => 33;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(tenantLicenseEntries);
      }
      if (from < 3) {
        await migrator.createTable(schoolOwnerEntries);
      }
      if (from < 4) {
        await migrator.createTable(syncCheckpointEntries);
      }
      if (from < 5) {
        await migrator.createTable(studentAttendanceRecords);
      }
      if (from < 6) {
        await migrator.createTable(studentDirectoryEntries);
      }
      if (from < 7) {
        await migrator.createTable(feeInvoiceEntries);
      }
      if (from < 8) {
        await migrator.createTable(feePaymentEntries);
      }
      if (from < 9) {
        await migrator.createTable(examScheduleEntries);
      }
      if (from < 10) {
        await migrator.createTable(studentExamMarkEntries);
      }
      if (from < 11) {
        await migrator.createTable(studentGuardianEntries);
      }
      if (from < 12) {
        await migrator.createTable(studentEnrollmentEntries);
      }
      if (from < 13) {
        await migrator.createTable(studentClassRollEntries);
      }
      if (from < 14) {
        await migrator.createTable(tenantUsageMetricEntries);
      }
      if (from < 15) {
        await migrator.createTable(tenantFeatureFlagEntries);
      }
      if (from < 16) {
        await migrator.createTable(noticeBoardEntries);
      }
      if (from < 17) {
        await migrator.createTable(timetableSlotEntries);
      }
      if (from < 18) {
        await migrator.createTable(transportRouteEntries);
      }
      if (from < 19) {
        await migrator.createTable(homeworkAssignmentEntries);
      }
      if (from < 20) {
        await migrator.createTable(onlineLearningEntries);
      }
      if (from < 21) {
        await migrator.createTable(lessonEntries);
        await migrator.createTable(lessonPlanEntries);
        await migrator.createTable(subjectEntries);
        await migrator.createTable(syllabusEntries);
      }
      if (from < 22) {
        await migrator.createTable(libraryBookEntries);
        await migrator.createTable(documentCenterEntries);
      }
      if (from < 23) {
        await migrator.createTable(visitorCommunicationEntries);
        await migrator.createTable(notificationEntries);
      }
      if (from < 24) {
        await migrator.createTable(liveClassEntries);
      }
      if (from < 25) {
        await migrator.createTable(leaveRequestEntries);
        await migrator.createTable(pendingTaskEntries);
        await migrator.createTable(hostelRoomEntries);
      }
      if (from < 26) {
        await migrator.createTable(homeworkSubmissionEntries);
      }
      if (from < 27) {
        await migrator.createTable(onlineLearningAttemptEntries);
      }
      if (from < 28) {
        await migrator.createTable(feeGroupEntries);
      }
      if (from < 29) {
        await migrator.createTable(cbseExamResultEntries);
      }
      if (from < 30) {
        await migrator.createTable(onlineExamEntries);
      }
      if (from < 31) {
        await migrator.createTable(studentBehaviourEntries);
        await migrator.createTable(behaviourCommentEntries);
      }
      if (from < 32) {
        await migrator.createTable(teacherEntries);
      }
      if (from < 33) {
        await migrator.createTable(onlineLessonEntries);
      }
    },
  );

  Future<int> pendingSyncCount() async {
    final countExpression = syncQueueEntries.id.count();
    final query = selectOnly(syncQueueEntries)
      ..addColumns([countExpression])
      ..where(syncQueueEntries.status.equals('pending'));

    final row = await query.getSingle();
    return row.read(countExpression) ?? 0;
  }

  Future<void> queueOperation({
    required String tenantId,
    required String entityType,
    required String entityId,
    required String operation,
    required String payload,
  }) async {
    await into(syncQueueEntries).insert(
      SyncQueueEntriesCompanion.insert(
        tenantId: tenantId,
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        payload: payload,
      ),
    );
  }

  Future<List<SyncQueueEntry>> getSyncQueueDispatchBatch({
    int limit = 50,
    int maxRetryCount = 5,
    String? tenantId,
  }) {
    return (select(syncQueueEntries)
          ..where((tbl) {
            final retryWindow = tbl.retryCount.isSmallerThanValue(
              maxRetryCount,
            );
            final pendingOrFailed =
                tbl.status.equals('pending') | tbl.status.equals('failed');
            final tenantScope = tenantId == null || tenantId.isEmpty
                ? const Constant(true)
                : tbl.tenantId.equals(tenantId);
            return retryWindow & pendingOrFailed & tenantScope;
          })
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.createdAt),
            (tbl) => OrderingTerm.asc(tbl.retryCount),
          ])
          ..limit(limit))
        .get();
  }

  Future<void> markSyncQueueEntrySynced({required int entryId}) {
    return (update(
      syncQueueEntries,
    )..where((tbl) => tbl.id.equals(entryId))).write(
      SyncQueueEntriesCompanion(
        status: const Value('synced'),
        lastAttemptAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markSyncQueueEntryFailed({
    required int entryId,
    required int currentRetryCount,
  }) {
    return (update(
      syncQueueEntries,
    )..where((tbl) => tbl.id.equals(entryId))).write(
      SyncQueueEntriesCompanion(
        status: const Value('failed'),
        retryCount: Value(currentRetryCount + 1),
        lastAttemptAt: Value(DateTime.now()),
      ),
    );
  }

  Future<DateTime?> getLastPullCheckpoint(String entityType) async {
    final row = await (select(
      syncCheckpointEntries,
    )..where((tbl) => tbl.entityType.equals(entityType))).getSingleOrNull();
    return row?.lastPulledAt;
  }

  Future<DateTime?> getEntityUpdatedAt({
    required String entityType,
    required String tenantId,
    required String entityId,
  }) async {
    switch (entityType) {
      case 'tenant_license':
        final row =
            await (select(tenantLicenseEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'school_owner':
        final row =
            await (select(schoolOwnerEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'tenant_usage_metric':
        final row =
            await (select(tenantUsageMetricEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'tenant_feature_flag':
        final row =
            await (select(tenantFeatureFlagEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'notice_board':
        final row =
            await (select(noticeBoardEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'timetable_slot':
        final row =
            await (select(timetableSlotEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'transport_route':
        final row =
            await (select(transportRouteEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'homework_assignment':
        final row =
            await (select(homeworkAssignmentEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'online_learning_item':
        final row =
            await (select(onlineLearningEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'lesson':
        final row =
            await (select(lessonEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'lesson_plan':
        final row =
            await (select(lessonPlanEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'subject':
        final row =
            await (select(subjectEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'syllabus':
        final row =
            await (select(syllabusEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'library_item':
        final row =
            await (select(libraryBookEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'document_center_item':
        final row =
            await (select(documentCenterEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'visitor_communication':
        final row =
            await (select(visitorCommunicationEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'notification':
        final row =
            await (select(notificationEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'live_class':
        final row =
            await (select(liveClassEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'leave_request':
        final row =
            await (select(leaveRequestEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'pending_task':
        final row =
            await (select(pendingTaskEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'hostel_room':
        final row =
            await (select(hostelRoomEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'student_profile':
        final row =
            await (select(studentDirectoryEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'student_guardian':
        final row =
            await (select(studentGuardianEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'student_enrollment':
        final row =
            await (select(studentEnrollmentEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'student_class_roll':
        final row =
            await (select(studentClassRollEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'student_attendance':
        final row =
            await (select(studentAttendanceRecords)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'fee_invoice':
        final row =
            await (select(feeInvoiceEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'fee_payment':
        final row =
            await (select(feePaymentEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'exam_schedule':
        final row =
            await (select(examScheduleEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'exam_mark':
        final row =
            await (select(studentExamMarkEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'homework_submission':
        final row =
            await (select(homeworkSubmissionEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'online_learning_attempt':
        final row =
            await (select(onlineLearningAttemptEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'fee_group':
        final row =
            await (select(feeGroupEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'cbse_exam_result':
        final row =
            await (select(cbseExamResultEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'online_exam':
        final row =
            await (select(onlineExamEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'student_behaviour':
        final row =
            await (select(studentBehaviourEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'behaviour_comment':
        final row =
            await (select(behaviourCommentEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'teacher':
        final row =
            await (select(teacherEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      case 'online_lesson':
        final row =
            await (select(onlineLessonEntries)..where((tbl) {
                  final byId = tbl.id.equals(entityId);
                  if (tenantId.isEmpty) return byId;
                  return byId & tbl.tenantId.equals(tenantId);
                }))
                .getSingleOrNull();
        return row?.updatedAt;
      default:
        return null;
    }
  }

  Future<void> setLastPullCheckpoint({
    required String entityType,
    required DateTime checkpoint,
  }) {
    return into(syncCheckpointEntries).insertOnConflictUpdate(
      SyncCheckpointEntriesCompanion(
        entityType: Value(entityType),
        lastPulledAt: Value(checkpoint),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> createOrUpdateTenantLicense({
    required String tenantId,
    required String tenantName,
    required String schoolOwnerEmail,
    required String planCode,
    required int seatLimit,
    DateTime? expiresAt,
  }) async {
    await transaction(() async {
      await into(tenantRecords).insertOnConflictUpdate(
        TenantRecordsCompanion(
          id: Value(tenantId),
          name: Value(tenantName),
          isActive: const Value(true),
        ),
      );

      await into(tenantLicenseEntries).insertOnConflictUpdate(
        TenantLicenseEntriesCompanion(
          id: Value('lic_$tenantId'),
          tenantId: Value(tenantId),
          schoolOwnerEmail: Value(schoolOwnerEmail),
          planCode: Value(planCode),
          seatLimit: Value(seatLimit),
          isActive: const Value(true),
          expiresAt: Value(expiresAt),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> upsertTenantLicenseFromRemote({
    required String licenseId,
    required String tenantId,
    required String tenantName,
    required String schoolOwnerEmail,
    required String planCode,
    required int seatLimit,
    required bool isActive,
    required DateTime issuedAt,
    required DateTime updatedAt,
    DateTime? expiresAt,
  }) async {
    await transaction(() async {
      await into(tenantRecords).insertOnConflictUpdate(
        TenantRecordsCompanion(
          id: Value(tenantId),
          name: Value(tenantName),
          isActive: Value(isActive),
        ),
      );

      await into(tenantLicenseEntries).insertOnConflictUpdate(
        TenantLicenseEntriesCompanion(
          id: Value(licenseId),
          tenantId: Value(tenantId),
          schoolOwnerEmail: Value(schoolOwnerEmail),
          planCode: Value(planCode),
          seatLimit: Value(seatLimit),
          isActive: Value(isActive),
          issuedAt: Value(issuedAt),
          expiresAt: Value(expiresAt),
          updatedAt: Value(updatedAt),
        ),
      );
    });
  }

  Future<void> setTenantLicenseStatus({
    required String licenseId,
    required String tenantId,
    required bool isActive,
  }) async {
    await transaction(() async {
      await (update(
        tenantLicenseEntries,
      )..where((tbl) => tbl.id.equals(licenseId))).write(
        TenantLicenseEntriesCompanion(
          isActive: Value(isActive),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await (update(tenantRecords)..where((tbl) => tbl.id.equals(tenantId)))
          .write(TenantRecordsCompanion(isActive: Value(isActive)));
    });
  }

  Future<void> upsertTenantUsageMetricFromRemote({
    required String metricId,
    required String tenantId,
    required String periodKey,
    required int activeStudents,
    required int activeStaff,
    required int monthlyActiveUsers,
    required double storageGb,
    required double outstandingAmount,
    required double collectedAmount,
    required int overdueInvoices,
    DateTime? nextBillingAt,
    required String billingStatus,
    String source = 'remote',
    required DateTime updatedAt,
  }) {
    return into(tenantUsageMetricEntries).insertOnConflictUpdate(
      TenantUsageMetricEntriesCompanion(
        id: Value(metricId),
        tenantId: Value(tenantId),
        periodKey: Value(periodKey),
        activeStudents: Value(activeStudents),
        activeStaff: Value(activeStaff),
        monthlyActiveUsers: Value(monthlyActiveUsers),
        storageGb: Value(storageGb),
        outstandingAmount: Value(outstandingAmount),
        collectedAmount: Value(collectedAmount),
        overdueInvoices: Value(overdueInvoices),
        nextBillingAt: Value(nextBillingAt),
        billingStatus: Value(billingStatus),
        source: Value(source),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  Future<void> upsertTenantFeatureFlagRecord({
    String? flagId,
    required String tenantId,
    required String featureKey,
    required bool isEnabled,
    String source = 'local',
    DateTime? updatedAt,
  }) {
    final resolvedFlagId = flagId ?? 'ff_${tenantId}_$featureKey';
    return into(tenantFeatureFlagEntries).insertOnConflictUpdate(
      TenantFeatureFlagEntriesCompanion(
        id: Value(resolvedFlagId),
        tenantId: Value(tenantId),
        featureKey: Value(featureKey),
        isEnabled: Value(isEnabled),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> upsertTenantFeatureFlagFromRemote({
    required String flagId,
    required String tenantId,
    required String featureKey,
    required bool isEnabled,
    String source = 'remote',
    required DateTime updatedAt,
  }) {
    return upsertTenantFeatureFlagRecord(
      flagId: flagId,
      tenantId: tenantId,
      featureKey: featureKey,
      isEnabled: isEnabled,
      source: source,
      updatedAt: updatedAt,
    );
  }

  Stream<List<TenantFeatureFlagEntry>> watchTenantFeatureFlags({
    required String tenantId,
  }) {
    return (select(tenantFeatureFlagEntries)
          ..where((tbl) => tbl.tenantId.equals(tenantId))
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.featureKey),
            (tbl) => OrderingTerm.desc(tbl.updatedAt),
          ]))
        .watch();
  }

  Stream<List<TenantLicenseView>> watchTenantLicenseViews() {
    return customSelect(
      '''
      SELECT
        l.id AS license_id,
        l.tenant_id AS tenant_id,
        t.name AS tenant_name,
        l.school_owner_email AS school_owner_email,
        l.plan_code AS plan_code,
        l.seat_limit AS seat_limit,
        l.is_active AS is_active,
        l.issued_at AS issued_at,
        l.expires_at AS expires_at,
        l.updated_at AS updated_at
      FROM tenant_license_entries l
      INNER JOIN tenant_records t ON t.id = l.tenant_id
      ORDER BY l.updated_at DESC
      ''',
      readsFrom: {tenantLicenseEntries, tenantRecords},
    ).watch().map(
      (rows) => rows
          .map(
            (row) => TenantLicenseView(
              licenseId: row.read<String>('license_id'),
              tenantId: row.read<String>('tenant_id'),
              tenantName: row.read<String>('tenant_name'),
              schoolOwnerEmail: row.read<String>('school_owner_email'),
              planCode: row.read<String>('plan_code'),
              seatLimit: row.read<int>('seat_limit'),
              isActive: row.read<bool>('is_active'),
              issuedAt: row.read<DateTime>('issued_at'),
              expiresAt: row.readNullable<DateTime>('expires_at'),
              updatedAt: row.read<DateTime>('updated_at'),
            ),
          )
          .toList(),
    );
  }

  Stream<List<TenantUsageBillingView>> watchTenantUsageBillingViews() {
    return customSelect(
      '''
      SELECT
        t.id AS tenant_id,
        t.name AS tenant_name,
        l.plan_code AS plan_code,
        l.seat_limit AS seat_limit,
        l.is_active AS license_active,
        l.expires_at AS license_expires_at,
        u.id AS metric_id,
        u.period_key AS period_key,
        u.active_students AS active_students,
        u.active_staff AS active_staff,
        u.monthly_active_users AS monthly_active_users,
        u.storage_gb AS storage_gb,
        u.outstanding_amount AS outstanding_amount,
        u.collected_amount AS collected_amount,
        u.overdue_invoices AS overdue_invoices,
        u.next_billing_at AS next_billing_at,
        u.billing_status AS billing_status,
        u.updated_at AS metric_updated_at
      FROM tenant_records t
      LEFT JOIN tenant_license_entries l
        ON l.tenant_id = t.id
      LEFT JOIN tenant_usage_metric_entries u
        ON u.tenant_id = t.id
        AND u.updated_at = (
          SELECT MAX(u2.updated_at)
          FROM tenant_usage_metric_entries u2
          WHERE u2.tenant_id = t.id
        )
      ORDER BY COALESCE(u.updated_at, l.updated_at, t.created_at) DESC
      ''',
      readsFrom: {
        tenantRecords,
        tenantLicenseEntries,
        tenantUsageMetricEntries,
      },
    ).watch().map(
      (rows) => rows
          .map(
            (row) => TenantUsageBillingView(
              tenantId: row.read<String>('tenant_id'),
              tenantName: row.read<String>('tenant_name'),
              planCode: row.readNullable<String>('plan_code'),
              seatLimit: row.readNullable<int>('seat_limit'),
              licenseActive: row.readNullable<bool>('license_active'),
              licenseExpiresAt: row.readNullable<DateTime>(
                'license_expires_at',
              ),
              metricId: row.readNullable<String>('metric_id'),
              periodKey: row.readNullable<String>('period_key'),
              activeStudents: row.readNullable<int>('active_students'),
              activeStaff: row.readNullable<int>('active_staff'),
              monthlyActiveUsers: row.readNullable<int>('monthly_active_users'),
              storageGb: row.readNullable<double>('storage_gb'),
              outstandingAmount: row.readNullable<double>('outstanding_amount'),
              collectedAmount: row.readNullable<double>('collected_amount'),
              overdueInvoices: row.readNullable<int>('overdue_invoices'),
              nextBillingAt: row.readNullable<DateTime>('next_billing_at'),
              billingStatus: row.readNullable<String>('billing_status'),
              updatedAt: row.readNullable<DateTime>('metric_updated_at'),
            ),
          )
          .toList(),
    );
  }

  Stream<List<TenantFeatureFlagView>> watchTenantFeatureFlagViews({
    String? tenantId,
  }) {
    final filters = <String>[];
    if (tenantId != null && tenantId.isNotEmpty) {
      final escapedTenantId = tenantId.replaceAll('"', r'\"');
      filters.add('f.tenant_id = "$escapedTenantId"');
    }
    final whereClause = filters.isEmpty ? '' : 'WHERE ${filters.join(' AND ')}';

    return customSelect(
      '''
      SELECT
        f.id AS flag_id,
        f.tenant_id AS tenant_id,
        t.name AS tenant_name,
        f.feature_key AS feature_key,
        f.is_enabled AS is_enabled,
        f.source AS source,
        f.updated_at AS updated_at
      FROM tenant_feature_flag_entries f
      INNER JOIN tenant_records t ON t.id = f.tenant_id
      $whereClause
      ORDER BY f.tenant_id ASC, f.feature_key ASC
      ''',
      readsFrom: {tenantFeatureFlagEntries, tenantRecords},
    ).watch().map(
      (rows) => rows
          .map(
            (row) => TenantFeatureFlagView(
              flagId: row.read<String>('flag_id'),
              tenantId: row.read<String>('tenant_id'),
              tenantName: row.read<String>('tenant_name'),
              featureKey: row.read<String>('feature_key'),
              isEnabled: row.read<bool>('is_enabled'),
              source: row.read<String>('source'),
              updatedAt: row.read<DateTime>('updated_at'),
            ),
          )
          .toList(),
    );
  }

  Future<void> createOrUpdateSchoolOwner({
    required String ownerId,
    required String tenantId,
    required String fullName,
    required String email,
    String? phone,
    bool isPrimary = true,
  }) async {
    await into(schoolOwnerEntries).insertOnConflictUpdate(
      SchoolOwnerEntriesCompanion(
        id: Value(ownerId),
        tenantId: Value(tenantId),
        fullName: Value(fullName),
        email: Value(email),
        phone: Value(phone),
        isPrimary: Value(isPrimary),
        isActive: const Value(true),
        provisioningStatus: const Value('provisioned'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> upsertSchoolOwnerFromRemote({
    required String ownerId,
    required String tenantId,
    required String tenantName,
    required String fullName,
    required String email,
    String? phone,
    required bool isPrimary,
    required bool isActive,
    required String provisioningStatus,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) async {
    await transaction(() async {
      await into(tenantRecords).insertOnConflictUpdate(
        TenantRecordsCompanion(
          id: Value(tenantId),
          name: Value(tenantName),
          isActive: Value(isActive),
        ),
      );

      await into(schoolOwnerEntries).insertOnConflictUpdate(
        SchoolOwnerEntriesCompanion(
          id: Value(ownerId),
          tenantId: Value(tenantId),
          fullName: Value(fullName),
          email: Value(email),
          phone: Value(phone),
          isPrimary: Value(isPrimary),
          isActive: Value(isActive),
          provisioningStatus: Value(provisioningStatus),
          createdAt: Value(createdAt),
          updatedAt: Value(updatedAt),
        ),
      );
    });
  }

  Future<void> setSchoolOwnerStatus({
    required String ownerId,
    required bool isActive,
  }) async {
    await (update(
      schoolOwnerEntries,
    )..where((tbl) => tbl.id.equals(ownerId))).write(
      SchoolOwnerEntriesCompanion(
        isActive: Value(isActive),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> upsertNoticeBoardRecord({
    required String noticeId,
    required String tenantId,
    required String title,
    required String message,
    String audience = 'all',
    required DateTime publishAt,
    DateTime? expiresAt,
    bool isPublished = true,
    String source = 'local',
    DateTime? updatedAt,
  }) {
    return into(noticeBoardEntries).insertOnConflictUpdate(
      NoticeBoardEntriesCompanion(
        id: Value(noticeId),
        tenantId: Value(tenantId),
        title: Value(title),
        message: Value(message),
        audience: Value(audience),
        publishAt: Value(publishAt),
        expiresAt: Value(expiresAt),
        isPublished: Value(isPublished),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> deleteNoticeBoardRecord({
    required String tenantId,
    required String noticeId,
  }) async {
    await (delete(noticeBoardEntries)..where(
          (tbl) => tbl.tenantId.equals(tenantId) & tbl.id.equals(noticeId),
        ))
        .go();
  }

  Stream<List<NoticeBoardEntry>> watchNoticeBoardEntries({
    required String tenantId,
    bool publishedOnly = true,
  }) {
    return (select(noticeBoardEntries)
          ..where((tbl) {
            final byTenant = tbl.tenantId.equals(tenantId);
            if (!publishedOnly) {
              return byTenant;
            }
            return byTenant & tbl.isPublished.equals(true);
          })
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.publishAt),
            (tbl) => OrderingTerm.desc(tbl.updatedAt),
          ]))
        .watch();
  }

  Future<void> upsertTimetableSlotRecord({
    required String slotId,
    required String tenantId,
    required String dayOfWeek,
    required int periodIndex,
    required String subjectName,
    String? teacherName,
    String? roomNo,
    String? timeFrom,
    String? timeTo,
    String? classSection,
    bool isActive = true,
    String source = 'local',
    DateTime? updatedAt,
  }) {
    return into(timetableSlotEntries).insertOnConflictUpdate(
      TimetableSlotEntriesCompanion(
        id: Value(slotId),
        tenantId: Value(tenantId),
        dayOfWeek: Value(dayOfWeek),
        periodIndex: Value(periodIndex),
        subjectName: Value(subjectName),
        teacherName: Value(teacherName),
        roomNo: Value(roomNo),
        timeFrom: Value(timeFrom),
        timeTo: Value(timeTo),
        classSection: Value(classSection),
        isActive: Value(isActive),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> deleteTimetableSlotRecord({
    required String tenantId,
    required String slotId,
  }) async {
    await (delete(timetableSlotEntries)..where(
          (tbl) => tbl.tenantId.equals(tenantId) & tbl.id.equals(slotId),
        ))
        .go();
  }

  Stream<List<TimetableSlotEntry>> watchTimetableSlots({
    required String tenantId,
    String? dayOfWeek,
    bool includeInactive = false,
  }) {
    return (select(timetableSlotEntries)
          ..where((tbl) {
            var expression = tbl.tenantId.equals(tenantId);
            if (!includeInactive) {
              expression = expression & tbl.isActive.equals(true);
            }
            if (dayOfWeek != null && dayOfWeek.isNotEmpty) {
              expression = expression & tbl.dayOfWeek.equals(dayOfWeek);
            }
            return expression;
          })
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.dayOfWeek),
            (tbl) => OrderingTerm.asc(tbl.periodIndex),
            (tbl) => OrderingTerm.asc(tbl.timeFrom),
            (tbl) => OrderingTerm.desc(tbl.updatedAt),
          ]))
        .watch();
  }

  Future<void> upsertTransportRouteRecord({
    required String routeId,
    required String tenantId,
    required String routeTitle,
    String? vehicleNo,
    String? vehicleModel,
    String? driverName,
    String? driverContact,
    String? pickupPoint,
    String? destinationPoint,
    String? pickupTime,
    String? dropTime,
    double monthlyFare = 0,
    bool isActive = true,
    String source = 'local',
    DateTime? updatedAt,
  }) {
    return into(transportRouteEntries).insertOnConflictUpdate(
      TransportRouteEntriesCompanion(
        id: Value(routeId),
        tenantId: Value(tenantId),
        routeTitle: Value(routeTitle),
        vehicleNo: Value(vehicleNo),
        vehicleModel: Value(vehicleModel),
        driverName: Value(driverName),
        driverContact: Value(driverContact),
        pickupPoint: Value(pickupPoint),
        destinationPoint: Value(destinationPoint),
        pickupTime: Value(pickupTime),
        dropTime: Value(dropTime),
        monthlyFare: Value(monthlyFare),
        isActive: Value(isActive),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> deleteTransportRouteRecord({
    required String tenantId,
    required String routeId,
  }) async {
    await (delete(transportRouteEntries)..where(
          (tbl) => tbl.tenantId.equals(tenantId) & tbl.id.equals(routeId),
        ))
        .go();
  }

  Stream<List<TransportRouteEntry>> watchTransportRoutes({
    required String tenantId,
    bool includeInactive = false,
  }) {
    return (select(transportRouteEntries)
          ..where((tbl) {
            final byTenant = tbl.tenantId.equals(tenantId);
            if (includeInactive) {
              return byTenant;
            }
            return byTenant & tbl.isActive.equals(true);
          })
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.routeTitle),
            (tbl) => OrderingTerm.desc(tbl.updatedAt),
          ]))
        .watch();
  }

  Future<void> upsertHomeworkAssignmentRecord({
    required String assignmentId,
    required String tenantId,
    required String assignmentType,
    required String title,
    String? subjectName,
    String? classSection,
    String? details,
    DateTime? assignedOn,
    DateTime? dueDate,
    String? attachmentUrl,
    bool isPublished = true,
    bool isActive = true,
    String source = 'local',
    DateTime? updatedAt,
  }) {
    return into(homeworkAssignmentEntries).insertOnConflictUpdate(
      HomeworkAssignmentEntriesCompanion(
        id: Value(assignmentId),
        tenantId: Value(tenantId),
        assignmentType: Value(assignmentType),
        title: Value(title),
        subjectName: Value(subjectName),
        classSection: Value(classSection),
        details: Value(details),
        assignedOn: Value(assignedOn),
        dueDate: Value(dueDate),
        attachmentUrl: Value(attachmentUrl),
        isPublished: Value(isPublished),
        isActive: Value(isActive),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> deleteHomeworkAssignmentRecord({
    required String tenantId,
    required String assignmentId,
  }) async {
    await (delete(homeworkAssignmentEntries)..where(
          (tbl) => tbl.tenantId.equals(tenantId) & tbl.id.equals(assignmentId),
        ))
        .go();
  }

  Stream<List<HomeworkAssignmentEntry>> watchHomeworkAssignments({
    required String tenantId,
    String? assignmentType,
    bool includeInactive = false,
  }) {
    return (select(homeworkAssignmentEntries)
          ..where((tbl) {
            var expression = tbl.tenantId.equals(tenantId);
            if (!includeInactive) {
              expression = expression & tbl.isActive.equals(true);
            }
            if (assignmentType != null && assignmentType.isNotEmpty) {
              expression =
                  expression & tbl.assignmentType.equals(assignmentType);
            }
            return expression;
          })
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.assignedOn),
            (tbl) => OrderingTerm.asc(tbl.dueDate),
            (tbl) => OrderingTerm.desc(tbl.updatedAt),
          ]))
        .watch();
  }

  Future<void> upsertOnlineLearningItemRecord({
    required String itemId,
    required String tenantId,
    required String itemType,
    required String title,
    String? summary,
    String? instructorName,
    String? durationLabel,
    String accessLevel = 'open',
    double priceAmount = 0,
    DateTime? publishedAt,
    bool isPublished = true,
    bool isActive = true,
    String source = 'local',
    DateTime? updatedAt,
  }) {
    return into(onlineLearningEntries).insertOnConflictUpdate(
      OnlineLearningEntriesCompanion(
        id: Value(itemId),
        tenantId: Value(tenantId),
        itemType: Value(itemType),
        title: Value(title),
        summary: Value(summary),
        instructorName: Value(instructorName),
        durationLabel: Value(durationLabel),
        accessLevel: Value(accessLevel),
        priceAmount: Value(priceAmount),
        publishedAt: Value(publishedAt),
        isPublished: Value(isPublished),
        isActive: Value(isActive),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> deleteOnlineLearningItemRecord({
    required String tenantId,
    required String itemId,
  }) async {
    await (delete(onlineLearningEntries)..where(
          (tbl) => tbl.tenantId.equals(tenantId) & tbl.id.equals(itemId),
        ))
        .go();
  }

  Stream<List<OnlineLearningEntry>> watchOnlineLearningItems({
    required String tenantId,
    String? itemType,
    bool includeInactive = false,
  }) {
    return (select(onlineLearningEntries)
          ..where((tbl) {
            var expression = tbl.tenantId.equals(tenantId);
            if (!includeInactive) {
              expression = expression & tbl.isActive.equals(true);
            }
            if (itemType != null && itemType.isNotEmpty) {
              expression = expression & tbl.itemType.equals(itemType);
            }
            return expression;
          })
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.publishedAt),
            (tbl) => OrderingTerm.desc(tbl.updatedAt),
          ]))
        .watch();
  }

  Future<void> upsertLessonRecord({
    required String lessonId,
    required String tenantId,
    required String title,
    String? classSection,
    String? subjectName,
    String? topicName,
    String? lessonDateLabel,
    String? attachmentUrl,
    bool isActive = true,
    String source = 'local',
    DateTime? updatedAt,
  }) {
    return into(lessonEntries).insertOnConflictUpdate(
      LessonEntriesCompanion(
        id: Value(lessonId),
        tenantId: Value(tenantId),
        title: Value(title),
        classSection: Value(classSection),
        subjectName: Value(subjectName),
        topicName: Value(topicName),
        lessonDateLabel: Value(lessonDateLabel),
        attachmentUrl: Value(attachmentUrl),
        isActive: Value(isActive),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> deleteLessonRecord({
    required String tenantId,
    required String lessonId,
  }) async {
    await (delete(lessonEntries)..where(
          (tbl) => tbl.tenantId.equals(tenantId) & tbl.id.equals(lessonId),
        ))
        .go();
  }

  Stream<List<LessonEntry>> watchLessons({
    required String tenantId,
    bool includeInactive = false,
  }) {
    return (select(lessonEntries)
          ..where((tbl) {
            var expression = tbl.tenantId.equals(tenantId);
            if (!includeInactive) {
              expression = expression & tbl.isActive.equals(true);
            }
            return expression;
          })
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.title),
            (tbl) => OrderingTerm.desc(tbl.updatedAt),
          ]))
        .watch();
  }

  Future<void> upsertLessonPlanRecord({
    required String planId,
    required String tenantId,
    required String title,
    String? classSection,
    String? subjectName,
    String? objective,
    String? periodLabel,
    String? activities,
    bool isActive = true,
    String source = 'local',
    DateTime? updatedAt,
  }) {
    return into(lessonPlanEntries).insertOnConflictUpdate(
      LessonPlanEntriesCompanion(
        id: Value(planId),
        tenantId: Value(tenantId),
        title: Value(title),
        classSection: Value(classSection),
        subjectName: Value(subjectName),
        objective: Value(objective),
        periodLabel: Value(periodLabel),
        activities: Value(activities),
        isActive: Value(isActive),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> deleteLessonPlanRecord({
    required String tenantId,
    required String planId,
  }) async {
    await (delete(lessonPlanEntries)..where(
          (tbl) => tbl.tenantId.equals(tenantId) & tbl.id.equals(planId),
        ))
        .go();
  }

  Stream<List<LessonPlanEntry>> watchLessonPlans({
    required String tenantId,
    bool includeInactive = false,
  }) {
    return (select(lessonPlanEntries)
          ..where((tbl) {
            var expression = tbl.tenantId.equals(tenantId);
            if (!includeInactive) {
              expression = expression & tbl.isActive.equals(true);
            }
            return expression;
          })
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.title),
            (tbl) => OrderingTerm.desc(tbl.updatedAt),
          ]))
        .watch();
  }

  Future<void> upsertSubjectRecord({
    required String subjectId,
    required String tenantId,
    required String subjectName,
    String? subjectCode,
    String subjectType = 'theory',
    String? classSection,
    String? teacherName,
    bool isActive = true,
    String source = 'local',
    DateTime? updatedAt,
  }) {
    return into(subjectEntries).insertOnConflictUpdate(
      SubjectEntriesCompanion(
        id: Value(subjectId),
        tenantId: Value(tenantId),
        subjectName: Value(subjectName),
        subjectCode: Value(subjectCode),
        subjectType: Value(subjectType),
        classSection: Value(classSection),
        teacherName: Value(teacherName),
        isActive: Value(isActive),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> deleteSubjectRecord({
    required String tenantId,
    required String subjectId,
  }) async {
    await (delete(subjectEntries)..where(
          (tbl) => tbl.tenantId.equals(tenantId) & tbl.id.equals(subjectId),
        ))
        .go();
  }

  Stream<List<SubjectEntry>> watchSubjects({
    required String tenantId,
    bool includeInactive = false,
  }) {
    return (select(subjectEntries)
          ..where((tbl) {
            var expression = tbl.tenantId.equals(tenantId);
            if (!includeInactive) {
              expression = expression & tbl.isActive.equals(true);
            }
            return expression;
          })
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.subjectName),
            (tbl) => OrderingTerm.desc(tbl.updatedAt),
          ]))
        .watch();
  }

  Future<void> upsertSyllabusRecord({
    required String syllabusId,
    required String tenantId,
    required String title,
    String? classSection,
    String? subjectName,
    String statusLabel = 'pending',
    String? completionPercent,
    DateTime? targetDate,
    String? notes,
    bool isActive = true,
    String source = 'local',
    DateTime? updatedAt,
  }) {
    return into(syllabusEntries).insertOnConflictUpdate(
      SyllabusEntriesCompanion(
        id: Value(syllabusId),
        tenantId: Value(tenantId),
        title: Value(title),
        classSection: Value(classSection),
        subjectName: Value(subjectName),
        statusLabel: Value(statusLabel),
        completionPercent: Value(completionPercent),
        targetDate: Value(targetDate),
        notes: Value(notes),
        isActive: Value(isActive),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> deleteSyllabusRecord({
    required String tenantId,
    required String syllabusId,
  }) async {
    await (delete(syllabusEntries)..where(
          (tbl) => tbl.tenantId.equals(tenantId) & tbl.id.equals(syllabusId),
        ))
        .go();
  }

  Stream<List<SyllabusEntry>> watchSyllabusItems({
    required String tenantId,
    bool includeInactive = false,
  }) {
    return (select(syllabusEntries)
          ..where((tbl) {
            var expression = tbl.tenantId.equals(tenantId);
            if (!includeInactive) {
              expression = expression & tbl.isActive.equals(true);
            }
            return expression;
          })
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.title),
            (tbl) => OrderingTerm.desc(tbl.updatedAt),
          ]))
        .watch();
  }

  Future<void> upsertLibraryBookRecord({
    required String bookId,
    required String tenantId,
    required String bookType,
    required String title,
    String? authorName,
    String? categoryName,
    DateTime? issuedOn,
    DateTime? dueDate,
    DateTime? returnDate,
    double ratingScore = 0,
    int issueCount = 0,
    bool isIssued = false,
    bool isActive = true,
    String source = 'local',
    DateTime? updatedAt,
  }) {
    return into(libraryBookEntries).insertOnConflictUpdate(
      LibraryBookEntriesCompanion(
        id: Value(bookId),
        tenantId: Value(tenantId),
        bookType: Value(bookType),
        title: Value(title),
        authorName: Value(authorName),
        categoryName: Value(categoryName),
        issuedOn: Value(issuedOn),
        dueDate: Value(dueDate),
        returnDate: Value(returnDate),
        ratingScore: Value(ratingScore),
        issueCount: Value(issueCount),
        isIssued: Value(isIssued),
        isActive: Value(isActive),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> deleteLibraryBookRecord({
    required String tenantId,
    required String bookId,
  }) async {
    await (delete(libraryBookEntries)..where(
          (tbl) => tbl.tenantId.equals(tenantId) & tbl.id.equals(bookId),
        ))
        .go();
  }

  Stream<List<LibraryBookEntry>> watchLibraryBooks({
    required String tenantId,
    String? bookType,
    bool includeInactive = false,
  }) {
    return (select(libraryBookEntries)
          ..where((tbl) {
            var expression = tbl.tenantId.equals(tenantId);
            if (!includeInactive) {
              expression = expression & tbl.isActive.equals(true);
            }
            if (bookType != null && bookType.isNotEmpty) {
              expression = expression & tbl.bookType.equals(bookType);
            }
            return expression;
          })
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.ratingScore),
            (tbl) => OrderingTerm.desc(tbl.issueCount),
            (tbl) => OrderingTerm.asc(tbl.title),
          ]))
        .watch();
  }

  Future<void> upsertDocumentCenterRecord({
    required String itemId,
    required String tenantId,
    required String contentType,
    required String title,
    String? description,
    String? fileUrl,
    String? thumbnailUrl,
    String? categoryLabel,
    String uploadState = 'uploaded',
    DateTime? publishedAt,
    bool isActive = true,
    String source = 'local',
    DateTime? updatedAt,
  }) {
    return into(documentCenterEntries).insertOnConflictUpdate(
      DocumentCenterEntriesCompanion(
        id: Value(itemId),
        tenantId: Value(tenantId),
        contentType: Value(contentType),
        title: Value(title),
        description: Value(description),
        fileUrl: Value(fileUrl),
        thumbnailUrl: Value(thumbnailUrl),
        categoryLabel: Value(categoryLabel),
        uploadState: Value(uploadState),
        publishedAt: Value(publishedAt),
        isActive: Value(isActive),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> deleteDocumentCenterRecord({
    required String tenantId,
    required String itemId,
  }) async {
    await (delete(documentCenterEntries)..where(
          (tbl) => tbl.tenantId.equals(tenantId) & tbl.id.equals(itemId),
        ))
        .go();
  }

  Stream<List<DocumentCenterEntry>> watchDocumentCenterItems({
    required String tenantId,
    String? contentType,
    bool includeInactive = false,
  }) {
    return (select(documentCenterEntries)
          ..where((tbl) {
            var expression = tbl.tenantId.equals(tenantId);
            if (!includeInactive) {
              expression = expression & tbl.isActive.equals(true);
            }
            if (contentType != null && contentType.isNotEmpty) {
              expression = expression & tbl.contentType.equals(contentType);
            }
            return expression;
          })
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.publishedAt),
            (tbl) => OrderingTerm.desc(tbl.updatedAt),
          ]))
        .watch();
  }

  Future<void> upsertVisitorCommunicationRecord({
    required String entryId,
    required String tenantId,
    required String entryType,
    String? visitorName,
    String? purpose,
    String? phone,
    DateTime? checkInAt,
    DateTime? checkOutAt,
    String statusLabel = 'open',
    String? note,
    bool isActive = true,
    String source = 'local',
    DateTime? updatedAt,
  }) {
    return into(visitorCommunicationEntries).insertOnConflictUpdate(
      VisitorCommunicationEntriesCompanion(
        id: Value(entryId),
        tenantId: Value(tenantId),
        entryType: Value(entryType),
        visitorName: Value(visitorName),
        purpose: Value(purpose),
        phone: Value(phone),
        checkInAt: Value(checkInAt),
        checkOutAt: Value(checkOutAt),
        statusLabel: Value(statusLabel),
        note: Value(note),
        isActive: Value(isActive),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> deleteVisitorCommunicationRecord({
    required String tenantId,
    required String entryId,
  }) async {
    await (delete(visitorCommunicationEntries)..where(
          (tbl) => tbl.tenantId.equals(tenantId) & tbl.id.equals(entryId),
        ))
        .go();
  }

  Stream<List<VisitorCommunicationEntry>> watchVisitorCommunicationEntries({
    required String tenantId,
    String? entryType,
    bool includeInactive = false,
  }) {
    return (select(visitorCommunicationEntries)
          ..where((tbl) {
            var expression = tbl.tenantId.equals(tenantId);
            if (!includeInactive) {
              expression = expression & tbl.isActive.equals(true);
            }
            if (entryType != null && entryType.isNotEmpty) {
              expression = expression & tbl.entryType.equals(entryType);
            }
            return expression;
          })
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.checkInAt),
            (tbl) => OrderingTerm.desc(tbl.updatedAt),
          ]))
        .watch();
  }

  Future<void> upsertNotificationRecord({
    required String notificationId,
    required String tenantId,
    required String notificationType,
    required String title,
    String? body,
    String audience = 'all',
    bool isRead = false,
    String deliveryStatus = 'queued',
    DateTime? sentAt,
    DateTime? readAt,
    String? payloadJson,
    bool isActive = true,
    String source = 'local',
    DateTime? updatedAt,
  }) {
    return into(notificationEntries).insertOnConflictUpdate(
      NotificationEntriesCompanion(
        id: Value(notificationId),
        tenantId: Value(tenantId),
        notificationType: Value(notificationType),
        title: Value(title),
        body: Value(body),
        audience: Value(audience),
        isRead: Value(isRead),
        deliveryStatus: Value(deliveryStatus),
        sentAt: Value(sentAt),
        readAt: Value(readAt),
        payloadJson: Value(payloadJson),
        isActive: Value(isActive),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> markNotificationRead({
    required String tenantId,
    required String notificationId,
    required DateTime readAt,
  }) async {
    await (update(notificationEntries)..where(
          (tbl) =>
              tbl.tenantId.equals(tenantId) & tbl.id.equals(notificationId),
        ))
        .write(
          NotificationEntriesCompanion(
            isRead: const Value(true),
            readAt: Value(readAt),
            deliveryStatus: const Value('read'),
            updatedAt: Value(readAt),
          ),
        );
  }

  Future<void> deleteNotificationRecord({
    required String tenantId,
    required String notificationId,
  }) async {
    await (delete(notificationEntries)..where(
          (tbl) =>
              tbl.tenantId.equals(tenantId) & tbl.id.equals(notificationId),
        ))
        .go();
  }

  Stream<List<NotificationEntry>> watchNotifications({
    required String tenantId,
    bool unreadOnly = false,
    bool includeInactive = false,
  }) {
    return (select(notificationEntries)
          ..where((tbl) {
            var expression = tbl.tenantId.equals(tenantId);
            if (unreadOnly) {
              expression = expression & tbl.isRead.equals(false);
            }
            if (!includeInactive) {
              expression = expression & tbl.isActive.equals(true);
            }
            return expression;
          })
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.sentAt),
            (tbl) => OrderingTerm.desc(tbl.updatedAt),
          ]))
        .watch();
  }

  Future<void> upsertLiveClassRecord({
    required String classId,
    required String tenantId,
    required String providerType,
    required String title,
    String? classSection,
    String? hostName,
    DateTime? startAt,
    DateTime? endAt,
    String? joinUrl,
    String? meetingId,
    String? meetingPassword,
    String statusLabel = 'scheduled',
    bool isActive = true,
    String source = 'local',
    DateTime? updatedAt,
  }) {
    return into(liveClassEntries).insertOnConflictUpdate(
      LiveClassEntriesCompanion(
        id: Value(classId),
        tenantId: Value(tenantId),
        providerType: Value(providerType),
        title: Value(title),
        classSection: Value(classSection),
        hostName: Value(hostName),
        startAt: Value(startAt),
        endAt: Value(endAt),
        joinUrl: Value(joinUrl),
        meetingId: Value(meetingId),
        meetingPassword: Value(meetingPassword),
        statusLabel: Value(statusLabel),
        isActive: Value(isActive),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> deleteLiveClassRecord({
    required String tenantId,
    required String classId,
  }) async {
    await (delete(liveClassEntries)..where(
          (tbl) => tbl.tenantId.equals(tenantId) & tbl.id.equals(classId),
        ))
        .go();
  }

  Stream<List<LiveClassEntry>> watchLiveClasses({
    required String tenantId,
    String? providerType,
    bool includeInactive = false,
  }) {
    return (select(liveClassEntries)
          ..where((tbl) {
            var expression = tbl.tenantId.equals(tenantId);
            if (!includeInactive) {
              expression = expression & tbl.isActive.equals(true);
            }
            if (providerType != null && providerType.isNotEmpty) {
              expression = expression & tbl.providerType.equals(providerType);
            }
            return expression;
          })
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.startAt),
            (tbl) => OrderingTerm.desc(tbl.updatedAt),
          ]))
        .watch();
  }

  Future<void> upsertLeaveRequestRecord({
    required String leaveId,
    required String tenantId,
    String? requesterId,
    DateTime? leaveFrom,
    DateTime? leaveTo,
    DateTime? appliedAt,
    String? reason,
    String statusLabel = 'pending',
    String? approverName,
    DateTime? approvedAt,
    String? attachmentUrl,
    bool isActive = true,
    String source = 'local',
    DateTime? updatedAt,
  }) {
    return into(leaveRequestEntries).insertOnConflictUpdate(
      LeaveRequestEntriesCompanion(
        id: Value(leaveId),
        tenantId: Value(tenantId),
        requesterId: Value(requesterId),
        leaveFrom: Value(leaveFrom),
        leaveTo: Value(leaveTo),
        appliedAt: Value(appliedAt),
        reason: Value(reason),
        statusLabel: Value(statusLabel),
        approverName: Value(approverName),
        approvedAt: Value(approvedAt),
        attachmentUrl: Value(attachmentUrl),
        isActive: Value(isActive),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> deleteLeaveRequestRecord({
    required String tenantId,
    required String leaveId,
  }) async {
    await (delete(leaveRequestEntries)..where(
          (tbl) => tbl.tenantId.equals(tenantId) & tbl.id.equals(leaveId),
        ))
        .go();
  }

  Stream<List<LeaveRequestEntry>> watchLeaveRequests({
    required String tenantId,
    bool includeInactive = false,
  }) {
    return (select(leaveRequestEntries)
          ..where((tbl) {
            var expression = tbl.tenantId.equals(tenantId);
            if (!includeInactive) {
              expression = expression & tbl.isActive.equals(true);
            }
            return expression;
          })
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.appliedAt),
            (tbl) => OrderingTerm.desc(tbl.updatedAt),
          ]))
        .watch();
  }

  Future<void> upsertPendingTaskRecord({
    required String taskId,
    required String tenantId,
    String? userId,
    required String title,
    DateTime? dueDate,
    String statusLabel = 'pending',
    bool isCompleted = false,
    String priority = 'medium',
    bool isActive = true,
    String source = 'local',
    DateTime? updatedAt,
  }) {
    return into(pendingTaskEntries).insertOnConflictUpdate(
      PendingTaskEntriesCompanion(
        id: Value(taskId),
        tenantId: Value(tenantId),
        userId: Value(userId),
        title: Value(title),
        dueDate: Value(dueDate),
        statusLabel: Value(statusLabel),
        isCompleted: Value(isCompleted),
        priority: Value(priority),
        isActive: Value(isActive),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> deletePendingTaskRecord({
    required String tenantId,
    required String taskId,
  }) async {
    await (delete(pendingTaskEntries)..where(
          (tbl) => tbl.tenantId.equals(tenantId) & tbl.id.equals(taskId),
        ))
        .go();
  }

  Stream<List<PendingTaskEntry>> watchPendingTasks({
    required String tenantId,
    bool includeInactive = false,
  }) {
    return (select(pendingTaskEntries)
          ..where((tbl) {
            var expression = tbl.tenantId.equals(tenantId);
            if (!includeInactive) {
              expression = expression & tbl.isActive.equals(true);
            }
            return expression;
          })
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.isCompleted),
            (tbl) => OrderingTerm.asc(tbl.dueDate),
            (tbl) => OrderingTerm.desc(tbl.updatedAt),
          ]))
        .watch();
  }

  Future<void> upsertHostelRoomRecord({
    required String roomId,
    required String tenantId,
    String? studentId,
    String? hostelName,
    String? roomNo,
    String? roomType,
    String? floorNo,
    String? bedNo,
    String? wardenName,
    String? wardenContact,
    double monthlyFees = 0,
    bool isActive = true,
    String source = 'local',
    DateTime? updatedAt,
  }) {
    return into(hostelRoomEntries).insertOnConflictUpdate(
      HostelRoomEntriesCompanion(
        id: Value(roomId),
        tenantId: Value(tenantId),
        studentId: Value(studentId),
        hostelName: Value(hostelName),
        roomNo: Value(roomNo),
        roomType: Value(roomType),
        floorNo: Value(floorNo),
        bedNo: Value(bedNo),
        wardenName: Value(wardenName),
        wardenContact: Value(wardenContact),
        monthlyFees: Value(monthlyFees),
        isActive: Value(isActive),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> deleteHostelRoomRecord({
    required String tenantId,
    required String roomId,
  }) async {
    await (delete(hostelRoomEntries)..where(
          (tbl) => tbl.tenantId.equals(tenantId) & tbl.id.equals(roomId),
        ))
        .go();
  }

  Stream<List<HostelRoomEntry>> watchHostelRooms({
    required String tenantId,
    bool includeInactive = false,
  }) {
    return (select(hostelRoomEntries)
          ..where((tbl) {
            var expression = tbl.tenantId.equals(tenantId);
            if (!includeInactive) {
              expression = expression & tbl.isActive.equals(true);
            }
            return expression;
          })
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.hostelName),
            (tbl) => OrderingTerm.asc(tbl.roomNo),
            (tbl) => OrderingTerm.desc(tbl.updatedAt),
          ]))
        .watch();
  }

  Future<void> upsertStudentAttendanceRecord({
    required String recordId,
    required String tenantId,
    required String studentId,
    required DateTime attendanceDate,
    required String status,
    String source = 'local',
    DateTime? updatedAt,
  }) {
    return into(studentAttendanceRecords).insertOnConflictUpdate(
      StudentAttendanceRecordsCompanion(
        id: Value(recordId),
        tenantId: Value(tenantId),
        studentId: Value(studentId),
        attendanceDate: Value(attendanceDate),
        status: Value(status),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> createOrUpdateStudentProfile({
    required String studentId,
    required String tenantId,
    required String admissionNo,
    required String fullName,
    String? classSection,
    bool isActive = true,
    DateTime? updatedAt,
  }) {
    return into(studentDirectoryEntries).insertOnConflictUpdate(
      StudentDirectoryEntriesCompanion(
        id: Value(studentId),
        tenantId: Value(tenantId),
        admissionNo: Value(admissionNo),
        fullName: Value(fullName),
        classSection: Value(classSection),
        isActive: Value(isActive),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> upsertStudentProfileFromRemote({
    required String studentId,
    required String tenantId,
    required String admissionNo,
    required String fullName,
    String? classSection,
    required bool isActive,
    required DateTime updatedAt,
  }) {
    return into(studentDirectoryEntries).insertOnConflictUpdate(
      StudentDirectoryEntriesCompanion(
        id: Value(studentId),
        tenantId: Value(tenantId),
        admissionNo: Value(admissionNo),
        fullName: Value(fullName),
        classSection: Value(classSection),
        isActive: Value(isActive),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  Future<void> upsertStudentGuardianRecord({
    required String guardianId,
    required String tenantId,
    required String studentId,
    required String fullName,
    required String relation,
    String? phone,
    String? email,
    bool isPrimary = false,
    bool isActive = true,
    String source = 'local',
    DateTime? updatedAt,
  }) {
    return into(studentGuardianEntries).insertOnConflictUpdate(
      StudentGuardianEntriesCompanion(
        id: Value(guardianId),
        tenantId: Value(tenantId),
        studentId: Value(studentId),
        fullName: Value(fullName),
        relation: Value(relation),
        phone: Value(phone),
        email: Value(email),
        isPrimary: Value(isPrimary),
        isActive: Value(isActive),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Stream<List<StudentGuardianEntry>> watchStudentGuardians({
    required String tenantId,
    required String studentId,
    bool? isActive,
  }) {
    return (select(studentGuardianEntries)
          ..where((tbl) {
            final base =
                tbl.tenantId.equals(tenantId) & tbl.studentId.equals(studentId);
            if (isActive == null) {
              return base;
            }
            return base & tbl.isActive.equals(isActive);
          })
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.isPrimary),
            (tbl) => OrderingTerm.asc(tbl.fullName),
          ]))
        .watch();
  }

  Future<void> upsertStudentEnrollmentRecord({
    required String enrollmentId,
    required String tenantId,
    required String studentId,
    required String academicSession,
    required String enrollmentStatus,
    DateTime? enrolledOn,
    DateTime? leftOn,
    String? remarks,
    String source = 'local',
    DateTime? updatedAt,
  }) {
    return into(studentEnrollmentEntries).insertOnConflictUpdate(
      StudentEnrollmentEntriesCompanion(
        id: Value(enrollmentId),
        tenantId: Value(tenantId),
        studentId: Value(studentId),
        academicSession: Value(academicSession),
        enrollmentStatus: Value(enrollmentStatus),
        enrolledOn: Value(enrolledOn),
        leftOn: Value(leftOn),
        remarks: Value(remarks),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Stream<List<StudentEnrollmentEntry>> watchStudentEnrollments({
    required String tenantId,
    required String studentId,
    String? academicSession,
  }) {
    return (select(studentEnrollmentEntries)
          ..where((tbl) {
            final base =
                tbl.tenantId.equals(tenantId) & tbl.studentId.equals(studentId);
            if (academicSession == null || academicSession.isEmpty) {
              return base;
            }
            return base & tbl.academicSession.equals(academicSession);
          })
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.updatedAt),
            (tbl) => OrderingTerm.desc(tbl.academicSession),
          ]))
        .watch();
  }

  Future<void> upsertStudentClassRollRecord({
    required String classRollId,
    required String tenantId,
    required String studentId,
    required String academicSession,
    required String className,
    String? sectionName,
    String? rollNo,
    bool isActive = true,
    String source = 'local',
    DateTime? updatedAt,
  }) {
    return into(studentClassRollEntries).insertOnConflictUpdate(
      StudentClassRollEntriesCompanion(
        id: Value(classRollId),
        tenantId: Value(tenantId),
        studentId: Value(studentId),
        academicSession: Value(academicSession),
        className: Value(className),
        sectionName: Value(sectionName),
        rollNo: Value(rollNo),
        isActive: Value(isActive),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Stream<List<StudentClassRollEntry>> watchStudentClassRolls({
    required String tenantId,
    required String studentId,
    String? academicSession,
  }) {
    return (select(studentClassRollEntries)
          ..where((tbl) {
            final base =
                tbl.tenantId.equals(tenantId) & tbl.studentId.equals(studentId);
            if (academicSession == null || academicSession.isEmpty) {
              return base;
            }
            return base & tbl.academicSession.equals(academicSession);
          })
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.updatedAt),
            (tbl) => OrderingTerm.desc(tbl.academicSession),
            (tbl) => OrderingTerm.asc(tbl.className),
          ]))
        .watch();
  }

  Stream<List<StudentDirectoryEntry>> watchActiveStudentProfiles({
    required String tenantId,
  }) {
    return (select(studentDirectoryEntries)
          ..where(
            (tbl) => tbl.tenantId.equals(tenantId) & tbl.isActive.equals(true),
          )
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.fullName),
            (tbl) => OrderingTerm.asc(tbl.admissionNo),
          ]))
        .watch();
  }

  Stream<List<StudentAttendanceRecord>> watchStudentAttendanceRange({
    required String tenantId,
    required String studentId,
    required DateTime from,
    required DateTime to,
  }) {
    return (select(studentAttendanceRecords)
          ..where(
            (tbl) =>
                tbl.tenantId.equals(tenantId) &
                tbl.studentId.equals(studentId) &
                tbl.attendanceDate.isBiggerOrEqualValue(from) &
                tbl.attendanceDate.isSmallerOrEqualValue(to),
          )
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.attendanceDate)]))
        .watch();
  }

  Future<void> upsertFeeInvoiceRecord({
    required String recordId,
    required String tenantId,
    required String studentId,
    required String invoiceNo,
    required double amountDue,
    double amountPaid = 0,
    String status = 'due',
    DateTime? dueDate,
    String source = 'local',
    DateTime? updatedAt,
  }) {
    return into(feeInvoiceEntries).insertOnConflictUpdate(
      FeeInvoiceEntriesCompanion(
        id: Value(recordId),
        tenantId: Value(tenantId),
        studentId: Value(studentId),
        invoiceNo: Value(invoiceNo),
        amountDue: Value(amountDue),
        amountPaid: Value(amountPaid),
        status: Value(status),
        dueDate: Value(dueDate),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Stream<List<FeeInvoiceEntry>> watchFeeInvoicesByStudent({
    required String tenantId,
    required String studentId,
    String? status,
  }) {
    return (select(feeInvoiceEntries)
          ..where((tbl) {
            final base =
                tbl.tenantId.equals(tenantId) & tbl.studentId.equals(studentId);
            if (status == null || status.isEmpty) {
              return base;
            }
            return base & tbl.status.equals(status);
          })
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]))
        .watch();
  }

  Future<void> upsertFeePaymentRecord({
    required String paymentId,
    required String tenantId,
    required String invoiceId,
    required String studentId,
    required double amount,
    required DateTime paidAt,
    String paymentMethod = 'cash',
    String? referenceNo,
    String source = 'local',
    DateTime? updatedAt,
  }) {
    return into(feePaymentEntries).insertOnConflictUpdate(
      FeePaymentEntriesCompanion(
        id: Value(paymentId),
        tenantId: Value(tenantId),
        invoiceId: Value(invoiceId),
        studentId: Value(studentId),
        amount: Value(amount),
        paidAt: Value(paidAt),
        paymentMethod: Value(paymentMethod),
        referenceNo: Value(referenceNo),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Stream<List<FeePaymentEntry>> watchFeePaymentsByInvoice({
    required String tenantId,
    required String invoiceId,
  }) {
    return (select(feePaymentEntries)
          ..where(
            (tbl) =>
                tbl.tenantId.equals(tenantId) & tbl.invoiceId.equals(invoiceId),
          )
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.paidAt)]))
        .watch();
  }

  Future<void> upsertExamScheduleRecord({
    required String scheduleId,
    required String tenantId,
    required String examName,
    required String subjectName,
    required double maxMarks,
    required DateTime examDate,
    String source = 'local',
    DateTime? updatedAt,
  }) {
    return into(examScheduleEntries).insertOnConflictUpdate(
      ExamScheduleEntriesCompanion(
        id: Value(scheduleId),
        tenantId: Value(tenantId),
        examName: Value(examName),
        subjectName: Value(subjectName),
        maxMarks: Value(maxMarks),
        examDate: Value(examDate),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<List<String>> getExamMarkIdsBySchedule({
    required String tenantId,
    required String scheduleId,
  }) async {
    final rows =
        await (selectOnly(studentExamMarkEntries)
              ..addColumns([studentExamMarkEntries.id])
              ..where(
                studentExamMarkEntries.tenantId.equals(tenantId) &
                    studentExamMarkEntries.scheduleId.equals(scheduleId),
              ))
            .get();

    return rows
        .map((row) => row.read(studentExamMarkEntries.id))
        .whereType<String>()
        .toList();
  }

  Future<void> deleteExamScheduleCascade({
    required String tenantId,
    required String scheduleId,
  }) async {
    await transaction(() async {
      await (delete(studentExamMarkEntries)..where(
            (tbl) =>
                tbl.tenantId.equals(tenantId) &
                tbl.scheduleId.equals(scheduleId),
          ))
          .go();

      await (delete(examScheduleEntries)..where(
            (tbl) => tbl.tenantId.equals(tenantId) & tbl.id.equals(scheduleId),
          ))
          .go();
    });
  }

  Stream<List<ExamScheduleEntry>> watchExamSchedulesInMonth({
    required String tenantId,
    required DateTime from,
    required DateTime to,
  }) {
    return (select(examScheduleEntries)
          ..where(
            (tbl) =>
                tbl.tenantId.equals(tenantId) &
                tbl.examDate.isBiggerOrEqualValue(from) &
                tbl.examDate.isSmallerOrEqualValue(to),
          )
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.examDate),
            (tbl) => OrderingTerm.asc(tbl.subjectName),
          ]))
        .watch();
  }

  Future<void> upsertStudentExamMarkRecord({
    required String markId,
    required String tenantId,
    required String studentId,
    required String scheduleId,
    required double marksObtained,
    String? grade,
    String source = 'local',
    DateTime? updatedAt,
  }) {
    return into(studentExamMarkEntries).insertOnConflictUpdate(
      StudentExamMarkEntriesCompanion(
        id: Value(markId),
        tenantId: Value(tenantId),
        studentId: Value(studentId),
        scheduleId: Value(scheduleId),
        marksObtained: Value(marksObtained),
        grade: Value(grade),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> deleteStudentExamMarkRecord({
    required String tenantId,
    required String markId,
  }) async {
    await (delete(studentExamMarkEntries)..where(
          (tbl) => tbl.tenantId.equals(tenantId) & tbl.id.equals(markId),
        ))
        .go();
  }

  Stream<List<StudentExamMarkView>> watchStudentExamMarkViews({
    required String tenantId,
    required String studentId,
    required DateTime from,
    required DateTime to,
  }) {
    return customSelect(
      '''
      SELECT
        m.id AS mark_id,
        m.schedule_id AS schedule_id,
        s.exam_name AS exam_name,
        s.subject_name AS subject_name,
        s.max_marks AS max_marks,
        s.exam_date AS exam_date,
        m.marks_obtained AS marks_obtained,
        m.grade AS grade,
        m.updated_at AS updated_at
      FROM student_exam_mark_entries m
      INNER JOIN exam_schedule_entries s ON s.id = m.schedule_id
      WHERE m.tenant_id = ?
        AND m.student_id = ?
        AND s.exam_date >= ?
        AND s.exam_date <= ?
      ORDER BY s.exam_date DESC, s.subject_name ASC
      ''',
      variables: [
        Variable<String>(tenantId),
        Variable<String>(studentId),
        Variable<DateTime>(from),
        Variable<DateTime>(to),
      ],
      readsFrom: {studentExamMarkEntries, examScheduleEntries},
    ).watch().map(
      (rows) => rows
          .map(
            (row) => StudentExamMarkView(
              markId: row.read<String>('mark_id'),
              scheduleId: row.read<String>('schedule_id'),
              examName: row.read<String>('exam_name'),
              subjectName: row.read<String>('subject_name'),
              maxMarks: row.read<double>('max_marks'),
              examDate: row.read<DateTime>('exam_date'),
              marksObtained: row.read<double>('marks_obtained'),
              grade: row.readNullable<String>('grade'),
              updatedAt: row.read<DateTime>('updated_at'),
            ),
          )
          .toList(),
    );
  }

  Stream<List<ExamAnalyticsMarkRow>> watchExamAnalyticsMarkRowsInMonth({
    required String tenantId,
    required DateTime from,
    required DateTime to,
  }) {
    return customSelect(
      '''
      SELECT
        m.id AS mark_id,
        m.student_id AS student_id,
        d.full_name AS student_name,
        d.admission_no AS admission_no,
        d.class_section AS class_section,
        m.schedule_id AS schedule_id,
        s.exam_name AS exam_name,
        s.subject_name AS subject_name,
        s.max_marks AS max_marks,
        s.exam_date AS exam_date,
        m.marks_obtained AS marks_obtained,
        m.grade AS grade,
        m.updated_at AS updated_at
      FROM student_exam_mark_entries m
      INNER JOIN exam_schedule_entries s
        ON s.id = m.schedule_id
        AND s.tenant_id = m.tenant_id
      LEFT JOIN student_directory_entries d
        ON d.id = m.student_id
        AND d.tenant_id = m.tenant_id
      WHERE m.tenant_id = ?
        AND s.exam_date >= ?
        AND s.exam_date <= ?
      ORDER BY s.exam_date DESC, s.subject_name ASC, m.marks_obtained DESC
      ''',
      variables: [
        Variable<String>(tenantId),
        Variable<DateTime>(from),
        Variable<DateTime>(to),
      ],
      readsFrom: {
        studentExamMarkEntries,
        examScheduleEntries,
        studentDirectoryEntries,
      },
    ).watch().map(
      (rows) => rows
          .map(
            (row) => ExamAnalyticsMarkRow(
              markId: row.read<String>('mark_id'),
              studentId: row.read<String>('student_id'),
              studentName: row.readNullable<String>('student_name'),
              admissionNo: row.readNullable<String>('admission_no'),
              classSection: row.readNullable<String>('class_section'),
              scheduleId: row.read<String>('schedule_id'),
              examName: row.read<String>('exam_name'),
              subjectName: row.read<String>('subject_name'),
              maxMarks: row.read<double>('max_marks'),
              examDate: row.read<DateTime>('exam_date'),
              marksObtained: row.read<double>('marks_obtained'),
              grade: row.readNullable<String>('grade'),
              updatedAt: row.read<DateTime>('updated_at'),
            ),
          )
          .toList(),
    );
  }

  Stream<List<SchoolOwnerView>> watchSchoolOwnerViews() {
    return customSelect(
      '''
      SELECT
        o.id AS owner_id,
        o.tenant_id AS tenant_id,
        t.name AS tenant_name,
        o.full_name AS full_name,
        o.email AS email,
        o.phone AS phone,
        o.is_primary AS is_primary,
        o.is_active AS is_active,
        o.provisioning_status AS provisioning_status,
        o.created_at AS created_at,
        o.updated_at AS updated_at
      FROM school_owner_entries o
      INNER JOIN tenant_records t ON t.id = o.tenant_id
      ORDER BY o.updated_at DESC
      ''',
      readsFrom: {schoolOwnerEntries, tenantRecords},
    ).watch().map(
      (rows) => rows
          .map(
            (row) => SchoolOwnerView(
              ownerId: row.read<String>('owner_id'),
              tenantId: row.read<String>('tenant_id'),
              tenantName: row.read<String>('tenant_name'),
              fullName: row.read<String>('full_name'),
              email: row.read<String>('email'),
              phone: row.readNullable<String>('phone'),
              isPrimary: row.read<bool>('is_primary'),
              isActive: row.read<bool>('is_active'),
              provisioningStatus: row.read<String>('provisioning_status'),
              createdAt: row.read<DateTime>('created_at'),
              updatedAt: row.read<DateTime>('updated_at'),
            ),
          )
          .toList(),
    );
  }

  Future<int> processPendingBatch({int limit = 50}) async {
    final pendingRows =
        await (select(syncQueueEntries)
              ..where((tbl) => tbl.status.equals('pending'))
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)])
              ..limit(limit))
            .get();

    for (final row in pendingRows) {
      // Placeholder behavior for phase-1 bootstrap: mark queued ops as synced.
      await (update(
        syncQueueEntries,
      )..where((tbl) => tbl.id.equals(row.id))).write(
        SyncQueueEntriesCompanion(
          status: const Value('synced'),
          lastAttemptAt: Value(DateTime.now()),
        ),
      );
    }

    return pendingRows.length;
  }

  // ── Homework Submissions ──────────────────────────────────────────────────

  Future<void> upsertHomeworkSubmissionRecord({
    required String submissionId,
    required String tenantId,
    required String assignmentId,
    required String studentId,
    String? submissionText,
    String? attachmentUrl,
    String statusLabel = 'submitted',
    String? teacherFeedback,
    double? gradeScore,
    DateTime? submittedAt,
    DateTime? reviewedAt,
    bool isActive = true,
    String source = 'local',
    DateTime? updatedAt,
  }) {
    return into(homeworkSubmissionEntries).insertOnConflictUpdate(
      HomeworkSubmissionEntriesCompanion(
        id: Value(submissionId),
        tenantId: Value(tenantId),
        assignmentId: Value(assignmentId),
        studentId: Value(studentId),
        submissionText: Value(submissionText),
        attachmentUrl: Value(attachmentUrl),
        statusLabel: Value(statusLabel),
        teacherFeedback: Value(teacherFeedback),
        gradeScore: Value(gradeScore),
        submittedAt: Value(submittedAt),
        reviewedAt: Value(reviewedAt),
        isActive: Value(isActive),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> deleteHomeworkSubmissionRecord({
    required String tenantId,
    required String submissionId,
  }) async {
    await (delete(homeworkSubmissionEntries)..where(
          (tbl) =>
              tbl.tenantId.equals(tenantId) & tbl.id.equals(submissionId),
        ))
        .go();
  }

  Stream<List<HomeworkSubmissionEntry>> watchHomeworkSubmissions({
    required String tenantId,
    required String assignmentId,
  }) {
    return (select(homeworkSubmissionEntries)
          ..where(
            (tbl) =>
                tbl.tenantId.equals(tenantId) &
                tbl.assignmentId.equals(assignmentId) &
                tbl.isActive.equals(true),
          )
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]))
        .watch();
  }

  Stream<List<HomeworkSubmissionEntry>> watchStudentSubmissions({
    required String tenantId,
    required String studentId,
  }) {
    return (select(homeworkSubmissionEntries)
          ..where(
            (tbl) =>
                tbl.tenantId.equals(tenantId) &
                tbl.studentId.equals(studentId) &
                tbl.isActive.equals(true),
          )
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]))
        .watch();
  }

  // ── Online Learning Attempts ──────────────────────────────────────────────

  Future<void> upsertOnlineLearningAttemptRecord({
    required String attemptId,
    required String tenantId,
    required String itemId,
    required String studentId,
    String attemptStatus = 'in_progress',
    double? scorePercent,
    int? durationSeconds,
    DateTime? startedAt,
    DateTime? completedAt,
    bool isPassed = false,
    bool isActive = true,
    String source = 'local',
    DateTime? updatedAt,
  }) {
    return into(onlineLearningAttemptEntries).insertOnConflictUpdate(
      OnlineLearningAttemptEntriesCompanion(
        id: Value(attemptId),
        tenantId: Value(tenantId),
        itemId: Value(itemId),
        studentId: Value(studentId),
        attemptStatus: Value(attemptStatus),
        scorePercent: Value(scorePercent),
        durationSeconds: Value(durationSeconds),
        startedAt: Value(startedAt),
        completedAt: Value(completedAt),
        isPassed: Value(isPassed),
        isActive: Value(isActive),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> deleteOnlineLearningAttemptRecord({
    required String tenantId,
    required String attemptId,
  }) async {
    await (delete(onlineLearningAttemptEntries)..where(
          (tbl) =>
              tbl.tenantId.equals(tenantId) & tbl.id.equals(attemptId),
        ))
        .go();
  }

  Stream<List<OnlineLearningAttemptEntry>> watchItemAttempts({
    required String tenantId,
    required String itemId,
  }) {
    return (select(onlineLearningAttemptEntries)
          ..where(
            (tbl) =>
                tbl.tenantId.equals(tenantId) &
                tbl.itemId.equals(itemId) &
                tbl.isActive.equals(true),
          )
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]))
        .watch();
  }

  Stream<List<OnlineLearningAttemptEntry>> watchStudentAttempts({
    required String tenantId,
    required String studentId,
  }) {
    return (select(onlineLearningAttemptEntries)
          ..where(
            (tbl) =>
                tbl.tenantId.equals(tenantId) &
                tbl.studentId.equals(studentId) &
                tbl.isActive.equals(true),
          )
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]))
        .watch();
  }

  // ── Fee Groups (enterprise fees) ─────────────────────────────────────────

  Future<void> upsertFeeGroupRecord({
    required String feeId,
    required String tenantId,
    required String studentId,
    required String feeTitle,
    String? feeCode,
    double amount = 0,
    double discount = 0,
    double fine = 0,
    double paid = 0,
    double balance = 0,
    String status = 'unpaid',
    String? dueDate,
    bool isPayable = false,
    String? paymentMode,
    String? paymentId,
    String? paymentDate,
    String feeType = 'fee',
    String? reference,
    String? comments,
    String source = 'remote',
    DateTime? updatedAt,
  }) {
    return into(feeGroupEntries).insertOnConflictUpdate(
      FeeGroupEntriesCompanion(
        id: Value(feeId),
        tenantId: Value(tenantId),
        studentId: Value(studentId),
        feeTitle: Value(feeTitle),
        feeCode: Value(feeCode),
        amount: Value(amount),
        discount: Value(discount),
        fine: Value(fine),
        paid: Value(paid),
        balance: Value(balance),
        status: Value(status),
        dueDate: Value(dueDate),
        isPayable: Value(isPayable),
        paymentMode: Value(paymentMode),
        paymentId: Value(paymentId),
        paymentDate: Value(paymentDate),
        feeType: Value(feeType),
        reference: Value(reference),
        comments: Value(comments),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> deleteFeeGroupRecord({
    required String tenantId,
    required String feeId,
  }) async {
    await (delete(feeGroupEntries)..where(
          (tbl) => tbl.tenantId.equals(tenantId) & tbl.id.equals(feeId),
        ))
        .go();
  }

  Stream<List<FeeGroupEntry>> watchFeeGroups({
    required String tenantId,
    required String studentId,
    String? feeType,
  }) {
    return (select(feeGroupEntries)
          ..where((tbl) {
            final base =
                tbl.tenantId.equals(tenantId) &
                tbl.studentId.equals(studentId);
            if (feeType != null) return base & tbl.feeType.equals(feeType);
            return base;
          })
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.feeTitle)]))
        .watch();
  }

  // ── CBSE Exam Results ─────────────────────────────────────────────────────

  Future<void> upsertCbseExamResultRecord({
    required String resultId,
    required String tenantId,
    required String studentId,
    required String examName,
    required String subjectName,
    String? subjectCode,
    String? assessmentName,
    double? marksObtained,
    double? maxMarks,
    String? examDate,
    String? grade,
    String? rank,
    String? percentage,
    String? totalObtained,
    String? totalMax,
    String resultType = 'result',
    String? roomNo,
    String? timeFrom,
    String? duration,
    String source = 'remote',
    DateTime? updatedAt,
  }) {
    return into(cbseExamResultEntries).insertOnConflictUpdate(
      CbseExamResultEntriesCompanion(
        id: Value(resultId),
        tenantId: Value(tenantId),
        studentId: Value(studentId),
        examName: Value(examName),
        subjectName: Value(subjectName),
        subjectCode: Value(subjectCode),
        assessmentName: Value(assessmentName),
        marksObtained: Value(marksObtained),
        maxMarks: Value(maxMarks),
        examDate: Value(examDate),
        grade: Value(grade),
        rank: Value(rank),
        percentage: Value(percentage),
        totalObtained: Value(totalObtained),
        totalMax: Value(totalMax),
        resultType: Value(resultType),
        roomNo: Value(roomNo),
        timeFrom: Value(timeFrom),
        duration: Value(duration),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> deleteCbseExamResultRecord({
    required String tenantId,
    required String resultId,
  }) async {
    await (delete(cbseExamResultEntries)..where(
          (tbl) => tbl.tenantId.equals(tenantId) & tbl.id.equals(resultId),
        ))
        .go();
  }

  Stream<List<CbseExamResultEntry>> watchCbseExamResults({
    required String tenantId,
    required String studentId,
    String resultType = 'result',
  }) {
    return (select(cbseExamResultEntries)
          ..where(
            (tbl) =>
                tbl.tenantId.equals(tenantId) &
                tbl.studentId.equals(studentId) &
                tbl.resultType.equals(resultType),
          )
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.examName),
            (tbl) => OrderingTerm.asc(tbl.subjectName),
          ]))
        .watch();
  }

  // ── Online Exams ──────────────────────────────────────────────────────────

  Future<void> upsertOnlineExamRecord({
    required String examId,
    required String tenantId,
    required String examTitle,
    String? description,
    String? examFrom,
    String? examTo,
    int totalQuestions = 0,
    int totalAttempt = 1,
    int durationMinutes = 0,
    double passingPercent = 35,
    bool isQuiz = false,
    String statusLabel = 'upcoming',
    int attemptCount = 0,
    bool isSubmitted = false,
    double? lastScorePercent,
    bool isPassed = false,
    bool isActive = true,
    String source = 'remote',
    DateTime? updatedAt,
  }) {
    return into(onlineExamEntries).insertOnConflictUpdate(
      OnlineExamEntriesCompanion(
        id: Value(examId),
        tenantId: Value(tenantId),
        examTitle: Value(examTitle),
        description: Value(description),
        examFrom: Value(examFrom),
        examTo: Value(examTo),
        totalQuestions: Value(totalQuestions),
        totalAttempt: Value(totalAttempt),
        durationMinutes: Value(durationMinutes),
        passingPercent: Value(passingPercent),
        isQuiz: Value(isQuiz),
        statusLabel: Value(statusLabel),
        attemptCount: Value(attemptCount),
        isSubmitted: Value(isSubmitted),
        lastScorePercent: Value(lastScorePercent),
        isPassed: Value(isPassed),
        isActive: Value(isActive),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> deleteOnlineExamRecord({
    required String tenantId,
    required String examId,
  }) async {
    await (delete(onlineExamEntries)..where(
          (tbl) => tbl.tenantId.equals(tenantId) & tbl.id.equals(examId),
        ))
        .go();
  }

  Stream<List<OnlineExamEntry>> watchOnlineExams({
    required String tenantId,
    bool? isSubmitted,
  }) {
    return (select(onlineExamEntries)
          ..where((tbl) {
            final base =
                tbl.tenantId.equals(tenantId) & tbl.isActive.equals(true);
            if (isSubmitted != null) {
              return base & tbl.isSubmitted.equals(isSubmitted);
            }
            return base;
          })
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.examFrom)]))
        .watch();
  }

  // ── Student Behaviour ─────────────────────────────────────────────────────

  Future<void> upsertStudentBehaviourRecord({
    required String incidentId,
    required String tenantId,
    required String studentId,
    required String title,
    String? description,
    String point = '0',
    bool isPositive = true,
    String? assignedBy,
    String? incidentDate,
    int commentCount = 0,
    String source = 'remote',
    DateTime? updatedAt,
  }) {
    return into(studentBehaviourEntries).insertOnConflictUpdate(
      StudentBehaviourEntriesCompanion(
        id: Value(incidentId),
        tenantId: Value(tenantId),
        studentId: Value(studentId),
        title: Value(title),
        description: Value(description),
        point: Value(point),
        isPositive: Value(isPositive),
        assignedBy: Value(assignedBy),
        incidentDate: Value(incidentDate),
        commentCount: Value(commentCount),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> deleteStudentBehaviourRecord({
    required String tenantId,
    required String incidentId,
  }) async {
    await (delete(studentBehaviourEntries)..where(
          (tbl) =>
              tbl.tenantId.equals(tenantId) & tbl.id.equals(incidentId),
        ))
        .go();
    await (delete(behaviourCommentEntries)..where(
          (tbl) =>
              tbl.tenantId.equals(tenantId) &
              tbl.incidentId.equals(incidentId),
        ))
        .go();
  }

  Stream<List<StudentBehaviourEntry>> watchStudentBehaviour({
    required String tenantId,
    required String studentId,
  }) {
    return (select(studentBehaviourEntries)
          ..where(
            (tbl) =>
                tbl.tenantId.equals(tenantId) &
                tbl.studentId.equals(studentId),
          )
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]))
        .watch();
  }

  Future<void> upsertBehaviourCommentRecord({
    required String commentId,
    required String tenantId,
    required String incidentId,
    required String commentText,
    String? commentedBy,
    String? commentDate,
    String source = 'remote',
    DateTime? updatedAt,
  }) {
    return into(behaviourCommentEntries).insertOnConflictUpdate(
      BehaviourCommentEntriesCompanion(
        id: Value(commentId),
        tenantId: Value(tenantId),
        incidentId: Value(incidentId),
        commentText: Value(commentText),
        commentedBy: Value(commentedBy),
        commentDate: Value(commentDate),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> deleteBehaviourCommentRecord({
    required String tenantId,
    required String commentId,
  }) async {
    await (delete(behaviourCommentEntries)..where(
          (tbl) =>
              tbl.tenantId.equals(tenantId) & tbl.id.equals(commentId),
        ))
        .go();
  }

  Stream<List<BehaviourCommentEntry>> watchBehaviourComments({
    required String tenantId,
    required String incidentId,
  }) {
    return (select(behaviourCommentEntries)
          ..where(
            (tbl) =>
                tbl.tenantId.equals(tenantId) &
                tbl.incidentId.equals(incidentId),
          )
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.updatedAt)]))
        .watch();
  }

  // ── Teachers ──────────────────────────────────────────────────────────────

  Future<void> upsertTeacherRecord({
    required String teacherId,
    required String tenantId,
    required String fullName,
    String? employeeNo,
    String? subjectName,
    String? qualification,
    String? email,
    String? phone,
    String? designation,
    bool isClassTeacher = false,
    String? imageUrl,
    int ratingScore = 0,
    String? reviewComment,
    bool hasReviewed = false,
    bool isActive = true,
    String source = 'remote',
    DateTime? updatedAt,
  }) {
    return into(teacherEntries).insertOnConflictUpdate(
      TeacherEntriesCompanion(
        id: Value(teacherId),
        tenantId: Value(tenantId),
        fullName: Value(fullName),
        employeeNo: Value(employeeNo),
        subjectName: Value(subjectName),
        qualification: Value(qualification),
        email: Value(email),
        phone: Value(phone),
        designation: Value(designation),
        isClassTeacher: Value(isClassTeacher),
        imageUrl: Value(imageUrl),
        ratingScore: Value(ratingScore),
        reviewComment: Value(reviewComment),
        hasReviewed: Value(hasReviewed),
        isActive: Value(isActive),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> deleteTeacherRecord({
    required String tenantId,
    required String teacherId,
  }) async {
    await (delete(teacherEntries)..where(
          (tbl) =>
              tbl.tenantId.equals(tenantId) & tbl.id.equals(teacherId),
        ))
        .go();
  }

  Stream<List<TeacherEntry>> watchTeachers({required String tenantId}) {
    return (select(teacherEntries)
          ..where(
            (tbl) =>
                tbl.tenantId.equals(tenantId) & tbl.isActive.equals(true),
          )
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.fullName)]))
        .watch();
  }

  // ── Online Lessons ────────────────────────────────────────────────────────

  Future<void> upsertOnlineLessonRecord({
    required String lessonId,
    required String tenantId,
    required String itemId,
    required String title,
    String contentType = 'video',
    String? contentUrl,
    String? description,
    int sortOrder = 0,
    int durationSeconds = 0,
    bool isCompleted = false,
    bool isActive = true,
    String source = 'remote',
    DateTime? updatedAt,
  }) {
    return into(onlineLessonEntries).insertOnConflictUpdate(
      OnlineLessonEntriesCompanion(
        id: Value(lessonId),
        tenantId: Value(tenantId),
        itemId: Value(itemId),
        title: Value(title),
        contentType: Value(contentType),
        contentUrl: Value(contentUrl),
        description: Value(description),
        sortOrder: Value(sortOrder),
        durationSeconds: Value(durationSeconds),
        isCompleted: Value(isCompleted),
        isActive: Value(isActive),
        source: Value(source),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  Future<void> deleteOnlineLessonRecord({
    required String tenantId,
    required String lessonId,
  }) async {
    await (delete(onlineLessonEntries)..where(
          (tbl) =>
              tbl.tenantId.equals(tenantId) & tbl.id.equals(lessonId),
        ))
        .go();
  }

  Stream<List<OnlineLessonEntry>> watchCourseLessons({
    required String tenantId,
    required String itemId,
  }) {
    return (select(onlineLessonEntries)
          ..where(
            (tbl) =>
                tbl.tenantId.equals(tenantId) &
                tbl.itemId.equals(itemId) &
                tbl.isActive.equals(true),
          )
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.sortOrder)]))
        .watch();
  }
}
