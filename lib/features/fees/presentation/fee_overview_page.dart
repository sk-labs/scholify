import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../data/fee_repository.dart';

class FeeOverviewPage extends StatefulWidget {
  const FeeOverviewPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<FeeOverviewPage> createState() => _FeeOverviewPageState();
}

class _FeeOverviewPageState extends State<FeeOverviewPage> {
  late final FeeRepository _repository;

  final TextEditingController _amountDueController = TextEditingController();
  final TextEditingController _amountPaidController = TextEditingController(
    text: '0',
  );

  String? _selectedStudentId;
  DateTime? _selectedDueDate;
  String _statusFilter = 'all';
  bool _isSaving = false;
  String? _updatingInvoiceId;

  static const List<String> _paymentMethods = [
    'cash',
    'card',
    'bank_transfer',
    'upi',
  ];

  @override
  void initState() {
    super.initState();
    _repository = FeeRepository(
      database: widget.syncEngine.database,
      syncEngine: widget.syncEngine,
      tenantContext: widget.tenantContext,
    );
  }

  @override
  void dispose() {
    _amountDueController.dispose();
    _amountPaidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page header
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fees',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Track invoices, payments, and balances.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<List<StudentDirectoryEntry>>(
          stream: _repository.watchStudents(),
          builder: (context, studentsSnapshot) {
            if (studentsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (studentsSnapshot.hasError) {
              return Center(
                child: Text(
                  'Failed to load students: ${studentsSnapshot.error}',
                ),
              );
            }

            final students =
                studentsSnapshot.data ?? const <StudentDirectoryEntry>[];
            if (students.isEmpty) {
              return const Center(
                child: Text(
                  'No students found. Add students in the Students tab first.',
                ),
              );
            }

            final selectedStudentId = _resolveSelectedStudentId(students);

            return Column(
              children: [
                _buildToolbar(students, selectedStudentId),
                const SizedBox(height: 12),
                _buildCreateInvoiceCard(selectedStudentId),
                const SizedBox(height: 12),
                _buildStatusFilterRow(),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<List<FeeInvoiceEntry>>(
                    stream: _repository.watchStudentInvoices(
                      studentId: selectedStudentId,
                      statusFilter: _statusFilter,
                    ),
                    builder: (context, invoiceSnapshot) {
                      if (invoiceSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (invoiceSnapshot.hasError) {
                        return Center(
                          child: Text(
                            'Failed to load fee invoices: ${invoiceSnapshot.error}',
                          ),
                        );
                      }

                      final invoices = invoiceSnapshot.data ?? const [];
                      if (invoices.isEmpty) {
                        return Center(
                          child: Text(
                            _statusFilter == 'all'
                                ? 'No fee invoices for this student yet.'
                                : 'No $_statusFilter invoices for this student.',
                          ),
                        );
                      }

                      final totalDue = invoices.fold<double>(
                        0,
                        (sum, row) => sum + row.amountDue,
                      );
                      final totalPaid = invoices.fold<double>(
                        0,
                        (sum, row) => sum + row.amountPaid,
                      );

                      return Column(
                        children: [
                          Card(
                            child: ListTile(
                              title: const Text('Student Fee Summary'),
                              subtitle: Text(
                                'Due: ${_money(totalDue)} | Paid: ${_money(totalPaid)} | Balance: ${_money(totalDue - totalPaid)}',
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView.separated(
                              itemCount: invoices.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final row = invoices[index];
                                final dueDateText = row.dueDate == null
                                    ? 'No due date'
                                    : DateFormat(
                                        'dd MMM yyyy',
                                      ).format(row.dueDate!.toLocal());
                                return Card(
                                  child: ListTile(
                                    title: Text(
                                      '${row.invoiceNo} (${row.status.toUpperCase()})',
                                    ),
                                    subtitle: Text(
                                      'Due: ${_money(row.amountDue)} | Paid: ${_money(row.amountPaid)} | $dueDateText',
                                    ),
                                    trailing: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          DateFormat(
                                            'dd/MM HH:mm',
                                          ).format(row.updatedAt.toLocal()),
                                        ),
                                        PopupMenuButton<String>(
                                          tooltip: 'Invoice actions',
                                          onSelected: (action) {
                                            _handleInvoiceAction(action, row);
                                          },
                                          itemBuilder: (context) {
                                            final items =
                                                <PopupMenuEntry<String>>[
                                                  const PopupMenuItem<String>(
                                                    value: 'add_payment',
                                                    child: Text('Add Payment'),
                                                  ),
                                                  const PopupMenuItem<String>(
                                                    value: 'edit_payment',
                                                    child: Text('Edit Payment'),
                                                  ),
                                                  const PopupMenuItem<String>(
                                                    value: 'view_payments',
                                                    child: Text(
                                                      'View Payments',
                                                    ),
                                                  ),
                                                ];

                                            if (row.status != 'paid') {
                                              items.add(
                                                const PopupMenuItem<String>(
                                                  value: 'mark_paid',
                                                  child: Text('Mark as Paid'),
                                                ),
                                              );
                                            }

                                            return items;
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ],
  ),
      ),
    );
  }

  Widget _buildStatusFilterRow() {
    const filters = ['all', 'due', 'partial', 'paid'];

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final filter in filters)
            ChoiceChip(
              label: Text(
                filter == 'all' ? 'All Invoices' : filter.toUpperCase(),
              ),
              selected: _statusFilter == filter,
              onSelected: (_) {
                setState(() {
                  _statusFilter = filter;
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildToolbar(
    List<StudentDirectoryEntry> students,
    String selectedStudentId,
  ) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Student',
        border: OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selectedStudentId,
          items: students
              .map(
                (student) => DropdownMenuItem<String>(
                  value: student.id,
                  child: Text(
                    '${student.fullName} (${student.admissionNo})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _selectedStudentId = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildCreateInvoiceCard(String selectedStudentId) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 170,
              child: TextField(
                controller: _amountDueController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount Due',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 170,
              child: TextField(
                controller: _amountPaidController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount Paid',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _pickDueDate,
              icon: const Icon(Icons.event),
              label: Text(
                _selectedDueDate == null
                    ? 'Pick Due Date'
                    : DateFormat('dd MMM yyyy').format(_selectedDueDate!),
              ),
            ),
            FilledButton.icon(
              onPressed: _isSaving
                  ? null
                  : () => _saveInvoice(selectedStudentId),
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving...' : 'Save Invoice'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 5),
      initialDate: _selectedDueDate ?? now,
    );

    if (picked == null) return;
    setState(() {
      _selectedDueDate = picked;
    });
  }

  Future<void> _saveInvoice(String studentId) async {
    final amountDue = double.tryParse(_amountDueController.text.trim());
    final amountPaid = double.tryParse(_amountPaidController.text.trim()) ?? 0;

    if (amountDue == null || amountDue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount due.')),
      );
      return;
    }

    if (amountPaid < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount paid cannot be negative.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.saveInvoice(
        studentId: studentId,
        amountDue: amountDue,
        amountPaid: amountPaid,
        dueDate: _selectedDueDate,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fee invoice saved locally and queued for sync.'),
          ),
        );
      }

      _amountDueController.clear();
      _amountPaidController.text = '0';
      setState(() {
        _selectedDueDate = null;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save fee invoice: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _handleInvoiceAction(
    String action,
    FeeInvoiceEntry invoice,
  ) async {
    if (_updatingInvoiceId != null) {
      return;
    }

    if (action == 'add_payment') {
      final draft = await _promptPaymentDraft(invoice);
      if (draft == null) return;
      await _addPayment(invoice: invoice, draft: draft);
      return;
    }

    if (action == 'mark_paid') {
      await _updateInvoicePayment(
        invoice: invoice,
        amountPaid: invoice.amountDue,
      );
      return;
    }

    if (action == 'edit_payment') {
      final newAmountPaid = await _promptPaymentAmount(invoice);
      if (newAmountPaid == null) return;
      await _updateInvoicePayment(invoice: invoice, amountPaid: newAmountPaid);
      return;
    }

    if (action == 'view_payments') {
      await _showPaymentHistory(invoice);
    }
  }

  Future<void> _showPaymentHistory(FeeInvoiceEntry invoice) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment History - ${invoice.invoiceNo}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<List<FeePaymentEntry>>(
                    stream: _repository.watchInvoicePayments(
                      invoiceId: invoice.id,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Failed to load payment history: ${snapshot.error}',
                          ),
                        );
                      }

                      final payments = snapshot.data ?? const [];
                      if (payments.isEmpty) {
                        return const Center(
                          child: Text(
                            'No payment entries yet for this invoice.',
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: payments.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final row = payments[index];
                          final paidAt = DateFormat(
                            'dd MMM yyyy, HH:mm',
                          ).format(row.paidAt.toLocal());
                          return ListTile(
                            title: Text(
                              '${_money(row.amount)} via ${row.paymentMethod.toUpperCase()}',
                            ),
                            subtitle: Text(
                              row.referenceNo == null ||
                                      row.referenceNo!.isEmpty
                                  ? paidAt
                                  : '$paidAt | Ref: ${row.referenceNo}',
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<_PaymentDraft?> _promptPaymentDraft(FeeInvoiceEntry invoice) async {
    final amountController = TextEditingController();
    final referenceController = TextEditingController();
    String paymentMethod = _paymentMethods.first;

    final draft = await showDialog<_PaymentDraft>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setInnerState) {
            return AlertDialog(
              title: const Text('Add Payment'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Payment Amount',
                      helperText:
                          'Current Paid: ${_money(invoice.amountPaid)} | Due: ${_money(invoice.amountDue)}',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                    ),
                    items: _paymentMethods
                        .map(
                          (method) => DropdownMenuItem(
                            value: method,
                            child: Text(method.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setInnerState(() {
                        paymentMethod = value;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: referenceController,
                    decoration: const InputDecoration(
                      labelText: 'Reference No (optional)',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final parsed = double.tryParse(
                      amountController.text.trim(),
                    );
                    if (parsed == null || parsed <= 0) {
                      return;
                    }
                    Navigator.of(context).pop(
                      _PaymentDraft(
                        amount: parsed,
                        paymentMethod: paymentMethod,
                        referenceNo: referenceController.text.trim().isEmpty
                            ? null
                            : referenceController.text.trim(),
                      ),
                    );
                  },
                  child: const Text('Add Payment'),
                ),
              ],
            );
          },
        );
      },
    );

    amountController.dispose();
    referenceController.dispose();
    return draft;
  }

  Future<void> _addPayment({
    required FeeInvoiceEntry invoice,
    required _PaymentDraft draft,
  }) async {
    setState(() {
      _updatingInvoiceId = invoice.id;
    });

    try {
      await _repository.addPayment(
        invoice: invoice,
        amount: draft.amount,
        paymentMethod: draft.paymentMethod,
        referenceNo: draft.referenceNo,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment added and queued for sync.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add payment: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _updatingInvoiceId = null;
        });
      }
    }
  }

  Future<double?> _promptPaymentAmount(FeeInvoiceEntry invoice) async {
    final controller = TextEditingController(
      text: invoice.amountPaid.toStringAsFixed(2),
    );

    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Payment'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount Paid',
              helperText: 'Invoice Due: ${_money(invoice.amountDue)}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = double.tryParse(controller.text.trim());
                if (parsed == null || parsed < 0) {
                  return;
                }
                Navigator.of(context).pop(parsed);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<void> _updateInvoicePayment({
    required FeeInvoiceEntry invoice,
    required double amountPaid,
  }) async {
    if (amountPaid < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount paid cannot be negative.')),
      );
      return;
    }

    setState(() {
      _updatingInvoiceId = invoice.id;
    });

    try {
      await _repository.updateInvoicePayment(
        invoice: invoice,
        amountPaid: amountPaid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice payment updated and queued.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update invoice: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _updatingInvoiceId = null;
        });
      }
    }
  }

  String _resolveSelectedStudentId(List<StudentDirectoryEntry> students) {
    final activeId = _selectedStudentId;
    if (activeId != null && students.any((student) => student.id == activeId)) {
      return activeId;
    }

    final fallback = students.first.id;
    if (activeId != fallback) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedStudentId = fallback;
        });
      });
    }

    return fallback;
  }

  String _money(double value) => value.toStringAsFixed(2);
}

class _PaymentDraft {
  const _PaymentDraft({
    required this.amount,
    required this.paymentMethod,
    required this.referenceNo,
  });

  final double amount;
  final String paymentMethod;
  final String? referenceNo;
}
