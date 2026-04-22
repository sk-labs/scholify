import 'dart:async';

import 'package:flutter/foundation.dart';

import '../database/local_database.dart';
import '../remote/pocketbase_gateway.dart';
import '../tenant/tenant_context.dart';
import 'pocketbase_sync_adapter.dart';

class SyncEngine extends ChangeNotifier {
  SyncEngine({
    required this.database,
    required this.pocketbaseGateway,
    required this.tenantContext,
  }) : _syncAdapter = PocketbaseSyncAdapter(
         database: database,
         pocketbaseGateway: pocketbaseGateway,
       );

  final AppLocalDatabase database;
  final PocketbaseGateway pocketbaseGateway;
  final TenantContext tenantContext;
  final PocketbaseSyncAdapter _syncAdapter;

  bool _isBackgroundSyncEnabled = false;
  bool _isSyncing = false;
  int _pendingJobs = 0;
  DateTime? _lastSyncAt;
  Timer? _backgroundTimer;

  bool get isBackgroundSyncEnabled => _isBackgroundSyncEnabled;
  bool get isSyncing => _isSyncing;
  int get pendingJobs => _pendingJobs;
  DateTime? get lastSyncAt => _lastSyncAt;

  Future<void> initialize() async {
    await _refreshPendingCount();
  }

  Future<void> enqueueOperation({
    required String entityType,
    required String entityId,
    required String operation,
    required String payload,
  }) async {
    final activeTenant = tenantContext.tenantId ?? 'global';
    await database.queueOperation(
      tenantId: activeTenant,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
    );
    await _refreshPendingCount();
  }

  void startBackgroundSync({Duration interval = const Duration(seconds: 30)}) {
    if (_isBackgroundSyncEnabled) return;
    _isBackgroundSyncEnabled = true;
    _backgroundTimer?.cancel();
    _backgroundTimer = Timer.periodic(interval, (_) {
      manualSync();
    });
    notifyListeners();
  }

  void stopBackgroundSync() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
    _isBackgroundSyncEnabled = false;
    notifyListeners();
  }

  Future<void> manualSync() async {
    if (_isSyncing) return;

    _isSyncing = true;
    notifyListeners();

    try {
      final isSuperAdmin = tenantContext.isSuperAdmin;
      final scopedTenantId = tenantContext.tenantId;

      if (!isSuperAdmin && (scopedTenantId == null || scopedTenantId.isEmpty)) {
        await _refreshPendingCount();
        return;
      }

      final pushed = await _syncAdapter.pushPendingQueue(
        limit: 25,
        scopedTenantId: isSuperAdmin ? null : scopedTenantId,
      );
      final pulled = await _syncAdapter.pullLatest(
        scopedTenantId: isSuperAdmin ? null : scopedTenantId,
      );
      if (pushed > 0 || pulled > 0) {
        _lastSyncAt = DateTime.now();
      }
      await _refreshPendingCount();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _refreshPendingCount() async {
    _pendingJobs = await database.pendingSyncCount();
    notifyListeners();
  }

  Future<void> disposeEngine() async {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
    await database.close();
  }
}
