import 'package:flutter/material.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../data/transport_repository.dart';

class TransportRoutesPage extends StatefulWidget {
  const TransportRoutesPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<TransportRoutesPage> createState() => _TransportRoutesPageState();
}

class _TransportRoutesPageState extends State<TransportRoutesPage> {
  late final TransportRepository _repository;

  final TextEditingController _routeTitleController = TextEditingController();
  final TextEditingController _vehicleNoController = TextEditingController();
  final TextEditingController _vehicleModelController = TextEditingController();
  final TextEditingController _driverNameController = TextEditingController();
  final TextEditingController _driverContactController =
      TextEditingController();
  final TextEditingController _pickupPointController = TextEditingController();
  final TextEditingController _destinationPointController =
      TextEditingController();
  final TextEditingController _pickupTimeController = TextEditingController();
  final TextEditingController _dropTimeController = TextEditingController();
  final TextEditingController _monthlyFareController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _repository = TransportRepository(
      database: widget.syncEngine.database,
      syncEngine: widget.syncEngine,
      tenantContext: widget.tenantContext,
    );
  }

  @override
  void dispose() {
    _routeTitleController.dispose();
    _vehicleNoController.dispose();
    _vehicleModelController.dispose();
    _driverNameController.dispose();
    _driverContactController.dispose();
    _pickupPointController.dispose();
    _destinationPointController.dispose();
    _pickupTimeController.dispose();
    _dropTimeController.dispose();
    _monthlyFareController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transport Routes (Offline-First)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildComposerCard(),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<TransportRouteEntry>>(
                stream: _repository.watchRoutes(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Failed to load transport routes: ${snapshot.error}',
                      ),
                    );
                  }

                  final routes = snapshot.data ?? const <TransportRouteEntry>[];
                  if (routes.isEmpty) {
                    return const Center(
                      child: Text('No transport routes created yet.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: routes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final route = routes[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.alt_route),
                          title: Text(route.routeTitle),
                          subtitle: Text(_routeSummary(route)),
                          isThreeLine: true,
                          trailing: IconButton(
                            tooltip: 'Delete route',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _isSaving
                                ? null
                                : () => _deleteRoute(route),
                          ),
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
  }

  Widget _buildComposerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Route',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _routeTitleController,
              decoration: const InputDecoration(
                labelText: 'Route title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 170,
                  child: TextField(
                    controller: _vehicleNoController,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle No',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: TextField(
                    controller: _vehicleModelController,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Model',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _driverNameController,
                    decoration: const InputDecoration(
                      labelText: 'Driver Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _driverContactController,
                    decoration: const InputDecoration(
                      labelText: 'Driver Contact',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _pickupPointController,
                    decoration: const InputDecoration(
                      labelText: 'Pickup Point',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _destinationPointController,
                    decoration: const InputDecoration(
                      labelText: 'Destination',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _pickupTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Pickup Time',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _dropTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Drop Time',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _monthlyFareController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Monthly Fare',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveRoute,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_road),
                  label: Text(_isSaving ? 'Saving...' : 'Add Route'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _routeSummary(TransportRouteEntry route) {
    final vehicle = [
      route.vehicleNo,
      route.vehicleModel,
    ].where((value) => value != null && value.trim().isNotEmpty).join(' ');
    final origin = route.pickupPoint ?? 'Pickup TBD';
    final destination = route.destinationPoint ?? 'Destination TBD';
    final timeRange = _formatTimeRange(route);
    final fare = route.monthlyFare.toStringAsFixed(2);

    return '${vehicle.isEmpty ? 'Vehicle TBD' : vehicle} | Driver: ${route.driverName ?? 'Unassigned'}\n$origin -> $destination | ${timeRange.isEmpty ? 'Time TBD' : timeRange} | Fare: $fare';
  }

  String _formatTimeRange(TransportRouteEntry route) {
    final pickup = route.pickupTime?.trim() ?? '';
    final drop = route.dropTime?.trim() ?? '';
    if (pickup.isEmpty && drop.isEmpty) {
      return '';
    }
    if (pickup.isNotEmpty && drop.isNotEmpty) {
      return '$pickup - $drop';
    }
    return pickup.isNotEmpty ? pickup : drop;
  }

  Future<void> _saveRoute() async {
    final routeTitle = _routeTitleController.text.trim();
    if (routeTitle.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Route title is required.')));
      return;
    }

    final monthlyFare =
        double.tryParse(_monthlyFareController.text.trim()) ?? 0;

    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.saveRoute(
        routeTitle: routeTitle,
        vehicleNo: _emptyToNull(_vehicleNoController.text),
        vehicleModel: _emptyToNull(_vehicleModelController.text),
        driverName: _emptyToNull(_driverNameController.text),
        driverContact: _emptyToNull(_driverContactController.text),
        pickupPoint: _emptyToNull(_pickupPointController.text),
        destinationPoint: _emptyToNull(_destinationPointController.text),
        pickupTime: _emptyToNull(_pickupTimeController.text),
        dropTime: _emptyToNull(_dropTimeController.text),
        monthlyFare: monthlyFare,
      );

      _routeTitleController.clear();
      _vehicleNoController.clear();
      _vehicleModelController.clear();
      _driverNameController.clear();
      _driverContactController.clear();
      _pickupPointController.clear();
      _destinationPointController.clear();
      _pickupTimeController.clear();
      _dropTimeController.clear();
      _monthlyFareController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transport route saved locally and queued for sync.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save route: $error')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteRoute(TransportRouteEntry route) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.deleteRoute(route);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transport route deleted.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete route: $error')),
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

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
