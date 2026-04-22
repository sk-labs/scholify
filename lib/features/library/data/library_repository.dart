import 'dart:convert';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

class LibraryRepository {
  LibraryRepository({
    required this.database,
    required this.syncEngine,
    required this.tenantContext,
  });

  final AppLocalDatabase database;
  final SyncEngine syncEngine;
  final TenantContext tenantContext;

  static const String issuedType = 'issued';
  static const String topType = 'top';
  static const String generalType = 'general';

  Stream<List<LibraryBookEntry>> watchIssuedBooks({
    bool includeInactive = false,
  }) {
    return database.watchLibraryBooks(
      tenantId: _resolveTenantId(),
      bookType: issuedType,
      includeInactive: includeInactive,
    );
  }

  Stream<List<LibraryBookEntry>> watchTopBooks({bool includeInactive = false}) {
    return database.watchLibraryBooks(
      tenantId: _resolveTenantId(),
      bookType: topType,
      includeInactive: includeInactive,
    );
  }

  Stream<List<LibraryBookEntry>> watchAllBooks({bool includeInactive = false}) {
    return database.watchLibraryBooks(
      tenantId: _resolveTenantId(),
      includeInactive: includeInactive,
    );
  }

  Future<void> saveBook({
    String? bookId,
    required String title,
    String bookType = generalType,
    String? authorName,
    String? categoryName,
    DateTime? issuedOn,
    DateTime? dueDate,
    DateTime? returnDate,
    double ratingScore = 0,
    int issueCount = 0,
    bool isIssued = false,
    bool isActive = true,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();
    final resolvedId =
        bookId ?? 'lib_${tenantId}_${now.microsecondsSinceEpoch}';

    await database.upsertLibraryBookRecord(
      bookId: resolvedId,
      tenantId: tenantId,
      bookType: bookType,
      title: title,
      authorName: authorName,
      categoryName: categoryName,
      issuedOn: issuedOn?.toUtc(),
      dueDate: dueDate?.toUtc(),
      returnDate: returnDate?.toUtc(),
      ratingScore: ratingScore,
      issueCount: issueCount,
      isIssued: isIssued,
      isActive: isActive,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'library_item',
      entityId: resolvedId,
      operation: 'upsert',
      payload: jsonEncode({
        'bookId': resolvedId,
        'tenantId': tenantId,
        'bookType': bookType,
        'title': title,
        'authorName': authorName,
        'categoryName': categoryName,
        'issuedOn': issuedOn?.toUtc().toIso8601String(),
        'dueDate': dueDate?.toUtc().toIso8601String(),
        'returnDate': returnDate?.toUtc().toIso8601String(),
        'ratingScore': ratingScore,
        'issueCount': issueCount,
        'isIssued': isIssued,
        'isActive': isActive,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> deleteBook(LibraryBookEntry book) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();

    await database.deleteLibraryBookRecord(tenantId: tenantId, bookId: book.id);

    await syncEngine.enqueueOperation(
      entityType: 'library_item',
      entityId: book.id,
      operation: 'delete',
      payload: jsonEncode({
        'bookId': book.id,
        'tenantId': tenantId,
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  String _resolveTenantId() {
    if (tenantContext.tenantId != null && tenantContext.tenantId!.isNotEmpty) {
      return tenantContext.tenantId!;
    }
    return 'school_demo';
  }
}
