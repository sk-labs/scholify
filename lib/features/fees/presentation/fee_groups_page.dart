import 'package:flutter/material.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../data/fee_group_repository.dart';

class FeeGroupsPage extends StatefulWidget {
  const FeeGroupsPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<FeeGroupsPage> createState() => _FeeGroupsPageState();
}

class _FeeGroupsPageState extends State<FeeGroupsPage> {
  late final FeeGroupRepository _repository;
  int _selectedTab = 0; // 0=Fees, 1=Processing, 2=Offline

  static const _tabs = ['Fees', 'Processing', 'Offline Payments'];
  static const _types = [
    FeeGroupRepository.typeFee,
    FeeGroupRepository.typeProcessing,
    FeeGroupRepository.typeOffline,
  ];

  @override
  void initState() {
    super.initState();
    _repository = FeeGroupRepository(
      database: widget.syncEngine.database,
      syncEngine: widget.syncEngine,
      tenantContext: widget.tenantContext,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enterprise Fees')),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: StreamBuilder<List<FeeGroupEntry>>(
              stream: _repository.watchFees(feeType: _types[_selectedTab]),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Failed to load: ${snapshot.error}'),
                  );
                }

                final rows = snapshot.data ?? const <FeeGroupEntry>[];

                if (rows.isEmpty) {
                  return Center(
                    child: Text('No ${_tabs[_selectedTab].toLowerCase()} found.'),
                  );
                }

                // Summary totals for fee tab
                if (_selectedTab == 0) {
                  return _buildFeesList(rows);
                }
                if (_selectedTab == 1) {
                  return _buildProcessingList(rows);
                }
                return _buildOfflineList(rows);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final selected = _selectedTab == i;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < _tabs.length - 1 ? 8 : 0),
              child: ChoiceChip(
                label: Text(_tabs[i]),
                selected: selected,
                onSelected: (_) => setState(() => _selectedTab = i),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFeesList(List<FeeGroupEntry> rows) {
    final totalAmount = rows.fold<double>(0, (s, r) => s + r.amount);
    final totalDiscount = rows.fold<double>(0, (s, r) => s + r.discount);
    final totalFine = rows.fold<double>(0, (s, r) => s + r.fine);
    final totalPaid = rows.fold<double>(0, (s, r) => s + r.paid);
    final totalBalance = rows.fold<double>(0, (s, r) => s + r.balance);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Grand total card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grand Total',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _summaryRow('Amount', totalAmount),
                _summaryRow('Discount', totalDiscount),
                _summaryRow('Fine', totalFine),
                _summaryRow('Paid', totalPaid),
                const Divider(),
                _summaryRow('Balance', totalBalance, bold: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...rows.map((fee) => _buildFeeCard(fee)),
      ],
    );
  }

  Widget _buildFeeCard(FeeGroupEntry fee) {
    final statusColor = _statusColor(fee.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fee.feeTitle,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (fee.feeCode?.isNotEmpty == true)
                        Text(
                          fee.feeCode!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    fee.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _dataRow(
                        'Due Date',
                        fee.dueDate ?? 'N/A',
                      ),
                    ),
                    Expanded(
                      child: _dataRow(
                        'Amount',
                        _money(fee.amount),
                        bold: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _dataRow('Paid', _money(fee.paid))),
                    Expanded(
                      child: _dataRow(
                        'Balance',
                        _money(fee.balance),
                        bold: true,
                        valueColor: fee.balance > 0 ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
                if (fee.discount > 0 || fee.fine > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (fee.discount > 0)
                        Expanded(
                          child: _dataRow('Discount', _money(fee.discount)),
                        ),
                      if (fee.fine > 0)
                        Expanded(child: _dataRow('Fine', _money(fee.fine))),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingList(List<FeeGroupEntry> rows) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: rows.map((fee) {
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        fee.feeTitle,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    _statusBadge(fee.status),
                  ],
                ),
                const SizedBox(height: 12),
                if (fee.feeCode?.isNotEmpty == true)
                  _dataRow('Fee Code', fee.feeCode!),
                if (fee.paymentId?.isNotEmpty == true)
                  _dataRow('Payment ID', fee.paymentId!),
                if (fee.paymentMode?.isNotEmpty == true)
                  _dataRow('Payment Mode', fee.paymentMode!),
                if (fee.paymentDate?.isNotEmpty == true)
                  _dataRow('Payment Date', fee.paymentDate!),
                _dataRow('Amount', _money(fee.amount), bold: true),
                if (fee.discount > 0) _dataRow('Discount', _money(fee.discount)),
                if (fee.fine > 0) _dataRow('Fine', _money(fee.fine)),
                _dataRow('Paid', _money(fee.paid)),
                _dataRow('Balance', _money(fee.balance)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOfflineList(List<FeeGroupEntry> rows) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: rows.map((fee) {
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Request: ${fee.feeCode ?? fee.id.substring(0, 8)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    _statusBadge(fee.status),
                  ],
                ),
                const SizedBox(height: 12),
                if (fee.paymentDate?.isNotEmpty == true)
                  _dataRow('Payment Date', fee.paymentDate!),
                _dataRow('Amount', _money(fee.amount), bold: true),
                if (fee.paymentMode?.isNotEmpty == true)
                  _dataRow('Payment Mode', fee.paymentMode!),
                if (fee.paymentId?.isNotEmpty == true)
                  _dataRow('Payment ID', fee.paymentId!),
                if (fee.reference?.isNotEmpty == true)
                  _dataRow('Reference', fee.reference!),
                if (fee.comments?.isNotEmpty == true)
                  _dataRow('Comments', fee.comments!),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _summaryRow(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            _money(value),
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataRow(String label, String value, {bool bold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.red;
    }
  }

  String _money(double v) => v.toStringAsFixed(2);
}
