import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/features/fees/presentation/family_fees_page.dart';

FeeInvoiceEntry _invoice({
  double due = 15000,
  double paid = 0,
  DateTime? dueDate,
}) {
  return FeeInvoiceEntry(
    id: 'inv1',
    tenantId: 'tenant1',
    studentId: 'student1',
    invoiceNo: 'INV-1',
    amountDue: due,
    amountPaid: paid,
    status: 'due',
    dueDate: dueDate,
    source: 'remote',
    updatedAt: DateTime(2026, 10, 1),
  );
}

void main() {
  final now = DateTime(2026, 10, 21, 12);

  group('invoiceStatusOf', () {
    test('fully paid invoice is paid even when past its due date', () {
      final invoice = _invoice(
        paid: 15000,
        dueDate: DateTime(2026, 10, 10),
      );
      expect(invoiceStatusOf(invoice, now), InvoiceStatus.paid);
    });

    test('unpaid invoice past its due date is overdue', () {
      final invoice = _invoice(dueDate: DateTime(2026, 10, 20));
      expect(invoiceStatusOf(invoice, now), InvoiceStatus.overdue);
    });

    test('partially paid invoice past its due date is overdue', () {
      final invoice = _invoice(
        paid: 5000,
        dueDate: DateTime(2026, 10, 10),
      );
      expect(invoiceStatusOf(invoice, now), InvoiceStatus.overdue);
    });

    test('partially paid invoice due in the future is partial', () {
      final invoice = _invoice(
        paid: 5000,
        dueDate: DateTime(2026, 11, 5),
      );
      expect(invoiceStatusOf(invoice, now), InvoiceStatus.partial);
    });

    test('unpaid invoice due today is due, not overdue', () {
      final invoice = _invoice(dueDate: DateTime(2026, 10, 21, 23, 59));
      expect(invoiceStatusOf(invoice, now), InvoiceStatus.due);
    });

    test('unpaid invoice due in the future is due', () {
      final invoice = _invoice(dueDate: DateTime(2026, 11, 5));
      expect(invoiceStatusOf(invoice, now), InvoiceStatus.due);
    });

    test('unpaid invoice without a due date is due', () {
      expect(invoiceStatusOf(_invoice(), now), InvoiceStatus.due);
    });
  });

  group('moneyText', () {
    test('whole amounts render grouped without decimals', () {
      expect(moneyText(15000), 'Rs 15,000');
      expect(moneyText(0), 'Rs 0');
      expect(moneyText(1250000), 'Rs 1,250,000');
    });

    test('fractional amounts keep two decimals', () {
      expect(moneyText(5000.5), 'Rs 5,000.50');
    });
  });
}
