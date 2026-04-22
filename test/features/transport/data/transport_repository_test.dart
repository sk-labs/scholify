import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';
import 'package:scholify/features/transport/data/transport_repository.dart';

void main() {
  group('TransportRepository', () {
    const tenantId = 'tenant_alpha';

    late AppLocalDatabase database;
    late TenantContext tenantContext;
    late SyncEngine syncEngine;
    late TransportRepository repository;

    setUp(() {
      database = AppLocalDatabase(executor: NativeDatabase.memory());
      tenantContext = TenantContext()
        ..setTenant(
          tenantId: tenantId,
          tenantName: 'Alpha School',
          role: 'school_owner',
          isSuperAdmin: false,
        );

      syncEngine = SyncEngine(
        database: database,
        pocketbaseGateway: PocketbaseGateway(baseUrl: 'http://127.0.0.1:8090'),
        tenantContext: tenantContext,
      );

      repository = TransportRepository(
        database: database,
        syncEngine: syncEngine,
        tenantContext: tenantContext,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'creates and deletes routes while queueing transport sync operations',
      () async {
        await repository.saveRoute(
          routeTitle: 'Route A',
          vehicleNo: 'UP32 AB 1234',
          driverName: 'Ramesh',
          pickupPoint: 'North Gate',
          destinationPoint: 'Main Campus',
          pickupTime: '07:20',
          dropTime: '08:00',
          monthlyFare: 1200,
        );

        await repository.saveRoute(
          routeTitle: 'Route B',
          vehicleNo: 'UP32 CD 5678',
          driverName: 'Suresh',
          pickupPoint: 'City Center',
          destinationPoint: 'Main Campus',
          pickupTime: '07:35',
          dropTime: '08:15',
          monthlyFare: 1500,
        );

        final routes = await repository.watchRoutes().first;
        expect(routes.length, 2);
        expect(routes.first.routeTitle, 'Route A');

        await repository.deleteRoute(routes.first);

        final afterDelete = await repository.watchRoutes().first;
        expect(afterDelete.length, 1);
        expect(afterDelete.single.routeTitle, 'Route B');

        final queue = await database.getSyncQueueDispatchBatch(
          limit: 50,
          tenantId: tenantId,
        );
        final routeOps = queue
            .where((entry) => entry.entityType == 'transport_route')
            .toList();

        expect(routeOps.length, 3);
        expect(
          routeOps.where((entry) => entry.operation == 'upsert').length,
          2,
        );
        expect(
          routeOps.where((entry) => entry.operation == 'delete').length,
          1,
        );
      },
    );
  });
}
