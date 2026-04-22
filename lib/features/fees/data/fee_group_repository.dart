import 'dart:convert';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

/// Enterprise fee groups — fee categories with discount/fine/balance breakdown,
/// processing fees, and offline bank payment requests.
class FeeGroupRepository {
  FeeGroupRepository({
    required this.database,
    required this.syncEngine,
    required this.tenantContext,
  });

  final AppLocalDatabase database;
  final SyncEngine syncEngine;
  final TenantContext tenantContext;

  static const String typeFee = 'fee';
  static const String typeProcessing = 'processing';
  static const String typeOffline = 'offline';

  Stream<List<FeeGroupEntry>> watchFees({String? feeType}) {
    return database.watchFeeGroups(
      tenantId: _tid(),
      studentId: _studentId(),
      feeType: feeType,
    );
  }

  /// Upsert a fee group record (typically pulled from remote).
  Future<void> saveFeeGroup({
    String? feeId,
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
  }) async {
    final tenantId = _tid();
    final studentId = _studentId();
    final now = DateTime.now().toUtc();
    final resolvedId =
        feeId ?? 'fg_${tenantId}_${studentId}_${now.millisecondsSinceEpoch}';

    await database.upsertFeeGroupRecord(
      feeId: resolvedId,
      tenantId: tenantId,
      studentId: studentId,
      feeTitle: feeTitle,
      feeCode: feeCode,
      amount: amount,
      discount: discount,
      fine: fine,
      paid: paid,
      balance: balance,
      status: status,
      dueDate: dueDate,
      isPayable: isPayable,
      paymentMode: paymentMode,
      paymentId: paymentId,
      paymentDate: paymentDate,
      feeType: feeType,
      reference: reference,
      comments: comments,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'fee_group',
      entityId: resolvedId,
      operation: 'upsert',
      payload: jsonEncode({
        'feeId': resolvedId,
        'tenantId': tenantId,
        'studentId': studentId,
        'feeTitle': feeTitle,
        'feeCode': feeCode,
        'amount': amount,
        'discount': discount,
        'fine': fine,
        'paid': paid,
        'balance': balance,
        'status': status,
        'dueDate': dueDate,
        'isPayable': isPayable,
        'feeType': feeType,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> deleteFeeGroup(FeeGroupEntry entry) async {
    final tenantId = _tid();
    final now = DateTime.now().toUtc();

    await database.deleteFeeGroupRecord(
      tenantId: tenantId,
      feeId: entry.id,
    );

    await syncEngine.enqueueOperation(
      entityType: 'fee_group',
      entityId: entry.id,
      operation: 'delete',
      payload: jsonEncode({
        'feeId': entry.id,
        'tenantId': tenantId,
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  String _tid() {
    final id = tenantContext.tenantId;
    return (id != null && id.isNotEmpty) ? id : 'school_demo';
  }

  String _studentId() {
    // In a real app this would come from the session/user profile.
    // For now we use the tenant context user id or a placeholder.
    return tenantContext.tenantId ?? 'student_demo';
  }
}
