import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../../../core/theme/scholify_colors.dart';
import '../../../core/widgets/scholify_empty_state.dart';
import '../../family/family_links.dart';
import '../data/fee_repository.dart';

/// Family-facing fees view: a guardian sees each linked child's fee
/// invoices (with the shared child switcher); a student sees their own.
/// Read-only — online payment is not wired yet, this page shows what is
/// owed, what is paid, and what is overdue.
class FamilyFeesPage extends StatefulWidget {
  const FamilyFeesPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<FamilyFeesPage> createState() => _FamilyFeesPageState();
}

class _FamilyFeesPageState extends State<FamilyFeesPage> {
  late final FeeRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = FeeRepository(
      database: widget.syncEngine.database,
      syncEngine: widget.syncEngine,
      tenantContext: widget.tenantContext,
    );
  }

  FamilyIdentity get _identity =>
      FamilyIdentity.fromGateway(widget.syncEngine.pocketbaseGateway);

  @override
  Widget build(BuildContext context) {
    final role = widget.tenantContext.role.toLowerCase();
    if (role == 'guardian') {
      return _buildGuardianBody(context);
    }
    return _buildStudentBody(context);
  }

  Widget _buildGuardianBody(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: StreamBuilder<List<StudentDirectoryEntry>>(
        stream: watchLinkedChildren(
          widget.syncEngine.database,
          identity: _identity,
          tenantId: widget.tenantContext.tenantId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final children = snapshot.data ?? const [];
          if (children.isEmpty) {
            return Center(
              child: ScholifyEmptyState(
                icon: Icons.family_restroom_outlined,
                title: 'No children linked',
                message:
                    'Contact the school office to link your children to this account.',
              ),
            );
          }
          return ValueListenableBuilder<String?>(
            valueListenable: FamilyChildSelection.selectedStudentId,
            builder: (context, _, _) {
              final child = effectiveChild(children)!;
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildHeader(
                    theme,
                    'Fees & Payments',
                    'Invoices and payment status for ${child.fullName}',
                  ),
                  if (children.length > 1) ...[
                    const SizedBox(height: 16),
                    FamilyChildSwitcher(children: children),
                  ],
                  const SizedBox(height: 20),
                  _InvoiceSection(
                    repository: _repository,
                    studentId: child.id,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStudentBody(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: StreamBuilder<StudentDirectoryEntry?>(
        stream: watchOwnStudentRecord(
          widget.syncEngine.database,
          identity: _identity,
          tenantId: widget.tenantContext.tenantId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final student = snapshot.data;
          if (student == null) {
            return Center(
              child: ScholifyEmptyState(
                icon: Icons.person_search_outlined,
                title: 'No student record linked',
                message:
                    'Contact the school office to link this account to your student record.',
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildHeader(
                theme,
                'Fees & Payments',
                'Your fee invoices and payment status',
              ),
              const SizedBox(height: 20),
              _InvoiceSection(repository: _repository, studentId: student.id),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Summary card + invoice list for one student.
class _InvoiceSection extends StatelessWidget {
  const _InvoiceSection({required this.repository, required this.studentId});

  final FeeRepository repository;
  final String studentId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<FeeInvoiceEntry>>(
      stream: repository.watchStudentInvoices(studentId: studentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final invoices = [...(snapshot.data ?? const <FeeInvoiceEntry>[])]
          ..sort((a, b) {
            final aDate = a.dueDate ?? DateTime(1970);
            final bDate = b.dueDate ?? DateTime(1970);
            return bDate.compareTo(aDate);
          });
        if (invoices.isEmpty) {
          return ScholifyEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No invoices yet',
            message: 'Fee invoices issued by the school will appear here.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryCard(invoices: invoices),
            const SizedBox(height: 20),
            Text(
              'Invoices',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            for (final invoice in invoices) ...[
              _InvoiceRow(invoice: invoice),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.invoices});

  final List<FeeInvoiceEntry> invoices;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brightness = theme.brightness;

    var balanceDue = 0.0;
    var totalPaid = 0.0;
    DateTime? nextDue;
    var hasOverdue = false;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    for (final invoice in invoices) {
      final balance = invoice.amountDue - invoice.amountPaid;
      totalPaid += invoice.amountPaid;
      if (balance > 0) {
        balanceDue += balance;
        final due = invoice.dueDate;
        if (due != null) {
          final dueDateOnly = DateTime(due.year, due.month, due.day);
          if (dueDateOnly.isBefore(todayDate)) {
            hasOverdue = true;
          }
          if (nextDue == null || due.isBefore(nextDue)) {
            nextDue = due;
          }
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: _SummaryStat(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Balance Due',
                value: moneyText(balanceDue),
                color: balanceDue > 0
                    ? (hasOverdue
                          ? scheme.error
                          : ScholifyColors.onTint(
                              ScholifyColors.achievementAmber,
                              brightness,
                            ))
                    : ScholifyColors.onTint(
                        ScholifyColors.accentFinance,
                        brightness,
                      ),
              ),
            ),
            Expanded(
              child: _SummaryStat(
                icon: Icons.paid_outlined,
                label: 'Total Paid',
                value: moneyText(totalPaid),
                color: ScholifyColors.onTint(
                  ScholifyColors.accentFinance,
                  brightness,
                ),
              ),
            ),
            Expanded(
              child: _SummaryStat(
                icon: Icons.event_outlined,
                label: 'Next Due',
                value: nextDue == null
                    ? '—'
                    : DateFormat('d MMM yyyy').format(nextDue),
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.invoice});

  final FeeInvoiceEntry invoice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brightness = theme.brightness;

    final status = invoiceStatusOf(invoice, DateTime.now());

    final subtitleParts = <String>[
      if (invoice.dueDate != null)
        'Due ${DateFormat('d MMM yyyy').format(invoice.dueDate!)}'
      else
        'No due date',
      if (status == InvoiceStatus.partial)
        '${moneyText(invoice.amountPaid)} paid of ${moneyText(invoice.amountDue)}',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: ScholifyColors.tintOf(
                  ScholifyColors.accentFinance,
                  brightness,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                color: ScholifyColors.onTint(
                  ScholifyColors.accentFinance,
                  brightness,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.invoiceNo,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitleParts.join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: status == InvoiceStatus.overdue
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  moneyText(invoice.amountDue),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                _StatusChip(status: status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, accent) = switch (status) {
      InvoiceStatus.paid => ('Paid', ScholifyColors.accentFinance),
      InvoiceStatus.partial => (
        'Partially Paid',
        ScholifyColors.achievementAmber,
      ),
      InvoiceStatus.overdue => ('Overdue', theme.colorScheme.error),
      InvoiceStatus.due => ('Due', theme.colorScheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ScholifyColors.tintOf(accent, theme.brightness),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: ScholifyColors.onTint(accent, theme.brightness),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

enum InvoiceStatus { paid, partial, overdue, due }

/// Display status for an invoice: fully paid wins, then overdue (past
/// its due date with a balance), then partially paid, then simply due.
InvoiceStatus invoiceStatusOf(FeeInvoiceEntry invoice, DateTime now) {
  final balance = invoice.amountDue - invoice.amountPaid;
  if (balance <= 0) return InvoiceStatus.paid;
  final due = invoice.dueDate;
  if (due != null) {
    final dueDateOnly = DateTime(due.year, due.month, due.day);
    final todayDate = DateTime(now.year, now.month, now.day);
    if (dueDateOnly.isBefore(todayDate)) return InvoiceStatus.overdue;
  }
  if (invoice.amountPaid > 0) return InvoiceStatus.partial;
  return InvoiceStatus.due;
}

/// 'Rs 15,000' for whole amounts, 'Rs 5,000.50' when there are paisas.
String moneyText(double value) {
  final isWhole = value == value.truncateToDouble();
  final formatter = NumberFormat(isWhole ? '#,##0' : '#,##0.00');
  return 'Rs ${formatter.format(value)}';
}
