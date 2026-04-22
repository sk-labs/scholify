import 'dart:convert';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

class TransportRepository {
  TransportRepository({
    required this.database,
    required this.syncEngine,
    required this.tenantContext,
  });

  final AppLocalDatabase database;
  final SyncEngine syncEngine;
  final TenantContext tenantContext;

  Stream<List<TransportRouteEntry>> watchRoutes({
    bool includeInactive = false,
  }) {
    return database.watchTransportRoutes(
      tenantId: _resolveTenantId(),
      includeInactive: includeInactive,
    );
  }

  Future<void> saveRoute({
    String? routeId,
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
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();
    final resolvedRouteId =
        routeId ?? 'route_${tenantId}_${now.millisecondsSinceEpoch}';

    await database.upsertTransportRouteRecord(
      routeId: resolvedRouteId,
      tenantId: tenantId,
      routeTitle: routeTitle,
      vehicleNo: vehicleNo,
      vehicleModel: vehicleModel,
      driverName: driverName,
      driverContact: driverContact,
      pickupPoint: pickupPoint,
      destinationPoint: destinationPoint,
      pickupTime: pickupTime,
      dropTime: dropTime,
      monthlyFare: monthlyFare,
      isActive: isActive,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'transport_route',
      entityId: resolvedRouteId,
      operation: 'upsert',
      payload: jsonEncode({
        'routeId': resolvedRouteId,
        'tenantId': tenantId,
        'routeTitle': routeTitle,
        'vehicleNo': vehicleNo,
        'vehicleModel': vehicleModel,
        'driverName': driverName,
        'driverContact': driverContact,
        'pickupPoint': pickupPoint,
        'destinationPoint': destinationPoint,
        'pickupTime': pickupTime,
        'dropTime': dropTime,
        'monthlyFare': monthlyFare,
        'isActive': isActive,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> deleteRoute(TransportRouteEntry route) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();

    await database.deleteTransportRouteRecord(
      tenantId: tenantId,
      routeId: route.id,
    );

    await syncEngine.enqueueOperation(
      entityType: 'transport_route',
      entityId: route.id,
      operation: 'delete',
      payload: jsonEncode({
        'routeId': route.id,
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
