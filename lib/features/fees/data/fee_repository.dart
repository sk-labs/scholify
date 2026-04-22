import 'dart:convert';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

class FeeRepository {
  FeeRepository({
    required this.database,
    required this.syncEngine,
    required this.tenantContext,
  });

  final AppLocalDatabase database;
  final SyncEngine syncEngine;
  final TenantContext tenantContext;

  Stream<List<StudentDirectoryEntry>> watchStudents() {
    return database.watchActiveStudentProfiles(tenantId: _resolveTenantId());
  }

  Stream<List<FeeInvoiceEntry>> watchStudentInvoices({
    required String studentId,
    String statusFilter = 'all',
  }) {
    return database.watchFeeInvoicesByStudent(
      tenantId: _resolveTenantId(),
      studentId: studentId,
      status: statusFilter == 'all' ? null : statusFilter,
    );
  }

  Stream<List<FeePaymentEntry>> watchInvoicePayments({
    required String invoiceId,
  }) {
    return database.watchFeePaymentsByInvoice(
      tenantId: _resolveTenantId(),
      invoiceId: invoiceId,
    );
  }

  Future<void> saveInvoice({
    required String studentId,
    required double amountDue,
    required double amountPaid,
    DateTime? dueDate,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();
    final recordId =
        'fee_${tenantId}_${studentId}_${now.millisecondsSinceEpoch}';
    final invoiceNo = 'INV-${now.millisecondsSinceEpoch}';
    final status = _deriveStatus(amountDue: amountDue, amountPaid: amountPaid);

    await database.upsertFeeInvoiceRecord(
      recordId: recordId,
      tenantId: tenantId,
      studentId: studentId,
      invoiceNo: invoiceNo,
      amountDue: amountDue,
      amountPaid: amountPaid,
      status: status,
      dueDate: dueDate,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'fee_invoice',
      entityId: recordId,
      operation: 'upsert',
      payload: jsonEncode({
        'recordId': recordId,
        'tenantId': tenantId,
        'studentId': studentId,
        'invoiceNo': invoiceNo,
        'amountDue': amountDue,
        'amountPaid': amountPaid,
        'status': status,
        'dueDate': dueDate?.toUtc().toIso8601String(),
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> updateInvoicePayment({
    required FeeInvoiceEntry invoice,
    required double amountPaid,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();
    final status = _deriveStatus(
      amountDue: invoice.amountDue,
      amountPaid: amountPaid,
    );

    await database.upsertFeeInvoiceRecord(
      recordId: invoice.id,
      tenantId: tenantId,
      studentId: invoice.studentId,
      invoiceNo: invoice.invoiceNo,
      amountDue: invoice.amountDue,
      amountPaid: amountPaid,
      status: status,
      dueDate: invoice.dueDate,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'fee_invoice',
      entityId: invoice.id,
      operation: 'upsert',
      payload: jsonEncode({
        'recordId': invoice.id,
        'tenantId': tenantId,
        'studentId': invoice.studentId,
        'invoiceNo': invoice.invoiceNo,
        'amountDue': invoice.amountDue,
        'amountPaid': amountPaid,
        'status': status,
        'dueDate': invoice.dueDate?.toUtc().toIso8601String(),
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> addPayment({
    required FeeInvoiceEntry invoice,
    required double amount,
    required String paymentMethod,
    String? referenceNo,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();
    final paymentId = 'pay_${invoice.id}_${now.millisecondsSinceEpoch}';
    final nextAmountPaid = invoice.amountPaid + amount;
    final status = _deriveStatus(
      amountDue: invoice.amountDue,
      amountPaid: nextAmountPaid,
    );

    await database.upsertFeeInvoiceRecord(
      recordId: invoice.id,
      tenantId: tenantId,
      studentId: invoice.studentId,
      invoiceNo: invoice.invoiceNo,
      amountDue: invoice.amountDue,
      amountPaid: nextAmountPaid,
      status: status,
      dueDate: invoice.dueDate,
      source: 'local',
      updatedAt: now,
    );

    await database.upsertFeePaymentRecord(
      paymentId: paymentId,
      tenantId: tenantId,
      invoiceId: invoice.id,
      studentId: invoice.studentId,
      amount: amount,
      paidAt: now,
      paymentMethod: paymentMethod,
      referenceNo: referenceNo,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'fee_invoice',
      entityId: invoice.id,
      operation: 'upsert',
      payload: jsonEncode({
        'recordId': invoice.id,
        'tenantId': tenantId,
        'studentId': invoice.studentId,
        'invoiceNo': invoice.invoiceNo,
        'amountDue': invoice.amountDue,
        'amountPaid': nextAmountPaid,
        'status': status,
        'dueDate': invoice.dueDate?.toUtc().toIso8601String(),
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );

    await syncEngine.enqueueOperation(
      entityType: 'fee_payment',
      entityId: paymentId,
      operation: 'upsert',
      payload: jsonEncode({
        'paymentId': paymentId,
        'tenantId': tenantId,
        'invoiceId': invoice.id,
        'studentId': invoice.studentId,
        'amount': amount,
        'paidAt': now.toIso8601String(),
        'paymentMethod': paymentMethod,
        'referenceNo': referenceNo,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  String _deriveStatus({
    required double amountDue,
    required double amountPaid,
  }) {
    if (amountPaid <= 0) return 'due';
    if (amountPaid >= amountDue) return 'paid';
    return 'partial';
  }

  String _resolveTenantId() {
    if (tenantContext.tenantId != null && tenantContext.tenantId!.isNotEmpty) {
      return tenantContext.tenantId!;
    }
    return 'school_demo';
  }
}
