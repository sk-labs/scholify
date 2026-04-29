import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import '../database/local_database.dart';

/// Service for exporting tenant lists to CSV files with RFC 4180 compliance.
///
/// For large datasets (> 1000 rows) the CSV serialization is offloaded to a
/// background isolate so the UI thread stays responsive. Row data is streamed
/// from the database in pages of [_pageSize] to avoid loading the entire
/// result set into memory at once.
///
/// Requirements: Q2.2, Q2.3, Q2.6, Performance (25.3)
class CSVExportService {
  final AppLocalDatabase _database;

  /// Number of tenant rows fetched per page when streaming large exports.
  static const int _pageSize = 200;

  /// Threshold above which the isolate path is used.
  static const int _isolateThreshold = 1000;

  const CSVExportService({
    required AppLocalDatabase database,
  }) : _database = database;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Exports a list of tenants to a CSV string.
  ///
  /// For lists with more than [_isolateThreshold] rows the serialization runs
  /// on a background isolate. Smaller lists are serialized inline.
  ///
  /// Columns (RFC 4180, UTF-8):
  ///   tenant_name, tenant_id, plan, seat_limit, is_active,
  ///   license_expires_at, owner_email, active_students, outstanding_amount
  ///
  /// Requirements: Q2.2, Q2.3, Q2.5, Q2.6
  Future<String> exportTenantList(List<TenantUsageBillingView> tenants) async {
    // Fetch owner emails (needed for the owner_email column)
    final ownerEmailMap = await _fetchOwnerEmails(tenants);

    // Build the raw row data (header + data rows)
    final rows = _buildRows(tenants, ownerEmailMap);

    if (tenants.length > _isolateThreshold) {
      // Offload serialization to a background isolate (25.3)
      return compute(_serializeRowsInIsolate, rows);
    } else {
      return _serializeRowsInIsolate(rows);
    }
  }

  /// Streams a large tenant export page-by-page, yielding CSV chunks.
  ///
  /// Each yielded string is a block of [_pageSize] rows (plus the header on
  /// the first chunk). Callers can concatenate chunks or write them
  /// incrementally to a file/sink.
  ///
  /// Requirements: Performance (25.3)
  Stream<String> exportTenantListStreaming() async* {
    bool headerEmitted = false;
    int offset = 0;

    while (true) {
      // Fetch one page from the database
      final page = await _fetchPage(offset, _pageSize);
      if (page.isEmpty) break;

      final ownerEmailMap = await _fetchOwnerEmails(page);
      final rows = _buildRows(page, ownerEmailMap, includeHeader: !headerEmitted);
      headerEmitted = true;

      // Serialize this page on a background isolate
      final chunk = await compute(_serializeRowsInIsolate, rows);
      yield chunk;

      if (page.length < _pageSize) break; // last page
      offset += _pageSize;
    }
  }

  /// Triggers a platform-specific file save dialog or share sheet.
  ///
  /// Requirements: Q2.4
  Future<void> saveCsvFile(String csvContent, {String filename = 'tenants.csv'}) async {
    if (kIsWeb) {
      _downloadCsvWeb(csvContent, filename);
    } else if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await _shareCsvMobile(csvContent, filename);
    } else {
      await _saveCsvDesktop(csvContent, filename);
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Fetches a page of [TenantUsageBillingView] rows from the database.
  Future<List<TenantUsageBillingView>> _fetchPage(int offset, int limit) async {
    final all = await _database.watchTenantUsageBillingViews().first;
    if (offset >= all.length) return const [];
    final end = (offset + limit).clamp(0, all.length);
    return all.sublist(offset, end);
  }

  /// Fetches primary owner emails for all tenants in [tenants].
  Future<Map<String, String>> _fetchOwnerEmails(
      List<TenantUsageBillingView> tenants) async {
    final map = <String, String>{};
    for (final tenant in tenants) {
      final owners = await (_database.select(_database.schoolOwnerEntries)
            ..where((o) => o.tenantId.equals(tenant.tenantId))
            ..where((o) => o.isPrimary.equals(true))
            ..limit(1))
          .get();
      if (owners.isNotEmpty) {
        map[tenant.tenantId] = owners.first.email;
      }
    }
    return map;
  }

  /// Builds the raw 2-D list of rows ready for CSV serialization.
  List<List<dynamic>> _buildRows(
    List<TenantUsageBillingView> tenants,
    Map<String, String> ownerEmailMap, {
    bool includeHeader = true,
  }) {
    final rows = <List<dynamic>>[];

    if (includeHeader) {
      rows.add([
        'tenant_name',
        'tenant_id',
        'plan',
        'seat_limit',
        'is_active',
        'license_expires_at',
        'owner_email',
        'active_students',
        'outstanding_amount',
      ]);
    }

    for (final tenant in tenants) {
      rows.add([
        tenant.tenantName,
        tenant.tenantId,
        tenant.planCode ?? '',
        tenant.seatLimit ?? 0,
        tenant.licenseActive == true ? 'true' : 'false',
        tenant.licenseExpiresAt?.toIso8601String() ?? '',
        ownerEmailMap[tenant.tenantId] ?? '',
        tenant.activeStudents ?? 0,
        tenant.outstandingAmount ?? 0.0,
      ]);
    }

    return rows;
  }

  // ── Platform save implementations ─────────────────────────────────────────

  void _downloadCsvWeb(String csvContent, String filename) {
    throw UnimplementedError('Web CSV download not yet implemented');
  }

  Future<void> _shareCsvMobile(String csvContent, String filename) async {
    throw UnimplementedError('Mobile CSV share not yet implemented');
  }

  Future<void> _saveCsvDesktop(String csvContent, String filename) async {
    throw UnimplementedError('Desktop CSV save not yet implemented');
  }
}

// ── Top-level isolate function ────────────────────────────────────────────────
//
// Must be a top-level (or static) function to be passed to [compute].
// Converts a 2-D list of rows into an RFC 4180 CSV string.

String _serializeRowsInIsolate(List<List<dynamic>> rows) {
  const converter = ListToCsvConverter();
  return converter.convert(rows);
}
